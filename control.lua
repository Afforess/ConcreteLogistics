require "defines"
require 'libs/utils'

local logger = require 'libs/logger'
local l = logger.new_logger("main")

script.on_event(defines.events.on_built_entity, function(event)
    if event.created_entity.name == "concrete-logistics" then
        if not global.concrete_logistics_towers then global.concrete_logistics_towers = {} end
        local pending = {entity = event.created_entity, row = 1, area = }
        local data = {logistics = event.created_entity, pending = {}, entities = {}}
        table.insert(global.concrete_logistics_towers, data)
    end
end)

script.on_event(defines.events.on_tick, function(event)
    if game.tick % 120 == 0 then
        if global.concrete_logistics_towers then 
            for i = #global.concrete_logistics_towers, 1, -1 do
                local data = global.concrete_logistics_towers[i]
                if data.logistics ~= nil and data.logistics.valid then
                    update_concrete_logistics(data)
                else
                    table.remove(global.concrete_logistics_towers, i)
                end
            end
        end
    end
end)

function update_concrete_logistics(data)
    if #data.pending > 0 then
        
    end
end

function update_pending_concrete_logistics(pending)
    
end

function entity_area(entity)
    local pos = entity.position
    local bb = entity.prototype.selection_box
    return {left_top = {x = bb.left_top.x + pos.x, y = bb.left_top.y + pos.y},
            right_bottom = {x = bb.right_bottom.x + pos.x, y = bb.right_bottom.y + pos.y}}
end

function expand_area(area, distance)
    return {left_top = {x = area.left_top.x - distance, y = area.left_top.y - distance},
            right_bottom = {x = area.right_bottom.x + distance, y = area.right_bottom.y + distance}}
end
