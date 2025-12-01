local module = {}

function module.make_lookup(value_type, t)
    value_type = value_type or "value"

    setmetatable(t, {
        __index = function(_, key)
            local keys = {}
            for k in pairs(t) do
                if type(k) == "string" then
                    keys[#keys + 1] = "\"" .. k .. "\""
                else
                    keys[#keys + 1] = tostring(k)
                end
            end
            table.sort(keys)
            local msg = "Invalid " .. value_type .. ": \"" .. tostring(key) .. "\""
            error(msg .. ". Expected one of: " .. table.concat(keys, ", "), 2)
        end,
    })

    return t
end

function module.keys(t)
    local result = {}
    for k in pairs(t) do
        result[#result + 1] = k
    end
    return result
end

function module.values(t)
    local result = {}
    for _, v in pairs(t) do
        result[#result + 1] = v
    end
    return result
end

function module.contains(t, value)
    for _, v in pairs(t) do
        if v == value then return true end
    end
    return false
end

function module.map(t, fn)
    local result = {}
    for i, v in ipairs(t) do
        result[i] = fn(v, i)
    end
    return result
end

function module.filter(t, fn)
    local result = {}
    for _, v in ipairs(t) do
        if fn(v) then
            result[#result + 1] = v
        end
    end
    return result
end

function module.escape_pattern(s)
    return s:gsub("([^%w])", "%%%1")
end

return module
