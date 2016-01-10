local styles = data.raw["gui-style"].default

styles["concrete-logistics-icon-base"] = {
  type = "checkbox_style",
  parent = "checkbox_style",
  width = 35,
  height = 35,
  hovered_background =
  {
    filename = "__ConcreteLogistics__/graphics/icons/blank.png",
    priority = "extra-high-no-scale",
    width = 32,
    height = 32
  },
  clicked_background =
  {
    filename = "__ConcreteLogistics__/graphics/icons/blank.png",
    priority = "extra-high-no-scale",
    width = 32,
    height = 32
  },
  checked =
  {
    filename = "__ConcreteLogistics__/graphics/icons/blank.png",
    priority = "extra-high-no-scale",
    width = 32,
    height = 32
  }
}

for _, type_data in pairs(data.raw) do
  local _, object = next(type_data)
  if object.stack_size then
    for name, item in pairs(type_data) do
      if item.icon then
        local style =
        {
          type = "checkbox_style",
          parent = "concrete-logistics-icon-base",
          default_background =
          {
            filename = item.icon,
            width = 32,
            height = 32
          },
          hovered_background =
          {
            filename = item.icon,
            width = 32,
            height = 32
          },
          clicked_background =
          {
            filename = item.icon,
            width = 32,
            height = 32
          }
        }
        data.raw["gui-style"].default["concrete-logistics-icon-" .. name] = style
      end
    end
  end
end
