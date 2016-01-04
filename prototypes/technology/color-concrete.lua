data:extend(
{
    {
        type = "technology",
        name = "colored-concrete-2",
        icon = "__color-coding__/graphics/concrete/cyan/icon.png",
        effects =
        {
            {
                type = "unlock-recipe",
                recipe = "concrete-logistics"
            }
        },
        prerequisites = {"colored-concrete", "automated-construction", "logistic-system"},
        unit = {
            count = 50,
            ingredients = {
                {"science-pack-1", 4},
                {"science-pack-2", 3},
                {"science-pack-3", 2}
            },
            time = 30
        },
        order = "c-c-cc"
    }
}
)
