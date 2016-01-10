script.on_init(function()
    Logger.log("on_init Registering concrete-logistics-api")
    remote.call("WrenchFu", "register", "concrete-logistics", "concrete-logistics-api", "show_my_gui", "hide_my_gui")
end)

script.on_load(function()
    Logger.log("on_load Registering concrete-logistics-api")
    remote.call("WrenchFu", "register", "concrete-logistics", "concrete-logistics-api", "show_my_gui", "hide_my_gui")
end)

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
    for _, concrete_logistics in pairs(global.concrete_logistics_towers) do
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

    local data = {}
    for structure, concrete_setting in pairs(concrete_data) do
        local found = false
        for k, v in pairs(data) do
            if v.settings == concrete_setting then
                found = true
                break
            end
        end
        if not found then
            table.insert(data, {structure = structure, settings = concrete_setting})
        end
    end
    table.sort(data, function(a, b)
        return a.settings.priority < b.settings.priority
    end)
    
    local table = root.add({type="table", name="table", colspan = 8, style = "concrete-logistics-items-table"})
    local max_index = math.min(active_page * 10, #data)
    for i = ((active_page - 1) * 10) + 1, max_index do
        local concrete_data = data[i]
        
        local structure = concrete_data.structure
        local concrete_settings = concrete_data.settings
        local structure_name = game.entity_prototypes[concrete_settings.icon_name].localised_name
        if game.entity_prototypes[structure] then structure_name = game.entity_prototypes[structure].localised_name end

        Logger.log("Structure: " .. structure .. ", Concrete Settings: " .. serpent.line(concrete_settings))
        
        table.add({type="label", caption={"gui.settings.priority", concrete_settings.priority}})
        table.add({type = "frame", name="structure-" .. structure .. "-increase-priority", style = "concrete-logistics-up-arrow"})
        table.add({type = "frame", name="structure-" .. structure .. "-decrease-priority", style = "concrete-logistics-down-arrow"})
        
        table.add({type="checkbox", name="structure-icon-" .. structure, style="concrete-logistics-icon-" .. concrete_settings.icon_name, state = true})
        table.add({type="label", caption={"gui.settings.structure", structure_name}})
        
        table.add({type="checkbox", name="concrete-icon-" .. structure, style="concrete-logistics-icon-" .. concrete_settings.concrete, state = true})
        
        if concrete_settings.radius == 1 then
            table.add({type="label", caption={"gui.settings.radius_singular", concrete_settings.radius}, style = "tile-radius-label"})
        else
            table.add({type="label", caption={"gui.settings.radius", concrete_settings.radius}, style = "tile-radius-label"})
        end
        
        table.add({type="label", caption={"gui.settings.shape.square"}, style = "tile-radius-label"})
    end
end

function close_gui(player_index, concrete_logistics)
    local player = game.players[player_index]
    player.gui.center["concrete_logistics_frame"].destroy()
end
