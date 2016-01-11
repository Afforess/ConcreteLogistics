script.on_init(function()
    remote.call("WrenchFu", "register", "concrete-logistics", "concrete-logistics-api", "show_my_gui", "hide_my_gui")
    
    init_concrete_data()
end)

script.on_load(function()
    remote.call("WrenchFu", "register", "concrete-logistics", "concrete-logistics-api", "show_my_gui", "hide_my_gui")
    
    init_concrete_data()
    -- clear old data
    global.concrete_logistics_towers = nil
end)

script.on_event(defines.events.on_gui_click, function(event)
    Logger.log("Element clicked: " .. event.element.name)

    local player = game.players[event.player_index]
    local gui_element = event.element
    if string.find(gui_element.name, "increase-priority", 1, true) or string.find(gui_element.name, "decrease-priority", 1, true) then
        local open_concrete_logistics = lookup_concrete_logistics_for_player(event.player_index)
        if open_concrete_logistics then
            update_priority(gui_element, open_concrete_logistics)
            render_main_gui(player, open_concrete_logistics, open_concrete_logistics.gui_data[event.player_index].active_page)
        end
    elseif gui_element.name == "cl-page-left" then
        local open_concrete_logistics = lookup_concrete_logistics_for_player(event.player_index)
        if open_concrete_logistics and open_concrete_logistics.gui_data[event.player_index].active_page > 1 then
            local player_gui_data = open_concrete_logistics.gui_data[event.player_index]
            player_gui_data.active_page = player_gui_data.active_page - 1
            render_main_gui(player, open_concrete_logistics, player_gui_data.active_page)
        end
    elseif gui_element.name == "cl-page-right" then
        local open_concrete_logistics = lookup_concrete_logistics_for_player(event.player_index)
        local max_page = math.floor(get_max_concrete_priority() / 10) + 1
        if open_concrete_logistics and open_concrete_logistics.gui_data[event.player_index].active_page < max_page then
            local player_gui_data = open_concrete_logistics.gui_data[event.player_index]
            player_gui_data.active_page = player_gui_data.active_page + 1
            render_main_gui(player, open_concrete_logistics, player_gui_data.active_page)
        end
    elseif string.find(gui_element.name, "structure-icon", 1, true) then
        local open_concrete_logistics = lookup_concrete_logistics_for_player(event.player_index)
        local editing_structure = find_structure_selected_in_gui(gui_element.name)
        if open_concrete_logistics and editing_structure then
            local player_gui_data = open_concrete_logistics.gui_data[event.player_index]
            if player_gui_data.editing_structure ~= editing_structure then
                player_gui_data.editing_structure = editing_structure
                update_entities_around_hub(open_concrete_logistics, concrete_data_for_type(editing_structure).types)
            end
            render_concrete_selection_gui(player, open_concrete_logistics, editing_structure)
        end
    elseif string.find(gui_element.name, "selection-concrete-icon", 1, true) then
        local open_concrete_logistics = lookup_concrete_logistics_for_player(event.player_index)
        if open_concrete_logistics then
            local structure = open_concrete_logistics.gui_data[event.player_index].editing_structure
            if structure then
                concrete_data_for_type(structure).concrete = find_concrete_selected_in_gui(gui_element.name)

                render_main_gui(player, open_concrete_logistics, open_concrete_logistics.gui_data[event.player_index].active_page)
            end
        end
    end
end)

function lookup_concrete_logistics_for_player(player_index)
    for _, concrete_logistics in pairs(global.concrete_logistics_hubs) do
        if concrete_logistics.gui_data[player_index] ~= nil then
            return concrete_logistics
        end
    end
    return nil
end

local interface = {}

function interface.show_my_gui(player_index, entity_name, position, surface_name)
    local player = game.players[player_index]
    if player ~= nil and player.valid and player.connected then
        local concrete_logistics = get_concrete_logistics(position, surface_name)
        if concrete_logistics ~= nil then
            open_gui(player_index, concrete_logistics)
        end
    end
end

function interface.hide_my_gui(player_index, entity_name, position, surface_name)
    local player = game.players[player_index]
    if player ~= nil and player.valid and player.connected then
        local concrete_logistics = get_concrete_logistics(position, surface_name)
        if concrete_logistics ~= nil then
            close_gui(player_index, concrete_logistics)
        end
    end
end

remote.add_interface("concrete-logistics-api", interface)

function get_concrete_logistics(position, surface_name)
    local surface = game.surfaces[surface_name]
    local entity = surface.find_entity("concrete-logistics", position)
    for _, concrete_logistics in pairs(global.concrete_logistics_hubs) do
        if concrete_logistics.logistics == entity then
            return concrete_logistics
        end
    end
    return nil
end

function open_gui(player_index, concrete_logistics)
    local player = game.players[player_index]
    
    if not concrete_logistics.gui_data then concrete_logistics.gui_data = {} end
    concrete_logistics.gui_data[player_index] = {active_page = 1}

    render_main_gui(player, concrete_logistics, 1)
end

function update_priority(gui_element, concrete_logistics)
    for i, concrete_data in pairs(global.concrete_data) do
        for j, structure in pairs(concrete_data.types) do
            local inc_priority = "structure-" .. structure .. "-increase-priority"
            if gui_element.name == inc_priority then
                increase_priority(concrete_data, concrete_logistics)
                update_entities_around_hub(concrete_logistics, concrete_data.types)
                return true
            end
            local dec_priority = "structure-" .. structure .. "-decrease-priority"
            if gui_element.name == dec_priority then
                decrease_priority(concrete_data, concrete_logistics)
                update_entities_around_hub(concrete_logistics, concrete_data.types)
                return true
            end
        end
    end
    return false
end

function decrease_priority(concrete_data, concrete_logistics)
    if concrete_data.priority > 1 then
        local priority = concrete_data.priority - 1
        concrete_data.priority = priority
        for _, concrete_item in pairs(global.concrete_data) do
            if concrete_data ~= concrete_item and concrete_item.priority == priority then
                concrete_item.priority = concrete_item.priority + 1
                update_entities_around_hub(concrete_logistics, concrete_item.types)
            end
        end
    end
end

function increase_priority(concrete_data, concrete_logistics)
    if concrete_data.priority < get_max_concrete_priority() then
        local priority = concrete_data.priority + 1
        concrete_data.priority = priority
        for _, concrete_item in pairs(global.concrete_data) do
            if concrete_data ~= concrete_item and concrete_item.priority == priority then
                concrete_item.priority = concrete_item.priority - 1
                update_entities_around_hub(concrete_logistics, concrete_item.types)
            end
        end
    end
end

local concrete_types = {"concrete-red", "concrete-orange", "concrete-yellow", "concrete-green", "concrete-cyan",
                        "concrete-blue", "concrete-purple", "concrete-magenta", "concrete-white", "concrete-black",
                        "concrete-hazard-left", "concrete-hazard-right", "concrete-fire-left", "concrete-fire-right"}

function find_concrete_selected_in_gui(name)
    for i = 1, #concrete_types do
        if name == ("selection-concrete-icon-" .. concrete_types[i]) then
            return concrete_types[i]
        end
    end
    return nil
end

function find_structure_selected_in_gui(name)
    for _, concrete_data in pairs(global.concrete_data) do
        if ("structure-icon-" .. concrete_data.types[1]) == name then
            return concrete_data.types[1]
        end
    end
    return nil
end

function render_concrete_selection_gui(player, concrete_logistics, editing_structure)
    if player.gui.center["concrete_logistics_frame"] then
        player.gui.center["concrete_logistics_frame"].destroy()
    end
    
    local structure_item = concrete_data_for_type(editing_structure).icon_name
    local structure_name = game.entity_prototypes[structure_item].localised_name

    local root = player.gui.center.add({type="frame", direction="vertical", name="concrete_logistics_frame", caption={"gui.settings"}})
    local title_bar = root.add({type="flow", name="title_bar", direction="horizontal", style="concrete-logistics-name-flow"})
    title_bar.add({type="button", name="structure-selection-icon-" .. editing_structure, style="concrete-logistics-icon-" .. structure_item})
    title_bar.add({type="label", style="structure-item-label-bold", caption={"gui.settings.structure", structure_name}})

    root.add({type="label", style="selection-instruction-label", caption={"gui.settings.selection"}})

    local row = nil
    for i = 0, #concrete_types - 1 do
        local index = i + 1
        if i % 5 == 0 then
            row = root.add({type="flow", direction="horizontal"})
        end
        row.add({type="button", name="selection-concrete-icon-" .. concrete_types[index], style="concrete-logistics-icon-" .. concrete_types[index]})
    end
end

function render_main_gui(player, concrete_logistics, active_page)
    if player.gui.center["concrete_logistics_frame"] then
        player.gui.center["concrete_logistics_frame"].destroy()
    end

    local root = player.gui.center.add({type="frame", direction="vertical", name="concrete_logistics_frame", caption={"gui.settings"}})
    
    local title_bar = root.add({type="flow", name="title_bar", direction="horizontal", style="concrete-logistics-name-flow"})
    title_bar.add({type="label", caption={"gui.settings.title_bar.priority"}, style="priority-label"})
    title_bar.add({type="label", caption={"gui.settings.title_bar.structure"}, style="structure-label"})
    title_bar.add({type="label", caption={"gui.settings.title_bar.concrete"}, style="concrete-label"})
    title_bar.add({type="label", caption={"gui.settings.title_bar.radius"}, style="radius-label"})
    title_bar.add({type="label", caption={"gui.settings.title_bar.shape"}, style="shape-label"})

    table.sort(global.concrete_data, function(a, b)
        return a.priority < b.priority
    end)
    
    local table = root.add({type="table", name="table", colspan = 8, style = "concrete-logistics-items-table"})
    local max_index = math.min(active_page * 10, #global.concrete_data)
    for i = ((active_page - 1) * 10) + 1, max_index do
        local concrete_data = global.concrete_data[i]
        
        local structure = concrete_data.types[1]
        local structure_name = game.entity_prototypes[concrete_data.icon_name].localised_name
        if game.entity_prototypes[structure] then structure_name = game.entity_prototypes[structure].localised_name end
        
        table.add({type="label", caption={"gui.settings.priority", concrete_data.priority}})
        table.add({type = "button", name="structure-" .. structure .. "-increase-priority", style = "concrete-logistics-up-arrow"})
        table.add({type = "button", name="structure-" .. structure .. "-decrease-priority", style = "concrete-logistics-down-arrow"})
        
        table.add({type="button", name="structure-dummy-icon-" .. structure, style="concrete-logistics-icon-" .. concrete_data.icon_name})
        table.add({type="label", style="structure-item-label", caption={"gui.settings.structure", structure_name}})
        
        table.add({type="button", name="structure-icon-" .. structure, style="concrete-logistics-icon-" .. concrete_data.concrete})
        
        if concrete_data.radius == 1 then
            table.add({type="label", caption={"gui.settings.radius_singular", concrete_data.radius}, style = "tile-radius-label"})
        else
            table.add({type="label", caption={"gui.settings.radius", concrete_data.radius}, style = "tile-radius-label"})
        end
        
        table.add({type="label", caption={"gui.settings.shape.square"}, style = "tile-radius-label"})
    end
    
    local page_navigation = root.add({type="flow", name="page_navigation", direction="horizontal", style="concrete-logistics-name-flow"})
    page_navigation.add({type="button", name="cl-page-left", style="button_style", caption = {"gui.settings.page_left"}})
    page_navigation.add({type="button", name="cl-page-number", style="button_style", caption = {"gui.settings.page", active_page, math.floor(#global.concrete_data / 10) + 1}})
    page_navigation.add({type="button", name="cl-page-right", style="button_style", caption = {"gui.settings.page_right"}})

end

function close_gui(player_index, concrete_logistics)
    local player = game.players[player_index]
    if player.gui.center["concrete_logistics_frame"] then
        player.gui.center["concrete_logistics_frame"].destroy()
    end
    concrete_logistics.gui_data[player_index] = nil
end
