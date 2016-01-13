
function reset_tile_caches()
    for _, concrete_logistics in pairs(global.concrete_logistics_hubs) do
        reset_tile_cache(concrete_logistics)
    end
end

function reset_tile_cache(concrete_logistics)
    concrete_logistics.tile_cache = tile_cache.new(concrete_logistics.logistics.position, 75, 75)
    concrete_logistics.cache_hits = 0
    concrete_logistics.cache_misses = 0
end

function get_cached_expected_tile_name(x, y, surface, force, concrete_logistics)
    if concrete_logistics.tile_cache == nil then
        reset_tile_cache(concrete_logistics)
    end
    local cache = concrete_logistics.tile_cache

    local cached_tile_name = tile_cache.get_value(cache, x, y)
    if cached_tile_name == nil then
        cached_tile_name = get_expected_tile_name(x, y, surface, force, concrete_logistics)
        tile_cache.set_value(cache, x, y, cached_tile_name)
        concrete_logistics.cache_misses = concrete_logistics.cache_misses + 1
    else
        concrete_logistics.cache_hits = concrete_logistics.cache_hits + 1
    end
    return cached_tile_name
end

function log_cache_stats()
    local hits = 0
    local misses = 0
    for _, concrete_logistics in pairs(global.concrete_logistics_hubs) do
        if concrete_logistics.cache_hits then
            hits = hits + concrete_logistics.cache_hits
        end
        if concrete_logistics.cache_misses then
            misses = misses + concrete_logistics.cache_misses
        end
    end
    if hits > 0 and misses > 0 then
        Logger.log("Cache hits: " .. hits .. ", Cache misses: " .. misses .. ", Ratio: " .. ((hits / (hits + misses)) * 100))
    end
end
