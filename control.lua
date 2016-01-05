require "defines"
require 'libs/utils'

local logger = require 'libs/logger'
local l = logger.new_logger("main")

script.on_event(defines.events.on_built_entity, function(event)
    if event.created_entity.name == "concrete-logistics" then
        event.created_entity.backer_name = ""
        if not global.concrete_logistics_towers then global.concrete_logistics_towers = {} end
        local data = {logistics = event.created_entity, pending_concrete = {}, pending_entities = {}, entities = {}, pending_construction = {}, concrete_areas = {}}
        table.insert(data.pending_entities, {entity = event.created_entity, distance = 5})
        table.insert(global.concrete_logistics_towers, data)
        l:log("Concrete Logistics Tower created at " .. serpent.line(event.created_entity.position))
    end
end)

script.on_event(defines.events.on_tick, function(event)
    if global.concrete_logistics_towers then 
        for i = #global.concrete_logistics_towers, 1, -1 do
            local data = global.concrete_logistics_towers[i]
            if data.logistics ~= nil and data.logistics.valid then
                update_concrete_logistics(data)
                if game.tick % 3600 == 0 then
                    prevent_pending_construction_death(data)
                end
            else
                table.remove(global.concrete_logistics_towers, i)
            end
        end
    end
end)

concrete_distances = {}
concrete_distances["transport-belt"] = 2
concrete_distances["inserter"] = 1
concrete_distances["straight-rail"] = 3
concrete_distances["curved-rail"] = 3
concrete_distances["assembling-machine"] = 3
concrete_distances["furnace"] = 3
concrete_distances["boiler"] = 3
concrete_distances["electric-pole"] = 1
concrete_distances["container"] = 1
concrete_distances["logistic-container"] = 1
concrete_distances["generator"] = 2
concrete_distances["pipe"] = 1
concrete_distances["pipe-to-ground"] = 1
concrete_distances["pump"] = 5
concrete_distances["radar"] = 3
concrete_distances["lamp"] = 3
concrete_distances["wall"] = 2
concrete_distances["turret"] = 2
concrete_distances["train-stop"] = 2
concrete_distances["rail-signal"] = 2
concrete_distances["rail-chain-signal"] = 2
concrete_distances["lab"] = 3
concrete_distances["rocket-sile"] = 5
concrete_distances["roboport"] = 5
concrete_distances["accumulator"] = 2
concrete_distances["beacon"] = 3

function concrete_distance_for_entity(entity)
    if concrete_distances[entity.type] ~= nil then
        return concrete_distances[entity.type]        
    end
    return nil
end

function plan_concrete_for_entity(concrete_logistics, entity, distance)
    local surface = entity.surface
    local concrete_area = expand_area(entity_area(entity), distance)
    for x = concrete_area.left_top.x, concrete_area.right_bottom.x, 1 do
        for y = concrete_area.left_top.y, concrete_area.right_bottom.y, 1 do
            if surface.get_tile(x, y).name ~= "concrete" and not tile_has_ghost(x, y, surface, concrete_logistics.logistics.force) then
                table.insert(concrete_logistics.pending_concrete, {concrete = "concrete", position = {x = math.floor(x), y = math.floor(y)}})
            end
        end
    end
    -- Add nearby entities to the queue
    local entities = surface.find_entities_filtered({area = concrete_area, force = concrete_logistics.logistics.force})
    for _, nearby_entity in pairs(entities) do
        if nearby_entity.name ~= "tile-ghost" and nearby_entity.name ~= "entity-ghost" then
            local dist = concrete_distance_for_entity(nearby_entity)
            if dist ~= nil and not in_concrete_logistics(concrete_logistics, nearby_entity) then
                l:log("Concrete distance for entity " .. serpent.line(nearby_entity.name) .. " is " ..  dist)
                table.insert(concrete_logistics.pending_entities, {entity = nearby_entity, distance = dist})
            end
        end
    end
    table.insert(concrete_logistics.concrete_areas, {entity = entity, area = concrete_area, concrete = "concrete"})
end

function max_pending_construction(concrete_logistics)
    local max = concrete_logistics.logistics.logistic_network.all_construction_robots
    return math.max(1, math.max(max / 2, max - 25))
end

function update_concrete_logistics(concrete_logistics)
    if #concrete_logistics.pending_construction >= max_pending_construction(concrete_logistics) then
        if game.tick % 300 == 0 then
            prevent_pending_construction_death(concrete_logistics)
        end
    elseif #concrete_logistics.pending_concrete > 0 then
        local concrete_request = table.remove(concrete_logistics.pending_concrete, 1)
        local data = {name = "tile-ghost", position = concrete_request.position, force = concrete_logistics.logistics.force, inner_name = concrete_request.concrete}
        local tile_ghost = concrete_logistics.logistics.surface.create_entity(data)
        if tile_ghost ~= nil then
            table.insert(concrete_logistics.pending_construction, tile_ghost)
        end
    elseif game.tick % 3 == 0 and #concrete_logistics.pending_entities > 0 then
        local entity_request = table.remove(concrete_logistics.pending_entities, 1)
        if entity_request.entity.valid then
            table.insert(concrete_logistics.entities, entity_request.entity)
            plan_concrete_for_entity(concrete_logistics, entity_request.entity, entity_request.distance)
            l:log("Planned concrete for entity " .. serpent.line(entity_request.entity.name))
        end
    end
end

-- prevents pending tile ghosts from dying after 5 mins
function prevent_pending_construction_death(concrete_logistics)
    for i = #concrete_logistics.pending_construction, 1, -1 do
        local entity = concrete_logistics.pending_construction[i]
        if entity.valid then
            entity.time_to_live = entity.force.ghost_time_to_live
        else
            table.remove(concrete_logistics.pending_construction, i)
        end
    end
end

function in_concrete_logistics(concrete_logistics, search_entity)
    for _, entity_request in pairs(concrete_logistics.pending_entities) do
        if search_entity == entity_request.entity then
            return true
        end
    end
    for _, entity in pairs(concrete_logistics.entities) do
        if search_entity == entity then
            return true
        end
    end
    return false
end

function tile_has_ghost(x, y, surface, force)
    local tx = math.floor(x)
    local ty = math.floor(y)
    local tile_ghosts = surface.find_entities_filtered({area = tile_area(tx, ty, 1), type = "tile-ghost", force = force})
    for _, tile_ghost in pairs(tile_ghosts) do
        local pos = tile_ghost.position
        local cx = math.floor(pos.x)
        local cy = math.floor(pos.y)
        local dist_squared = (tx - cx) * (tx - cx) + (ty - cy) * (ty - cy)
        if dist_squared < 0.5 then
            return true
        end
    end
    return false
end

function tile_area(x, y, distance)
    return {left_top = {x = math.floor(x) - distance, y = math.floor(y) - distance},
            right_bottom = {x = math.floor(x) + distance, y = math.floor(y) + distance}}
end

function entity_area(entity)
    local pos = entity.position
    local bb = entity.prototype.selection_box
    return {left_top = {x = bb.left_top.x + pos.x, y = bb.left_top.y + pos.y},
            right_bottom = {x = bb.right_bottom.x + pos.x, y = bb.right_bottom.y + pos.y}}
end

function expand_area(area, distance)
    return {left_top = {x = area.left_top.x - distance, y = area.left_top.y - distance},
            right_bottom = {x = area.right_bottom.x + distance, y = area.right_bottom.y + distance}}
end
