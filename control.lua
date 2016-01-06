require "defines"
require 'libs/concrete'

local logger = require 'libs/logger'
local l = logger.new_logger("main")

script.on_event({defines.events.on_built_entity, defines.on_robot_built_entity}, function(event)
    if event.created_entity.name == "concrete-logistics" then
        event.created_entity.backer_name = ""
        if not global.concrete_logistics_towers then global.concrete_logistics_towers = {} end
        -- logistics: the logistics tower entity
        -- player_entities: list of entities recently constructed by player (or player bots), may or may not be in logistics concrete area, will be calculated eventually
        -- pending_concrete: list of tuples with concrete type and position, will be processed and converted into a tile_ghost entity
        -- pending_entities: list of tuples containing an entity and it's concrete area to be examined for pending concrete requests
        -- entities: list of examined entities that had concrete areas managed by the logistics tower
        -- pending_construction: list tile_ghost entities that are pending arrival of a construction bot
        -- concrete_areas: areas around entities that have been given concrete
        local data = {logistics = event.created_entity, player_entities = {}, pending_concrete = {}, pending_entities = {}, entities = {}, pending_construction = {}, concrete_areas = {}}
        table.insert(data.pending_entities, {entity = event.created_entity, distance = concrete_distance_for_entity(event.created_entity) })
        table.insert(global.concrete_logistics_towers, data)
        l:log("Concrete Logistics Hub created at " .. serpent.line(event.created_entity.position))
    elseif global.concrete_logistics_towers and concrete_distance_for_entity(event.created_entity) ~= nil then
        local force = event.created_entity.force
        for _, concrete_logistics in pairs(global.concrete_logistics_towers) do
            if concrete_logistics.logistics.force == force then
                table.insert(concrete_logistics.player_entities, event.created_entity)
            end
        end
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

function concrete_distance_for_entity(entity)
    if concrete_distances[entity.type] ~= nil then
        return concrete_distances[entity.type]        
    end
    return nil
end

function plan_concrete_for_entity(concrete_logistics, entity, distance)
    local surface = entity.surface
    local concrete_area = expand_area(entity_area(entity), distance.radius - 1)
    for x = concrete_area.left_top.x, concrete_area.right_bottom.x - 1, 1 do
        for y = concrete_area.left_top.y, concrete_area.right_bottom.y - 1, 1 do
            if surface.get_tile(x, y).name ~= "concrete" and not tile_has_ghost(x, y, surface, concrete_logistics.logistics.force) then
                table.insert(concrete_logistics.pending_concrete, {concrete = "concrete", position = {x = math.floor(x), y = math.floor(y)}})
            end
        end
    end
    -- Add nearby entities to the queue
    local entity_search_area = expand_area(entity_area(entity), math.max(distance.radius, distance.search) - 1)
    local entities = surface.find_entities_filtered({area = entity_search_area, force = concrete_logistics.logistics.force})
    for _, nearby_entity in pairs(entities) do
        if nearby_entity.name ~= "tile-ghost" and nearby_entity.name ~= "entity-ghost" then
            local dist = concrete_distance_for_entity(nearby_entity)
            if dist ~= nil and not in_concrete_logistics(concrete_logistics, nearby_entity) then
                local closest_cell = concrete_logistics.logistics.logistic_network.find_cell_closest_to(nearby_entity.position)
                if closest_cell ~= nil and closest_cell.is_in_construction_range(nearby_entity.position) then
                    table.insert(concrete_logistics.pending_entities, {entity = nearby_entity, distance = dist})
                else
                    l:log("Entity " .. nearby_entity.name .. " at position " .. serpent.line(nearby_entity.position) .. " is out of range of the construction logistics network.")
                end
            end
        end
    end
    table.insert(concrete_logistics.concrete_areas, {entity = entity, area = concrete_area, concrete = "concrete"})
end

-- function: max_pending_construction
-- Maximum number of construction robots that the logistics tower can put into use
-- The max is 1/2 of total construction robots, or the total construction robots minus 25, whichever is larger
function max_pending_construction(concrete_logistics)
    local max = concrete_logistics.logistics.logistic_network.all_construction_robots
    return math.max(1, math.max(max / 2, max - 25))
end

-- function: update_concrete_logistics
-- main logic for each logistics tower
-- Will either warn players if the logistics tower is not connected to a logistics network or has no construction bots
-- OR fulfills one pending_concrete construction request per tick, unless the the number of pending_construction tile_ghosts exceeds the max allowed
-- OR examines one nearby entity every 3 ticks for nearby entities and pending concrete tile_ghosts
function update_concrete_logistics(concrete_logistics)
    if concrete_logistics.logistics.logistic_network == nil or concrete_logistics.logistics.logistic_network.all_construction_robots == 0 then
        if game.tick % 3600 == 0 then
            warn_no_construction_bots(concrete_logistics)
        end
    elseif #concrete_logistics.pending_construction >= max_pending_construction(concrete_logistics) then
        if game.tick % 300 == 0 then
            prevent_pending_construction_death(concrete_logistics)
        end
    elseif #concrete_logistics.pending_concrete > 0 then
        fulfill_construction_request(concrete_logistics)
    elseif game.tick % 3 == 0 and #concrete_logistics.player_entities > 0 then
        examine_player_entities(concrete_logistics)
    elseif game.tick % 3 == 0 and #concrete_logistics.pending_entities > 0 then
        examine_nearby_entities_for_concrete_logistics(concrete_logistics)
    end
end

function examine_player_entities(concrete_logistics)
    local entity = table.remove(concrete_logistics.player_entities, 1)
    if entity.valid then
        local pos = entity.position
        
        for i = #concrete_logistics.entities, 1, -1 do
            local other_entity = concrete_logistics.entities[i]
            if other_entity.valid then
                local concrete_search_dist = concrete_distance_for_entity(other_entity).search
                if dist_squared(pos, other_entity.position) <= (concrete_search_dist * concrete_search_dist) then
                    table.insert(concrete_logistics.pending_entities, {entity = entity, distance = concrete_distance_for_entity(entity)})
                    return
                end
            else
                table.remove(concrete_logistics.entities, i)
            end
        end
    end
end

function examine_nearby_entities_for_concrete_logistics(concrete_logistics)
    local entity_request = table.remove(concrete_logistics.pending_entities, 1)
    if entity_request.entity.valid then
        table.insert(concrete_logistics.entities, entity_request.entity)
        plan_concrete_for_entity(concrete_logistics, entity_request.entity, entity_request.distance)
        l:log("Planned concrete for entity " .. serpent.line(entity_request.entity.name))
    end
end

function fulfill_construction_request(concrete_logistics)
    local concrete_request = table.remove(concrete_logistics.pending_concrete, 1)
    local closest_cell = concrete_logistics.logistics.logistic_network.find_cell_closest_to(concrete_request.position)
    if closest_cell ~= nil and closest_cell.is_in_construction_range(concrete_request.position) then
        local data = {name = "tile-ghost", position = concrete_request.position, force = concrete_logistics.logistics.force, inner_name = concrete_request.concrete}
        local tile_ghost = concrete_logistics.logistics.surface.create_entity(data)
        if tile_ghost ~= nil then
            table.insert(concrete_logistics.pending_construction, tile_ghost)
        end
    else
        l:log("No logistics cell closest to position at " .. serpent.line(concrete_request.position))
    end
end

-- function: warn_no_construction_bots
-- Iterates all online players that are in the same force as the concrete logistics network
-- and prints a warning message that no construction bots are within a concrete logistics network.
function warn_no_construction_bots(concrete_logistics)
    local force = concrete_logistics.logistics.force
    for _, player in pairs(game.players) do
        if player.valid and player.connected and player.force == force then
            player.print("No construction bots within a concrete logistics hub network!")
        end
    end
end

-- function: prevent_pending_construction_death
-- Iterates all tile-ghost entities in the concrete logistics pending_construction list
-- Any invalid entities are removed, and the time_to_live for each entity is reset to the maximum allowed by its force
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

-- function: in_concrete_logistics
-- Checks if an entity is in either the pending_entities or already examined list of entities for a concrete logistics network
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

-- function: dist_squared
-- squared distance between two positions (square roots are expensive)
function dist_squared(pos_a, pos_b)
    local axbx = pos_a.x - pos_b.x
    local ayby = pos_a.y - pos_b.y
    return axbx * axbx + ayby + ayby
end

-- function: tile_has_ghost
-- Checks if a given x,y pair of coordinates on a surface has a tile-ghost entity at the location
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

-- function: tile_area
-- Converts an x,y pair into an area around a tile from the given distance
function tile_area(x, y, distance)
    return {left_top = {x = math.floor(x) - distance, y = math.floor(y) - distance},
            right_bottom = {x = math.floor(x) + distance, y = math.floor(y) + distance}}
end

-- function: entity_area
-- Converts the position and selection_box of an entity into an area around it
function entity_area(entity)
    local pos = entity.position
    local bb = entity.prototype.selection_box
    return {left_top = {x = bb.left_top.x + pos.x, y = bb.left_top.y + pos.y},
            right_bottom = {x = bb.right_bottom.x + pos.x, y = bb.right_bottom.y + pos.y}}
end

-- function: expand_area
-- Given an area and a distance to expand it, returns an area with the given extra distance
function expand_area(area, distance)
    return {left_top = {x = area.left_top.x - distance, y = area.left_top.y - distance},
            right_bottom = {x = area.right_bottom.x + distance, y = area.right_bottom.y + distance}}
end
