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
        -- pending_entities: list containing entities to be examined for pending concrete requests
        -- entities: list of examined entities that had concrete areas managed by the logistics tower
        -- pending_construction: list tile_ghost entities that are pending arrival of a construction bot
        local data = {logistics = event.created_entity, player_entities = {}, pending_concrete = {}, pending_entities = {}, entities = {}, pending_construction = {}}
        table.insert(data.pending_entities, event.created_entity)
        table.insert(global.concrete_logistics_towers, data)
        l:log("Concrete Logistics Hub created at " .. serpent.line(event.created_entity.position))
    elseif global.concrete_logistics_towers and concrete_data_for_entity(event.created_entity) ~= nil then
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

function is_valid_tile_for_concrete(x, y, surface)
    local adjacent = {{1, 0}, {0, 1}, {-1, 0}, {0, -1}, {1, 1}, {1, -1}, {-1, 1}, {-1, -1}}
    for _, tuple in pairs(adjacent) do
        if surface.get_tile(x + tuple[1], y + tuple[2]).name == "water" then
            return false
        end
    end
    return true
end

function get_tile_name(x, y, surface, force, concrete_logistics)
    local tile_ghost = get_tile_ghost(x, y, surface, force)
    if tile_ghost ~= nil then
        return {name = tile_ghost.ghost_name, tile_ghost = tile_ghost}
    end
    local tx = math.floor(x)
    local ty = math.floor(y)
    for index, data in pairs(concrete_logistics.pending_concrete) do
        if data.position.x == tx and data.position.y == ty then
            return {name = data.concrete, pending_concrete_index = index}
        end
    end
    return {name = surface.get_tile(x, y).name}
end

function get_expected_tile_name(x, y, surface, force)
    local area = expand_area(tile_area(x, y, 1), get_largest_concrete_radius())
    l:log("Tile Search Area: " .. serpent.line(area))
    local entities = surface.find_entities_filtered({area = area, force = force})
    local highest_priority_data = nil
    for _, entity in pairs(entities) do
        local concrete_data = concrete_data_for_entity(entity)
        if concrete_data ~= nil then
            local concrete_area = expand_area(entity_area(entity), concrete_data.radius - 1)
            if inside_area(x, y, concrete_area) then
                if highest_priority_data == nil or concrete_data.priority < highest_priority_data.priority then
                    highest_priority_data = concrete_data
                end
            end
        end
    end
    return highest_priority_data.concrete
end

function make_request_for_concrete_tile(x, y, surface, force, concrete_logistics, tile_name, expected_tile_name)
    local position = {x = math.floor(x), y = math.floor(y)}
    if tile_name.tile_ghost ~= nil then
        local new_tile_ghost = surface.create_entity({name = "tile-ghost", position = position, force = force, inner_name = expected_tile_name})
        if new_tile_ghost ~= nil then
            table.insert(concrete_logistics.pending_construction, new_tile_ghost)
        end
        tile_name.tile_ghost.destroy()
    elseif tile_name.pending_concrete_index ~= nil then
        concrete_logistics.pending_concrete[tile_name.pending_concrete_index] = {concrete = expected_tile_name, position = position}
    else
        table.insert(concrete_logistics.pending_concrete, {concrete = expected_tile_name, position = position})
    end
end

function plan_concrete_for_entity(concrete_logistics, entity)
    local surface = entity.surface
    local force = entity.force
    local concrete_data = concrete_data_for_entity(entity)
    local concrete_area = expand_area(entity_area(entity), concrete_data.radius - 1)
    for x = concrete_area.left_top.x, concrete_area.right_bottom.x - 1, 1 do
        for y = concrete_area.left_top.y, concrete_area.right_bottom.y - 1, 1 do
            if is_valid_tile_for_concrete(x, y, surface) then
                local pos = {x = math.floor(x), y = math.floor(y)}
                local closest_cell = concrete_logistics.logistics.logistic_network.find_cell_closest_to(pos)
                if closest_cell ~= nil and closest_cell.is_in_construction_range(pos) then
                    local tile_name = get_tile_name(x, y, surface, force, concrete_logistics)
                    local expected_tile_name = get_expected_tile_name(x, y, surface, force)
                    if tile_name.name ~= expected_tile_name then
                        make_request_for_concrete_tile(x, y, surface, force, concrete_logistics, tile_name, expected_tile_name)
                    end
                end
            end
        end
    end
    -- Add nearby entities to the queue
    local entity_search_area = expand_area(entity_area(entity), math.max(concrete_data.radius, concrete_data.search) - 1)
    local entities = surface.find_entities_filtered({area = entity_search_area, force = concrete_logistics.logistics.force})
    for _, nearby_entity in pairs(entities) do
        if nearby_entity.name ~= "tile-ghost" and nearby_entity.name ~= "entity-ghost" then
            local data = concrete_data_for_entity(nearby_entity)
            if data ~= nil and not in_concrete_logistics(concrete_logistics, nearby_entity) then
                local closest_cell = concrete_logistics.logistics.logistic_network.find_cell_closest_to(nearby_entity.position)
                if closest_cell ~= nil and closest_cell.is_in_construction_range(nearby_entity.position) then
                    table.insert(concrete_logistics.pending_entities, nearby_entity)
                else
                    l:log("Entity " .. nearby_entity.name .. " at position " .. serpent.line(nearby_entity.position) .. " is out of range of the construction logistics network.")
                end
            end
        end
    end
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
    l:log("Pending construction: " .. #concrete_logistics.pending_construction .. ", max pending construction: " .. max_pending_construction(concrete_logistics))
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
                local concrete_search_dist = concrete_data_for_entity(other_entity).search
                if dist_squared(pos, other_entity.position) <= (concrete_search_dist * concrete_search_dist) then
                    table.insert(concrete_logistics.pending_entities, entity)
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
    if entity_request.valid then
        table.insert(concrete_logistics.entities, entity_request)
        plan_concrete_for_entity(concrete_logistics, entity_request)
        l:log("Planned concrete for entity " .. serpent.line(entity_request.name))
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
        if search_entity == entity_request then
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
    return axbx * axbx + ayby * ayby
end

-- function: tile_has_ghost
-- Checks if a given x,y pair of coordinates on a surface has a tile-ghost entity at the location
function tile_has_ghost(x, y, surface, force)
    return get_tile_ghost(x, y, surface, force) ~= nil
end

-- function: get_tile_ghost
-- Returns the tile ghost entity given an x,y pair of coordinates on a surface
function get_tile_ghost(x, y, surface, force)
    local tx = math.floor(x)
    local ty = math.floor(y)
    local tile_ghosts = surface.find_entities_filtered({area = tile_area(tx, ty, 1), type = "tile-ghost", force = force})
    for _, tile_ghost in pairs(tile_ghosts) do
        local pos = tile_ghost.position
        local cx = math.floor(pos.x)
        local cy = math.floor(pos.y)
        local dist_squared = (tx - cx) * (tx - cx) + (ty - cy) * (ty - cy)
        if dist_squared < 0.5 then
            return tile_ghost
        end
    end
    return nil
end

-- function: inside_area
-- Checks if a given pair of x,y coordinates are inside the area
function inside_area(x,y, area)
    return x >= area.left_top.x and y >= area.left_top.y and
            x <= area.right_bottom.x and y <= area.right_bottom.y
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
    return {left_top = {x = math.floor(bb.left_top.x + pos.x), y = math.floor(bb.left_top.y + pos.y)},
            right_bottom = {x = math.ceil(bb.right_bottom.x + pos.x), y = math.ceil(bb.right_bottom.y + pos.y)}}
end

-- function: expand_area
-- Given an area and a distance to expand it, returns an area with the given extra distance
function expand_area(area, distance)
    return {left_top = {x = area.left_top.x - distance, y = area.left_top.y - distance},
            right_bottom = {x = area.right_bottom.x + distance, y = area.right_bottom.y + distance}}
end
