---------------------------
    -- Functions --
---------------------------
Utils = {
    MySQLAsyncExecute  = function(query) -- MySQL Query Function
        local IsBusy = true
        local result = nil
        MySQL.Async.fetchAll(query, {}, function(data)
            result = data
            IsBusy = false
        end)
        while IsBusy do
            Citizen.Wait(0)
        end
        return result
end,
    round  = function(num, numDecimalPlaces) -- Round function
        local mult = 10^(numDecimalPlaces or 0)
        return math.floor(num * mult + 0.5) / mult
end,
    format_thousand  = function(v) -- Comma Value function
        local s = string.format("%d", math.floor(v))
        local pos = string.len(s) % 3
        if pos == 0 then pos = 2 end
        return string.sub(s, 1, pos)
                .. string.gsub(string.sub(s, pos + 1), "(...)", ".%1")
end,
    Distance = function(first, second) -- Distance between function
        local distance = #(first - second)
        return distance
end,
    GetLicense = function(source, type) -- Get License function
    for k,v in ipairs(GetPlayerIdentifiers(source)) do
        if string.sub(v, 1, string.len(t)) == string.lower(t) then
            return v
        end
    end
    return false
end,
}