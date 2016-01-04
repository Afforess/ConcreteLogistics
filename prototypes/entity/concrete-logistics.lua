data:extend({
    {
        type = "radar",
        name = "concrete-logistics",
        icon = "__ConcreteLogistics__/graphics/icons/concrete-logistics.png",
        flags = {"placeable-player", "player-creation"},
        minable = {hardness = 0.2, mining_time = 0.5, result = "concrete-logistics"},
        max_health = 150,
        corpse = "big-remnants",
        collision_box = {{-0.7, -0.7}, {0.7, 0.7}},
        selection_box = {{-1, -1}, {1, 1}},
        energy_per_sector = "1MJ",
        max_distance_of_sector_revealed = 1,
        max_distance_of_nearby_sector_revealed = 1,
        energy_per_nearby_scan = "250kJ",
        energy_source =
        {
            type = "electric",
            usage_priority = "secondary-input"
        },
        energy_usage = "300kW",
        pictures =
        {
            filename = "__ConcreteLogistics__/graphics/entity/concrete-logistics.png",
            priority = "low",
            width = 136,
            height = 132,
            shift = {1, -0.75},
            apply_projection = false,
            direction_count = 1,
            line_length = 1
        },
    }
})
