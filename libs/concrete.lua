concrete_data = {}
table.insert(concrete_data, {types = {"transport-belt","transport-belt-to-ground","splitter"}, shape = "square", radius = 1, concrete = "concrete", priority = 18, icon_name = "basic-transport-belt"})
table.insert(concrete_data, {types = {"inserter"}, shape = "square", radius = 1, concrete = "concrete", priority = 19, icon_name = "basic-inserter"})
table.insert(concrete_data, {types = {"straight-rail","curved-rail"}, shape = "square", radius = 2, concrete = "concrete-hazard-right", priority = 1 , icon_name = "straight-rail"})
table.insert(concrete_data, {types = {"assembling-machine"}, shape = "circle", radius = 2, concrete = "concrete-cyan", priority = 3 , icon_name = "assembling-machine-2"})
table.insert(concrete_data, {types = {"furnace"}, shape = "circle", radius = 1, concrete = "concrete-red", priority = 2 , icon_name = "electric-furnace"})
table.insert(concrete_data, {types = {"boiler"}, shape = "square", radius = 2, concrete = "concrete-black", priority = 5 , icon_name = "boiler"})
table.insert(concrete_data, {types = {"electric-pole"}, shape = "square", radius = 2, concrete = "concrete", priority = 17, icon_name = "big-electric-pole"})
table.insert(concrete_data, {types = {"container", "smart-container", "logistic-container"}, shape = "square", radius = 1, concrete = "concrete", priority = 16, icon_name = "steel-chest"})
table.insert(concrete_data, {types = {"generator"}, shape = "square", radius = 2, concrete = "concrete-black", priority = 4 , icon_name = "steam-engine"})
table.insert(concrete_data, {types = {"pipe", "pipe-to-ground", "pump"}, shape = "square", radius = 1, concrete = "concrete", priority = 20, icon_name = "pipe"})
table.insert(concrete_data, {types = {"radar"}, shape = "circle", radius = 3, concrete = "concrete", priority = 15, icon_name = "radar"})
table.insert(concrete_data, {types = {"lamp"}, shape = "circle", radius = 2, concrete = "concrete", priority = 14, icon_name = "small-lamp"})
table.insert(concrete_data, {types = {"wall"}, shape = "square", radius = 2, concrete = "concrete-hazard-left", priority = 13, icon_name = "stone-wall"})
table.insert(concrete_data, {types = {"turret", "ammo-turret"}, shape = "square", radius = 2, concrete = "concrete-hazard-left",  priority = 12, icon_name = "gun-turret"})
table.insert(concrete_data, {types = {"train-stop"}, shape = "square", radius = 2, concrete = "concrete", priority = 11, icon_name = "train-stop"})
table.insert(concrete_data, {types = {"lab"}, shape = "square", radius = 3, concrete = "concrete-purple", priority = 6, icon_name = "lab"})
table.insert(concrete_data, {types = {"rocket-silo"}, shape = "square", radius = 2, concrete = "concrete-white", priority = 7, icon_name = "rocket-silo"})
table.insert(concrete_data, {types = {"roboport"}, shape = "square", radius = 1, concrete = "concrete", priority = 8 , icon_name = "roboport"})
table.insert(concrete_data, {types = {"accumulator"}, shape = "square", radius = 2, concrete = "concrete-blue", priority = 9 , icon_name = "basic-accumulator"})
table.insert(concrete_data, {types = {"beacon"}, shape = "square", radius = 3, concrete = "concrete", priority = 10, icon_name = "basic-beacon"})
table.insert(concrete_data, {types = {"solar-panel"}, shape = "square", radius = 2, concrete = "concrete-white", priority = 21, icon_name = "solar-panel"})
_concrete_cache = {}

function init_concrete_data()
    if not global.concrete_data then
        global.concrete_data = concrete_data
    end
    local list = structure_for_each_concrete_data()
    for structure, concrete_data in pairs(list) do
        _concrete_cache[structure] = concrete_data
    end
end

function concrete_data_for_type(type)
    return _concrete_cache[type]
end

function structure_for_each_concrete_data()
    local table = {}
    for i, concrete_data in pairs(global.concrete_data) do
        for j, structure in pairs(concrete_data.types) do
            table[structure] = concrete_data
        end
    end
    return table
end

function concrete_data_for_entity(entity)
    return concrete_data_for_type(entity.type)
end

function set_concrete_shape(concrete_logistics, concrete_data, shape)
    local prev_shape = concrete_data.shape
    if prev_shape ~= shape then
        concrete_data.shape = shape
        update_entities_around_hub(concrete_logistics, concrete_data.types)
        reset_tile_caches()
        return true
    end
    return false
end

function set_concrete_data_priority(concrete_logistics, concrete_data, priority)
    local prev_priority = concrete_data.priority
    if prev_priority ~= priority then
        concrete_data.priority = priority
        update_entities_around_hub(concrete_logistics, concrete_data.types)
        reset_tile_caches()
        return true
    end
    return false
end

function set_concrete_data_radius(concrete_logistics, concrete_data, radius)
    local prev_radius = concrete_data.radius
    concrete_data.radius = math.max(0, math.min(10, radius))
    if prev_radius ~= concrete_data.radius then
        _max_concrete_distance = -1
        update_entities_around_hub(concrete_logistics, concrete_data.types)
        reset_tile_caches()
        return true
    end
    return false
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
