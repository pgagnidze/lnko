local module = {}

local stream = io.stderr

local function should_use_color()
    if os.getenv("FORCE_COLOR") then return true end
    if os.getenv("NO_COLOR") then return false end
    local term = os.getenv("TERM")
    if not term or term == "dumb" then return false end
    return true
end

local use_color = should_use_color()

local codes = {
    reset = 0,
    bold = 1,
    dim = 2,
    red = 31,
    green = 32,
    yellow = 33,
    blue = 34,
    magenta = 35,
    cyan = 36,
    white = 37,
    bright_black = 90,
}

local function seq(code)
    if not use_color then return "" end
    return string.char(27) .. "[" .. code .. "m"
end

module.codes = codes
module.use_color = use_color

function module.set_stream(fh)
    stream = fh
end

function module.write(...)
    local args = { ... }
    for i = 1, #args do
        args[i] = tostring(args[i])
    end
    stream:write(table.concat(args))
    stream:flush()
end

function module.print(...)
    local args = { ... }
    for i = 1, #args do
        args[i] = tostring(args[i])
    end
    stream:write(table.concat(args, "\t"), "\n")
    stream:flush()
end

function module.seq(code)
    return seq(code)
end

function module.color(name)
    local code = codes[name]
    if not code then return "" end
    return seq(code)
end

function module.reset()
    return seq(codes.reset)
end

function module.styled(style, text)
    if not use_color then return text end
    return seq(codes[style] or 0) .. text .. seq(codes.reset)
end

return module
