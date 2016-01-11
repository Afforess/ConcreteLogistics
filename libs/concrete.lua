concrete_data = {}
concrete_data["transport-belt"]             = {radius = 1, concrete = "concrete",              priority = 18, icon_name = "basic-transport-belt"}
concrete_data["transport-belt-to-ground"]   = concrete_data["transport-belt"]
concrete_data["splitter"]                   = concrete_data["transport-belt"]
concrete_data["inserter"]                   = {radius = 1, concrete = "concrete",              priority = 19, icon_name = "basic-inserter"}
concrete_data["straight-rail"]              = {radius = 3, concrete = "concrete-hazard-right", priority = 1 , icon_name = "straight-rail"}
concrete_data["curved-rail"]                = concrete_data["straight-rail"]
concrete_data["assembling-machine"]         = {radius = 2, concrete = "concrete-cyan",         priority = 3 , icon_name = "assembling-machine-2"}
concrete_data["furnace"]                    = {radius = 1, concrete = "concrete-red",          priority = 2 , icon_name = "electric-furnace"}
concrete_data["boiler"]                     = {radius = 3, concrete = "concrete-black",        priority = 5 , icon_name = "boiler"}
concrete_data["electric-pole"]              = {radius = 2, concrete = "concrete",              priority = 17, icon_name = "big-electric-pole"}
concrete_data["container"]                  = {radius = 1, concrete = "concrete",              priority = 16, icon_name = "steel-chest"}
concrete_data["smart-container"]            = concrete_data["container"]
concrete_data["logistic-container"]         = concrete_data["container"]
concrete_data["generator"]                  = {radius = 2, concrete = "concrete-black",        priority = 4 , icon_name = "steam-engine"}
concrete_data["pipe"]                       = {radius = 1, concrete = "concrete",              priority = 20, icon_name = "pipe"}
concrete_data["pipe-to-ground"]             = concrete_data["pipe"]
concrete_data["pump"]                       = concrete_data["pipe"]
concrete_data["radar"]                      = {radius = 3, concrete = "concrete",              priority = 15, icon_name = "radar"}
concrete_data["lamp"]                       = {radius = 2, concrete = "concrete",              priority = 14, icon_name = "small-lamp"}
concrete_data["wall"]                       = {radius = 2, concrete = "concrete-hazard-left",  priority = 13, icon_name = "stone-wall"}
concrete_data["turret"]                     = {radius = 2, concrete = "concrete-hazard-left",  priority = 12, icon_name = "gun-turret"}
concrete_data["ammo-turret"]                = concrete_data["turret"]
concrete_data["train-stop"]                 = {radius = 2, concrete = "concrete",              priority = 11, icon_name = "train-stop"}
concrete_data["lab"]                        = {radius = 3, concrete = "concrete-purple",       priority = 6 , icon_name = "lab"}
concrete_data["rocket-silo"]                = {radius = 2, concrete = "concrete-white",        priority = 7 , icon_name = "rocket-silo"}
concrete_data["roboport"]                   = {radius = 1, concrete = "concrete",              priority = 8 , icon_name = "roboport"}
concrete_data["accumulator"]                = {radius = 2, concrete = "concrete-blue",         priority = 9 , icon_name = "basic-accumulator"}
concrete_data["beacon"]                     = {radius = 3, concrete = "concrete",              priority = 10, icon_name = "basic-beacon"}
concrete_data["solar-panel"]                = {radius = 2, concrete = "concrete-white",        priority = 21, icon_name = "solar-panel"}

function save_concrete_data()
    if not global.concrete_data then
        global.concrete_data = concrete_data
    end
end

function concrete_data_for_entity(entity)
    if global.concrete_data[entity.type] ~= nil then
        return global.concrete_data[entity.type]        
    end
    return nil
end

_max_concrete_distance = -1
function get_largest_concrete_radius()
    if _max_concrete_distance == -1 then
        for _, data in pairs(global.concrete_data) do
            if (data.radius > _max_concrete_distance) then
                _max_concrete_distance = data.radius
            end
        end
    end
    return _max_concrete_distance
end

_max_concrete_priority = -1
function get_max_concrete_priority()
    if _max_concrete_priority == -1 then
        for _, data in pairs(global.concrete_data) do
            if (data.priority > _max_concrete_priority) then
                _max_concrete_priority = data.priority
            end
        end
    end
    return _max_concrete_priority
end
