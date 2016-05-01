require 'defines'
require 'libs/concrete'
require 'libs/circular_buffer'
require 'libs/tile_cache'
require 'libs/logger'
require 'libs/cache_manager'
require 'libs/settings_gui'

script.on_event({defines.events.on_built_entity, defines.events.on_robot_built_entity}, function(event)
    local created_entity = event.created_entity
    if created_entity.name == "concrete-logistics" then
        created_entity.backer_name = ""

        if not global.concrete_logistics_hubs then global.concrete_logistics_hubs = {} end
        init_concrete_data()

        local hub = add_concrete_logistics_hub(created_entity)
        if show_first_time_player_info(event) then
            first_time_player_information(event.player_index, hub)
        elseif event.player_index then
            render_main_gui(game.players[event.player_index], hub, 1)
        end

    elseif global.concrete_logistics_hubs and concrete_data_for_entity(created_entity) ~= nil then
        local force = created_entity.force
        for _, concrete_logistics in pairs(global.concrete_logistics_hubs) do
            if concrete_logistics.logistics.valid and concrete_logistics.logistics.force == force then
                if entity_inside_concrete_logistics_area(created_entity, concrete_logistics) then
                    circular_buffer.append(concrete_logistics.pending_entities, created_entity)
                    reset_tile_cache(concrete_logistics)
                end
            end
        end
    end
end)

function show_first_time_player_info(event)
    if not global.player_notices then global.player_notices = {} end
    return event.player_index and global.player_notices[event.player_index] == nil
end

function first_time_player_information(player_index, hub)
    local player = game.players[player_index]
    local root = player.gui.center.add({type="frame", direction="vertical", name="concrete_logistics_frame", caption={"gui.players.first_time_notice.title"}})
    local text_flow = root.add({type="flow", direction="vertical"})
    for i = 1, 7 do
        text_flow.add({type="label", caption={"gui.players.first_time_notice.congrats.line" .. i}, style="cl-tutorial-label"})
    end
    text_flow.add({type="button", name="cl-congrats-menu", style="button_style", caption = {"gui.settings.exit"}})
    player.character.insert{name = "wrenchfu-wrench", count = 1}
    global.player_notices[player_index] = hub
end

function add_concrete_logistics_hub(entity)
    local concrete_area = expand_area(entity_area(entity), entity.logistic_cell.construction_radius)
    local data = {
        -- logistics: the logistics tower entity
        logistics = entity,
        -- concrete_area: area that the logistics tower manages
        concrete_area = concrete_area,
        -- fill_gaps: Gaps between entities, but outside the strict radius of entity concrete radius is filled in with gray concrete
        fill_gaps = false,
        -- deconstruction_enabled: concrete is deconstructed before a different type of concrete is placed overtop
        deconstruction_enabled = true,
        -- pending_concrete: list of tuples with concrete type and position, will be processed and converted into a tile_ghost entity
        pending_concrete = circular_buffer.new(),
        -- pending_entities: list containing entities to be examined for concrete requests
        pending_entities = circular_buffer.new(),
        -- pending_entities: list containing entities to be examined for a second pass, to identify gaps in concrete, used only if fill_gaps is on
        pending_entities_second_pass = circular_buffer.new(),
        -- pending_deconstruction: list of positions that are pending a deconstruction request for the concrete
        pending_deconstruction = circular_buffer.new(),
        -- pending_construction: list of tile_ghost entities that are pending arrival of a construction bot
        pending_construction = circular_buffer.new(),

        rescan_entity_types = {}
    }
    for i = 1, #global.concrete_data do
        if global.concrete_data[i].priority < 5 then
            update_entities_around_hub(data, global.concrete_data[i].types)
        else
            table.insert(data.rescan_entity_types, global.concrete_data[i].types)
        end
    end
    table.insert(global.concrete_logistics_hubs, data)
    Logger.log("Concrete Logistics Hub created at " .. serpent.line(entity.position))
    return data
end

script.on_event({defines.events.on_entity_died, defines.events.on_robot_pre_mined, defines.events.on_preplayer_mined_item}, function(event)
    if global.concrete_logistics_hubs then
        local entity = event.entity
        local force = entity.force
        for _, concrete_logistics in pairs(global.concrete_logistics_hubs) do
            if concrete_logistics.logistics.valid and concrete_logistics.logistics.force == force then
                if entity_inside_concrete_logistics_area(entity, concrete_logistics) then
                    reset_tile_cache(concrete_logistics)
                end
            end
        end
    end
end)


script.on_event(defines.events.on_tick, function(event)
    if global.concrete_logistics_hubs then
        local num_logistics_hubs = #global.concrete_logistics_hubs
        for i = num_logistics_hubs, 1, -1 do
            local data = global.concrete_logistics_hubs[i]
            if data.logistics ~= nil and data.logistics.valid then
                if num_logistics_hubs == 1 or (event.tick + i) % num_logistics_hubs == 0 then
                    update_concrete_logistics(data)
                end
                if game.tick % 3600 == 0 then
                    prevent_pending_construction_death(data)
                    log_cache_stats()
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
    local entities = {}
    for _, entity_type in pairs(entity_types) do
        local list = surface.find_entities_filtered({area = concrete_logistics.concrete_area, type = entity_type, force = concrete_logistics.logistics.force})
        for index, entity in pairs(list) do
            table.insert(entities, entity)
        end
    end
    -- sort entities by distance, not strictly nessecary, but aesthetically pleasing
    local all_entities = {}
    local iter = circular_buffer.iterator(concrete_logistics.pending_entities)
    while(iter.has_next()) do
        local pending_entity = iter.next()
        if pending_entity.valid then
            table.insert(all_entities, {entity = pending_entity, pos = pending_entity.position})
        end
    end
    for _, nearby_entity in pairs(entities) do
        local data = concrete_data_for_entity(nearby_entity)
        if data ~= nil and entity_inside_concrete_logistics_area(nearby_entity, concrete_logistics) then
            local already_in_list = false
            for _, pending in pairs(all_entities) do
                if pending.entity == nearby_entity then
                    already_in_list = true
                    break
                end
            end
            if not already_in_list then
                table.insert(all_entities, {pos = nearby_entity.position, entity = nearby_entity})
            end
        end
    end
    table.sort(all_entities, function(a, b)
        return dist_squared(a.pos, position) < dist_squared(b.pos, position)
    end)
    circular_buffer.reset(concrete_logistics.pending_entities)
    for _, data in pairs(all_entities) do
        circular_buffer.append(concrete_logistics.pending_entities, data.entity)
    end
end


function entity_inside_concrete_logistics_area(entity, concrete_logistics)
    if entity.surface == concrete_logistics.logistics.surface then
        local concrete_area = concrete_logistics.concrete_area
        return area_inside(concrete_area, entity_area(entity))
    end
    return false
end

function is_valid_tile_for_concrete(x, y, surface)
    local adjacent = {{0, 0}, {1, 0}, {0, 1}, {-1, 0}, {0, -1}, {1, 1}, {1, -1}, {-1, 1}, {-1, -1}}
    for _, tuple in pairs(adjacent) do
        if string.find(surface.get_tile(x + tuple[1], y + tuple[2]).name, "water", 1, true) then
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

function get_expected_tile_name(x, y, surface, force, concrete_logistics)
    local area = expand_area(tile_area(x, y, 1), get_largest_concrete_radius())
    local entities = surface.find_entities_filtered({area = area, force = force})
    local highest_priority_data = nil
    for _, entity in pairs(entities) do
        local concrete_data = concrete_data_for_entity(entity)
        if concrete_data ~= nil then
            local entity_area = entity_area(entity)
            local radius = concrete_data.radius
            if concrete_data.shape == "circle" then
                radius = radius + (entity_area.right_bottom.x - entity_area.left_top.x) / 2
                if radius == math.floor(radius) then
                    radius = radius - 0.5
                end
            end
            local concrete_area = expand_area(entity_area, radius)
            if inside_area(x, y, concrete_area) then
                local radius_squared = (radius * radius)
                if concrete_data.shape ~= "circle" or (dist_squared(entity.position, {x = x, y = y}) < radius_squared) then
                    if highest_priority_data == nil or concrete_data.priority < highest_priority_data.priority then
                        highest_priority_data = concrete_data
                    end
                end
            end
        end
    end
    if highest_priority_data then
        return highest_priority_data.concrete
    end
    return nil
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
        tile_name.pending_concrete_node.value = {concrete = expected_tile_name, position = position}
    else
        circular_buffer.append(concrete_logistics.pending_concrete, {concrete = expected_tile_name, position = position})
    end
end

function plan_concrete_for_entity(concrete_logistics, entity, second_pass)
    local surface = entity.surface
    local force = entity.force
    local concrete_data = concrete_data_for_entity(entity)
    if concrete_data.radius <= 0 then
        return
    end
    local entity_area = entity_area(entity)
    local radius = concrete_data.radius
    if concrete_data.shape == "circle" then
        radius = radius + (entity_area.right_bottom.x - entity_area.left_top.x) / 2
        if radius == math.floor(radius) then
            radius = radius - 0.5
        end
    end
    local concrete_area = expand_area(entity_area, math.max(0, radius))
    local total_concrete_area = concrete_area
    if second_pass and concrete_logistics.fill_gaps then
        total_concrete_area = expand_area(concrete_area, 4)
    end
    for x = total_concrete_area.left_top.x, total_concrete_area.right_bottom.x - 1, 1 do
        for y = total_concrete_area.left_top.y, total_concrete_area.right_bottom.y - 1, 1 do
            if is_valid_tile_for_concrete(x, y, surface) then
                local pos = {x = math.floor(x), y = math.floor(y)}
                local closest_cell = concrete_logistics.logistics.logistic_network.find_cell_closest_to(pos)
                if closest_cell ~= nil and closest_cell.is_in_construction_range(pos) then
                    local tile_name = get_tile_name(x, y, surface, force, concrete_logistics)
                    local expected_tile_name = get_cached_expected_tile_name(x, y, surface, force, concrete_logistics)

                    -- fill gaps, if enabled
                    if second_pass and concrete_logistics.fill_gaps and expected_tile_name == nil then
                        expected_tile_name = "concrete"
                    end
                    if tile_name.name ~= expected_tile_name and expected_tile_name ~= nil then
                        local is_concrete = string.find(tile_name.name, "concrete", 1, true)
                        if second_pass and is_concrete then
                            -- do nothing! second_pass to fill gaps should not erase player-placed concrete
                        else
                            if is_concrete and concrete_logistics.deconstruction_enabled then
                                circular_buffer.append(concrete_logistics.pending_deconstruction, {position = {x = x, y = y}})
                            end
                            make_request_for_concrete_tile(x, y, surface, force, concrete_logistics, tile_name, expected_tile_name)
                        end
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
    if concrete_logistics.rescan_entity_types == nil then
        concrete_logistics.rescan_entity_types = {}
    end
    if concrete_logistics.logistics.logistic_network == nil or concrete_logistics.logistics.logistic_network.all_construction_robots == 0 then
        if tick_interval_execute(concrete_logistics, "warn_no_construction_bots", 3600) then
            warn_no_construction_bots(concrete_logistics)
        end
    elseif concrete_logistics.pending_construction.count >= max_pending_construction(concrete_logistics) then
        if tick_interval_execute(concrete_logistics, "prevent_pending_construction_death", 600) then
            prevent_pending_construction_death(concrete_logistics)
        end
    elseif tick_interval_execute(concrete_logistics, "fulfill_deconstruction_request", 3) and concrete_logistics.pending_deconstruction.count > 0 then
        fulfill_deconstruction_request(concrete_logistics)
    elseif tick_interval_execute(concrete_logistics, "fulfill_construction_request", 3) and concrete_logistics.pending_concrete.count > 0 then
        fulfill_construction_request(concrete_logistics)
    elseif tick_interval_execute(concrete_logistics, "fill_concrete_gaps", 42) and concrete_logistics.pending_entities_second_pass.count > 0 then
        if concrete_logistics.fill_gaps then
            examine_entities_to_fill_concrete_gaps(concrete_logistics)
        else
            concrete_logistics.pending_entities_second_pass = circular_buffer.new()
        end
    elseif tick_interval_execute(concrete_logistics, "examine_nearby_entities", 14) and concrete_logistics.pending_entities.count > 0 then
        examine_nearby_entities_for_concrete_logistics(concrete_logistics, false)
    elseif tick_interval_execute(concrete_logistics, "rescan_entity_types", 3600) and #concrete_logistics.rescan_entity_types > 0 then
        local types = table.remove(concrete_logistics.rescan_entity_types, 1)
        update_entities_around_hub(concrete_logistics, types)
    end
end

function does_concrete_logistics_need_update(concrete_logistics)
    if concrete_logistics.pending_construction.count > 0 or concrete_logistics.pending_deconstruction.count > 0 then
        return true
    end
    if concrete_logistics.pending_concrete.count > 0 or concrete_logistics.pending_entities_second_pass.count > 0 then
        return true
    end
    if concrete_logistics.pending_entities.count > 0 or #concrete_logistics.rescan_entity_types > 0 then
        return true
    end
    return false
end

function tick_interval_execute(concrete_logistics, key, interval)
    if concrete_logistics.tick_timers == nil then
        concrete_logistics.tick_timers = { }
    end
    local data = concrete_logistics.tick_timers[key]
    if data == nil then
        data = { last_tick = game.tick, next_tick = game.tick + interval }
        concrete_logistics.tick_timers[key] = data
    end
    if game.tick >= data.next_tick then
        concrete_logistics.tick_timers[key] = { last_tick = game.tick, next_tick = game.tick + interval }
        return true
    end
    return false
end

function examine_nearby_entities_for_concrete_logistics(concrete_logistics)
    local entity_request = circular_buffer.pop(concrete_logistics.pending_entities)
    if entity_request.valid then
        plan_concrete_for_entity(concrete_logistics, entity_request, false)
        if concrete_logistics.fill_gaps then
            circular_buffer.append(concrete_logistics.pending_entities_second_pass, entity_request)
        end
    end
end

function examine_entities_to_fill_concrete_gaps(concrete_logistics)
    local entity_request = circular_buffer.pop(concrete_logistics.pending_entities_second_pass)
    if entity_request.valid then
        plan_concrete_for_entity(concrete_logistics, entity_request, true)
    end
end

function fulfill_deconstruction_request(concrete_logistics)
    local deconstruction_request = circular_buffer.pop(concrete_logistics.pending_deconstruction)
    local closest_cell = concrete_logistics.logistics.logistic_network.find_cell_closest_to(deconstruction_request.position)
    if closest_cell ~= nil and closest_cell.is_in_construction_range(deconstruction_request.position) then
        local data = {name = "deconstructible-tile-proxy", position = deconstruction_request.position, force = concrete_logistics.logistics.force}
        local tile_ghost = concrete_logistics.logistics.surface.create_entity(data)
        if tile_ghost ~= nil then
            circular_buffer.append(concrete_logistics.pending_construction, tile_ghost)
        end
    end
end

function fulfill_construction_request(concrete_logistics)
    local concrete_request = circular_buffer.pop(concrete_logistics.pending_concrete)
    local closest_cell = concrete_logistics.logistics.logistic_network.find_cell_closest_to(concrete_request.position)
    if concrete_request.concrete and closest_cell ~= nil and closest_cell.is_in_construction_range(concrete_request.position) then
        local data = {name = "tile-ghost", position = concrete_request.position, force = concrete_logistics.logistics.force, inner_name = concrete_request.concrete}
        local tile_ghost = concrete_logistics.logistics.surface.create_entity(data)
        if tile_ghost ~= nil then
            circular_buffer.append(concrete_logistics.pending_construction, tile_ghost)
        end
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
            if entity.name == "tile-ghost" then
                entity.time_to_live = entity.force.ghost_time_to_live
            end
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
