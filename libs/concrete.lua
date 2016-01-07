concrete_data = {}
concrete_data["transport-belt"]             = {search = 2, radius = 2, concrete = "concrete-yellow",       priority = 18}
concrete_data["transport-belt-to-ground"]   = concrete_data["transport-belt"]
concrete_data["splitter"]                   = concrete_data["transport-belt"]
concrete_data["inserter"]                   = {search = 2, radius = 1, concrete = "concrete",              priority = 19}
concrete_data["straight-rail"]              = {search = 4, radius = 3, concrete = "concrete-hazard-right", priority = 1 }
concrete_data["curved-rail"]                = concrete_data["straight-rail"]
concrete_data["assembling-machine"]         = {search = 4, radius = 2, concrete = "concrete-cyan",         priority = 4 }
concrete_data["furnace"]                    = {search = 4, radius = 1, concrete = "concrete-red",          priority = 3 }
concrete_data["boiler"]                     = {search = 4, radius = 3, concrete = "concrete-black",        priority = 5 }
concrete_data["electric-pole"]              = {search = 4, radius = 2, concrete = "concrete",              priority = 17}
concrete_data["container"]                  = {search = 2, radius = 1, concrete = "concrete",              priority = 16}
concrete_data["logistic-container"]         = concrete_data["container"]
concrete_data["generator"]                  = {search = 2, radius = 2, concrete = "concrete-black",        priority = 5 }
concrete_data["pipe"]                       = {search = 2, radius = 1, concrete = "concrete",              priority = 20}
concrete_data["pipe-to-ground"]             = concrete_data["pipe"]
concrete_data["pump"]                       = concrete_data["pipe"]
concrete_data["radar"]                      = {search = 4, radius = 3, concrete = "concrete",              priority = 15}
concrete_data["lamp"]                       = {search = 4, radius = 2, concrete = "concrete",              priority = 14}
concrete_data["wall"]                       = {search = 2, radius = 2, concrete = "concrete-hazard-left",  priority = 13}
concrete_data["turret"]                     = {search = 2, radius = 2, concrete = "concrete-hazard-left",  priority = 12}
concrete_data["train-stop"]                 = {search = 2, radius = 2, concrete = "concrete",              priority = 11}
concrete_data["lab"]                        = {search = 4, radius = 3, concrete = "concrete-purple",       priority = 6 }
concrete_data["rocket-silo"]                = {search = 5, radius = 5, concrete = "concrete-white",        priority = 7 }
concrete_data["roboport"]                   = {search = 5, radius = 5, concrete = "concrete",              priority = 8 }
concrete_data["accumulator"]                = {search = 2, radius = 2, concrete = "concrete-blue",         priority = 9 }
concrete_data["beacon"]                     = {search = 4, radius = 3, concrete = "concrete",              priority = 10}

function concrete_data_for_entity(entity)
    if concrete_data[entity.type] ~= nil then
        return concrete_data[entity.type]        
    end
    return nil
end

_max_concrete_distance = -1
function get_largest_concrete_radius()
    if _max_concrete_distance == -1 then
        for _, data in pairs(concrete_data) do
            if (data.radius > _max_concrete_distance) then
                _max_concrete_distance = data.radius
            end
        end
    end
    return _max_concrete_distance
end
