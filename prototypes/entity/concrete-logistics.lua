data:extend({
    {
        type = "roboport",
        name = "concrete-logistics",
        icon = "__ConcreteLogistics__/graphics/icons/concrete-logistics.png",
        flags = {"placeable-player", "player-creation"},
        minable = {hardness = 0.2, mining_time = 0.5, result = "concrete-logistics"},
        max_health = 150,
        corpse = "small-remnants",
        collision_box = {{-0.7, -0.7}, {0.7, 0.7}},
        selection_box = {{-1, -1}, {1, 1}},
        dying_explosion = "medium-explosion",
        energy_source =
        {
            type = "electric",
            usage_priority = "secondary-input",
            input_flow_limit = "500kW",
            buffer_capacity = "50MJ"
        },
        recharge_minimum = "5MJ",
        energy_usage = "100kW",
        charging_energy = "0kW",
        logistics_radius = 0,
        construction_radius = 50,
        charge_approach_distance = 5,
        robot_slots_count = 0,
        material_slots_count = 0,
        stationing_offset = {0, 0},
        base =
        {
            filename = "__ConcreteLogistics__/graphics/entity/concrete-logistics.png",
            width = 136,
            height = 132,
            shift = {1, -0.75}
        },
        base_animation =
        {
            filename = "__ConcreteLogistics__/graphics/entity/roboport-chargepad.png",
            priority = "medium",
            width = 32,
            height = 32,
            frame_count = 6,
            shift = {0, -2.28125},
            animation_speed = 0.1,
        },
        base_patch =
        {
            filename = "__ConcreteLogistics__/graphics/entity/blank.png",
            width = 1,
            height = 1,
            frame_count = 1,
        },
        door_animation =
        {
            filename = "__ConcreteLogistics__/graphics/entity/blank.png",
            width = 1,
            height = 1,
            frame_count = 1,
        },
        door_animation_up =
        {
            filename = "__ConcreteLogistics__/graphics/entity/blank.png",
            width = 1,
            height = 1,
            frame_count = 1,
        },
        door_animation_down =
        {
            filename = "__ConcreteLogistics__/graphics/entity/blank.png",
            width = 1,
            height = 1,
            frame_count = 1,
        },
        recharging_animation =
        {
          filename = "__base__/graphics/entity/roboport/roboport-recharging.png",
          priority = "high",
          width = 37,
          height = 35,
          frame_count = 16,
          scale = 1.5,
          animation_speed = 0.5
        },
        recharging_light = {intensity = 0.4, size = 5},
        request_to_open_door_timeout = 3,
        spawn_and_station_height = 1.75,
        radius_visualisation_picture =
        {
            filename = "__base__/graphics/entity/roboport/roboport-radius-visualization.png",
            width = 12,
            height = 12,
            priority = "high"
        },
        construction_radius_visualisation_picture =
        {
            filename = "__ConcreteLogistics__/graphics/entity/roboport-concrete-radius-visualization.png",
            width = 12,
            height = 12,
            priority = "extra-high-no-scale"
        }
    }
})
