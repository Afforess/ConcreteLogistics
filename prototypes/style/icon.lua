local styles = data.raw["gui-style"].default

local down_arrow_style =
{
    type = "monolith",
    top_monolith_border = 1,
    right_monolith_border = 1,
    bottom_monolith_border = 1,
    left_monolith_border = 1,
    monolith_image =
    {
        filename = "__ConcreteLogistics__/graphics/icons/gui.png",
        priority = "extra-high-no-scale",
        width = 14,
        height = 14,
        x = 322,
        y = 9
    }
}

local up_arrow_style =
{
    type = "monolith",
    top_monolith_border = 1,
    right_monolith_border = 1,
    bottom_monolith_border = 1,
    left_monolith_border = 1,
    monolith_image =
    {
        filename = "__ConcreteLogistics__/graphics/icons/gui.png",
        priority = "extra-high-no-scale",
        width = 14,
        height = 14,
        x = 338,
        y = 9
    }
}
data.raw["gui-style"].default["concrete-logistics-down-arrow"] =
{
    type = "button_style",
    parent = "button_style",
    width = 14,
    height = 14,
    top_padding  = 0,
    right_padding = 0,
    bottom_padding = 0,
    left_padding = 0,
    scalable = false,
    default_graphical_set = down_arrow_style,
    hovered_graphical_set = down_arrow_style,
    clicked_graphical_set = down_arrow_style,
    disabled_graphical_set = down_arrow_style
}

data.raw["gui-style"].default["concrete-logistics-up-arrow"] =
{
    type = "button_style",
    parent = "button_style",
    width = 14,
    height = 14,
    top_padding  = 0,
    right_padding = 0,
    bottom_padding = 0,
    left_padding = 0,
    scalable = false,
    default_graphical_set = up_arrow_style,
    hovered_graphical_set = up_arrow_style,
    clicked_graphical_set = up_arrow_style,
    disabled_graphical_set = up_arrow_style
}


local icon_image_style =
{
    type = "monolith",
    top_monolith_border = 1,
    right_monolith_border = 1,
    bottom_monolith_border = 1,
    left_monolith_border = 1,
    monolith_image =
    {
        filename = "__ConcreteLogistics__/graphics/icons/blank.png",
        priority = "extra-high-no-scale",
        width = 32,
        height = 32
    }
}

styles["concrete-logistics-icon-base"] = {
    type = "button_style",
    parent = "button_style",
    width = 32,
    height = 32,
    top_padding = 0,
    right_padding = 0,
    bottom_padding = 0,
    left_padding = 0,
    default_graphical_set = icon_image_style,
    hovered_graphical_set = icon_image_style,
    clicked_graphical_set = icon_image_style,
    disabled_graphical_set = icon_image_style
}

for _, type_data in pairs(data.raw) do
    local _, object = next(type_data)
    if object.stack_size then
        for name, item in pairs(type_data) do
            if item.icon then
                local icon_style = {
                    type = "monolith",
                    top_monolith_border = 0,
                    right_monolith_border = 0,
                    bottom_monolith_border = 0,
                    left_monolith_border = 0,
                    monolith_image =
                    {
                        filename = item.icon,
                        priority = "extra-high-no-scale",
                        width = 32,
                        height = 32
                    }
                }
                local style =
                {
                    type = "button_style",
                    parent = "concrete-logistics-icon-base",
                    default_graphical_set = icon_style,
                    hovered_graphical_set = icon_style,
                    clicked_graphical_set = icon_style,
                    disabled_graphical_set = icon_style
                }
                data.raw["gui-style"].default["concrete-logistics-icon-" .. name] = style
            end
        end
    end
end
