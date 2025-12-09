local module = {}

local lfs = require("lfs")

local IS_WINDOWS = package.config:sub(1, 1) == "\\"

local function to_forward_slash(path)
    if IS_WINDOWS then
        return path:gsub("\\", "/")
    end
    return path
end

local function is_absolute(path)
    if path:sub(1, 1) == "/" then
        return true
    end
    if IS_WINDOWS and path:match("^%a:/") then
        return true
    end
    return false
end

function module.exists(path)
    return lfs.attributes(path) ~= nil
end

function module.is_directory(path)
    local attr = lfs.attributes(path)
    return attr and attr.mode == "directory"
end

function module.is_file(path)
    local attr = lfs.attributes(path)
    return attr and attr.mode == "file"
end

function module.is_symlink(path)
    local ok, attr = pcall(lfs.symlinkattributes, path)
    return ok and attr and attr.mode == "link"
end

function module.symlink_target(path)
    local ok, attr = pcall(lfs.symlinkattributes, path)
    if ok and attr and attr.mode == "link" then
        return to_forward_slash(attr.target)
    end
    return nil
end

function module.current_dir()
    return to_forward_slash(lfs.currentdir())
end

function module.change_dir(path)
    return lfs.chdir(path)
end

function module.mkdir(path)
    return lfs.mkdir(path)
end

function module.mkdir_p(path)
    if module.exists(path) then
        return true
    end

    local parent = module.dirname(path)
    if parent and parent ~= path and parent ~= "" then
        local ok, err = module.mkdir_p(parent)
        if not ok then
            return nil, err
        end
    end

    if not module.exists(path) then
        return lfs.mkdir(path)
    end

    return true
end

function module.rmdir(path)
    return lfs.rmdir(path)
end

function module.remove(path)
    return os.remove(path)
end

function module.symlink(target, link_path)
    return lfs.link(target, link_path, true)
end

function module.dir(path)
    local entries = {}
    for entry in lfs.dir(path) do
        if entry ~= "." and entry ~= ".." then
            entries[#entries + 1] = entry
        end
    end
    table.sort(entries)
    return entries
end

function module.walk(path, callback)
    local entries = module.dir(path)
    for _, entry in ipairs(entries) do
        local full_path = module.join(path, entry)
        callback(full_path, entry)
        if module.is_directory(full_path) and not module.is_symlink(full_path) then
            module.walk(full_path, callback)
        end
    end
end

function module.files_recursive(path)
    local files = {}
    module.walk(path, function(full_path)
        if module.is_file(full_path) or module.is_symlink(full_path) then
            files[#files + 1] = full_path
        end
    end)
    return files
end

function module.symlinks_recursive(path)
    local links = {}
    module.walk(path, function(full_path)
        if module.is_symlink(full_path) then
            links[#links + 1] = full_path
        end
    end)
    return links
end

function module.dirname(path)
    return path:match("(.+)/[^/]+$") or (path:match("^/") and "/" or ".")
end

function module.basename(path)
    return path:match("[^/]+$") or path
end

function module.join(...)
    local parts = { ... }
    local result = {}

    for _, part in ipairs(parts) do
        if part and part ~= "" then
            part = to_forward_slash(part)
            if is_absolute(part) then
                result = { part }
            elseif #result == 0 then
                result[#result + 1] = part
            else
                local last = result[#result]
                if last:sub(-1) == "/" then
                    result[#result + 1] = part
                else
                    result[#result + 1] = "/" .. part
                end
            end
        end
    end

    return table.concat(result)
end

function module.split(path)
    local parts = {}
    for part in path:gmatch("[^/]+") do
        parts[#parts + 1] = part
    end
    return parts
end

function module.relative(from_dir, to_path)
    from_dir = module.normalize(from_dir)
    to_path = module.normalize(to_path)
    local from_parts = module.split(from_dir)
    local to_parts = module.split(to_path)

    local common = 0
    for i = 1, math.min(#from_parts, #to_parts) do
        if from_parts[i] == to_parts[i] then
            common = i
        else
            break
        end
    end

    local result = {}

    for _ = common + 1, #from_parts do
        result[#result + 1] = ".."
    end

    for i = common + 1, #to_parts do
        result[#result + 1] = to_parts[i]
    end

    if #result == 0 then
        return "."
    end

    return table.concat(result, "/")
end

function module.absolute(path)
    path = to_forward_slash(path)
    if is_absolute(path) then
        return path
    end

    local cwd = module.current_dir()
    return module.join(cwd, path)
end

function module.resolve_symlink(path)
    if not module.is_symlink(path) then
        return path
    end

    local target = module.symlink_target(path)
    if not target then
        return nil
    end

    if target:sub(1, 1) == "/" then
        return target
    end

    local dir = module.dirname(path)
    return module.normalize(module.join(dir, target))
end

function module.normalize(path)
    path = to_forward_slash(path)
    local drive_prefix = ""
    if IS_WINDOWS and path:match("^%a:/") then
        drive_prefix = path:sub(1, 2)
        path = path:sub(3)
    end

    local parts = module.split(path)
    local result = {}
    local abs = path:sub(1, 1) == "/"

    for _, part in ipairs(parts) do
        if part == ".." then
            if #result > 0 and result[#result] ~= ".." then
                result[#result] = nil
            elseif not abs then
                result[#result + 1] = ".."
            end
        elseif part ~= "." then
            result[#result + 1] = part
        end
    end

    local normalized = table.concat(result, "/")
    if abs then
        return drive_prefix .. "/" .. normalized
    end

    return normalized ~= "" and normalized or "."
end

function module.symlink_points_to(link_path, expected_target)
    local target = module.symlink_target(link_path)
    if not target then
        return false
    end

    if target == expected_target then
        return true
    end

    local resolved = module.resolve_symlink(link_path)
    local expected_abs = module.absolute(expected_target)

    return resolved == expected_abs or module.normalize(resolved) == module.normalize(expected_abs)
end

return module
