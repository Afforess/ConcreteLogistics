require 'defines'
require 'libs/concrete'
require 'libs/circular_buffer'
require 'libs/logger'
require 'libs/settings_gui'

script.on_event({defines.events.on_built_entity, defines.on_robot_built_entity}, function(event)
    local created_entity = event.created_entity
    if created_entity.name == "concrete-logistics" then
        created_entity.backer_name = ""
        
        if not global.concrete_logistics_hubs then global.concrete_logistics_hubs = {} end
        init_concrete_data()

        -- logistics: the logistics tower entity
        -- pending_concrete: list of tuples with concrete type and position, will be processed and converted into a tile_ghost entity
        -- pending_entities: list containing entities to be examined for pending concrete requests
        -- entities: list of examined entities that had concrete areas managed by the logistics tower
        -- pending_construction: list tile_ghost entities that are pending arrival of a construction bot
        local concrete_area = expand_area(entity_area(created_entity), created_entity.logistic_cell.construction_radius)
        local data = {logistics = created_entity, concrete_area = concrete_area, pending_concrete = circular_buffer.new(), pending_entities = circular_buffer.new(), pending_construction = circular_buffer.new()}
        update_entities_around_hub(data, nil)
        table.insert(global.concrete_logistics_hubs, data)
        Logger.log("Concrete Logistics Hub created at " .. serpent.line(created_entity.position))
    elseif global.concrete_logistics_hubs and concrete_data_for_entity(created_entity) ~= nil then
        local force = created_entity.force
        for _, concrete_logistics in pairs(global.concrete_logistics_hubs) do
            if concrete_logistics.logistics.force == force then
                if entity_inside_concrete_logistics_area(created_entity, concrete_logistics) then
                    circular_buffer.append(concrete_logistics.pending_entities, created_entity)
                end
            end
        end
    end
end)

script.on_event(defines.events.on_tick, function(event)
    if global.concrete_logistics_hubs then 
        for i = #global.concrete_logistics_hubs, 1, -1 do
            local data = global.concrete_logistics_hubs[i]
            if data.logistics ~= nil and data.logistics.valid then
                update_concrete_logistics(data)
                if game.tick % 3600 == 0 then
                    prevent_pending_construction_death(data)
                end
            else
                table.remove(global.concrete_logistics_hubs, i)
            end
        end
    end
end)


function update_entities_around_hub(concrete_logistics, entity_types)
    -- Add nearby entities to the queue
    local position = concrete_logistics.logistics.position
    local surface = concrete_logistics.logistics.surface
    local entities = nil
    if entity_types == nil then
        entities = surface.find_entities_filtered({area = concrete_logistics.concrete_area, force = concrete_logistics.logistics.force})
    else
        entities = {}
        for _, entity_type in pairs(entity_types) do
            local list = surface.find_entities_filtered({area = concrete_logistics.concrete_area, type = entity_type, force = concrete_logistics.logistics.force})
            for index, entity in pairs(list) do
                table.insert(entities, entity)
            end
        end
    end
    -- sort entities by distance, not strictly nessecary, but aesthetically pleasing
    local sorted_entities = {}
    for _, nearby_entity in pairs(entities) do
        local data = concrete_data_for_entity(nearby_entity)
        if data ~= nil and entity_inside_concrete_logistics_area(nearby_entity, concrete_logistics) then
            table.insert(sorted_entities, {pos = nearby_entity.position, entity = nearby_entity})
        end
    end
    table.sort(sorted_entities, function(a, b)
        return dist_squared(a.pos, position) < dist_squared(b.pos, position)
    end)
    for _, data in pairs(sorted_entities) do
        circular_buffer.append(concrete_logistics.pending_entities, data.entity)
    end
end


function entity_inside_concrete_logistics_area(entity, concrete_logistics)
    local concrete_area = concrete_logistics.concrete_area
    return area_inside(concrete_area, entity_area(entity))
end

function is_valid_tile_for_concrete(x, y, surface)
    local adjacent = {{0, 0}, {1, 0}, {0, 1}, {-1, 0}, {0, -1}, {1, 1}, {1, -1}, {-1, 1}, {-1, -1}}
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
    
    local iter = circular_buffer.iterator(concrete_logistics.pending_concrete)
    while(iter.has_next()) do
        local node = iter.next_node()
        local data = node.value
        if data.position.x == tx and data.position.y == ty then
            return {name = data.concrete, pending_concrete_node = node}
        end
    end
    return {name = surface.get_tile(x, y).name}
end

function get_expected_tile_name(x, y, surface, force)
    local area = expand_area(tile_area(x, y, 1), get_largest_concrete_radius())
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
            circular_buffer.append(concrete_logistics.pending_construction, new_tile_ghost)
        end
        tile_name.tile_ghost.destroy()
    elseif tile_name.pending_concrete_node ~= nil then
        pending_concrete_node.value = {concrete = expected_tile_name, position = position}
    else
        circular_buffer.append(concrete_logistics.pending_concrete, {concrete = expected_tile_name, position = position})
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
    elseif concrete_logistics.pending_construction.count >= max_pending_construction(concrete_logistics) then
        if game.tick % 300 == 0 then
            prevent_pending_construction_death(concrete_logistics)
        end
    elseif game.tick % 2 == 1 and concrete_logistics.pending_concrete.count > 0 then
        fulfill_construction_request(concrete_logistics)
    elseif game.tick % 5 == 3 and concrete_logistics.pending_entities.count > 0 then
        examine_nearby_entities_for_concrete_logistics(concrete_logistics)
    end
end

function examine_nearby_entities_for_concrete_logistics(concrete_logistics)
    local entity_request = circular_buffer.pop(concrete_logistics.pending_entities)
    if entity_request.valid then
        plan_concrete_for_entity(concrete_logistics, entity_request)
        Logger.log("Planned concrete for entity " .. serpent.line(entity_request.name))
    end
end

function fulfill_construction_request(concrete_logistics)
    local concrete_request = circular_buffer.pop(concrete_logistics.pending_concrete)
    local closest_cell = concrete_logistics.logistics.logistic_network.find_cell_closest_to(concrete_request.position)
    if closest_cell ~= nil and closest_cell.is_in_construction_range(concrete_request.position) then
        local data = {name = "tile-ghost", position = concrete_request.position, force = concrete_logistics.logistics.force, inner_name = concrete_request.concrete}
        local tile_ghost = concrete_logistics.logistics.surface.create_entity(data)
        if tile_ghost ~= nil then
            circular_buffer.append(concrete_logistics.pending_construction, tile_ghost)
        end
    else
        Logger.log("No logistics cell closest to position at " .. serpent.line(concrete_request.position))
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
    local iter = circular_buffer.iterator(concrete_logistics.pending_construction)
    while(iter.has_next()) do
        local node = iter.next_node()
        local entity = node.value
        if entity.valid then
            entity.time_to_live = entity.force.ghost_time_to_live
        else
            circular_buffer.remove(concrete_logistics.pending_construction, node)
        end
    end
end

-- function: dist_squared
-- squared distance between two positions (square roots are expensive)
function dist_squared(pos_a, pos_b)
    local axbx = pos_a.x - pos_b.x
    local ayby = pos_a.y - pos_b.y
    return axbx * axbx + ayby * ayby
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

-- function: area_inside
-- Checks if a given area contains the other_area completely inside of itself
function area_inside(area, other_area)
    return inside_area(other_area.left_top.x, other_area.left_top.y, area) and
            inside_area(other_area.right_bottom.x, other_area.right_bottom.y, area)
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
