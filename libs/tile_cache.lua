
tile_cache = {}
function tile_cache.new(pos, height, width)
    local cache = {center_position = {x = math.floor(pos.x), y = math.floor(pos.y)}, height = height, width = width, cache_table = {}}
    tile_cache.reset(cache)
    return cache
end

function tile_cache.reset(cache)
    cache.cache_table = {}
    for dx = 0, (cache.height * 2) - 1 do
        cache.cache_table[dx] = {}
    end
end

function tile_cache.get_value(cache, x, y)
    local cx = math.floor(x) + cache.height - cache.center_position.x
    local cy = math.floor(y) + cache.width - cache.center_position.x
    return cache.cache_table[cx][cy]
end

function tile_cache.set_value(cache, x, y, value)
    local cx = math.floor(x) + cache.height - cache.center_position.x
    local cy = math.floor(y) + cache.width - cache.center_position.x
    cache.cache_table[cx][cy] = value
end
