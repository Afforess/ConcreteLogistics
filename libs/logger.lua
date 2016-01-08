require "defines"

local _M = {}
local Logger = {prefix='concrete_logistics'}
Logger.__index = Logger

 -- tracks if the log file has ever been written to, for append vs replace in write_file
local ever_written = false
local debug = true

function Logger:log(str)
    local run_time_s = 0
    local run_time_minutes = 0
    local run_time_hours = 0
    if _G["game"] then
        run_time_s = math.floor(game.tick/60)
        run_time_minutes = math.floor(run_time_s/60)
        run_time_hours = math.floor(run_time_minutes/60)
    end
    self.log_buffer[#self.log_buffer + 1] = string.format("%02d:%02d:%02d: %s\r\n", run_time_hours, run_time_minutes % 60, run_time_s % 60, str)
    self:checkOutput()
end

function Logger:checkOutput()
    if self.last_write_size ~= #self.log_buffer and (debug or (game.tick - self.last_write_tick) > 3600) then
        self:dump()
    end
end

function Logger:dump()
    if _G["game"] then
        self.last_write_tick = game.tick
        self.last_write_size = #self.log_buffer
        local file_name = "logs/"..self.prefix.."/"..self.name..".log"
        game.write_file(file_name, table.concat(self.log_buffer), ever_written)
        self.log_buffer = {}
        ever_written = true
        return true
    end
    return false
end

function _M.new_logger(name)
    local temp = {name = name, log_buffer = {}, last_write_tick = 0, last_write_size = 0}
    local logger = setmetatable(temp, Logger)
    return logger
end
return _M
