local module = {}

local fs = require("lnko.fs")

function module.can_fold(target_dir, source_dir)
    if not fs.is_directory(target_dir) then
        return false
    end

    local entries = fs.dir(target_dir)
    if #entries == 0 then
        return false
    end

    local parent_in_pkg = nil

    for _, entry in ipairs(entries) do
        local target_path = fs.join(target_dir, entry)

        if not fs.is_symlink(target_path) then
            return false
        end

        local link_dest = fs.symlink_target(target_path)
        if not link_dest then
            return false
        end

        local link_parent = fs.dirname(link_dest)

        if parent_in_pkg == nil then
            parent_in_pkg = link_parent
        elseif parent_in_pkg ~= link_parent then
            return false
        end
    end

    if not parent_in_pkg then
        return false
    end

    local resolved = fs.normalize(fs.join(target_dir, parent_in_pkg))
    local source_abs = fs.absolute(source_dir)

    return resolved:sub(1, #source_abs) == source_abs, parent_in_pkg
end

function module.should_unfold(target_path, pkg_path, source_dir)
    if not fs.is_symlink(target_path) then
        return false
    end

    local link_dest = fs.symlink_target(target_path)
    if not link_dest then
        return false
    end

    local resolved = fs.resolve_symlink(target_path)
    if not resolved then
        return false
    end

    local source_abs = fs.absolute(source_dir)

    if resolved:sub(1, #source_abs) ~= source_abs then
        return false
    end

    return fs.is_directory(resolved) and fs.is_directory(pkg_path)
end

function module.fold(target_dir, parent_link, plan)
    local plan_mod = require("lnko.plan")

    local entries = fs.dir(target_dir)
    for _, entry in ipairs(entries) do
        local target_path = fs.join(target_dir, entry)
        plan_mod.add_task(plan, plan_mod.ACTION_UNLINK, target_path)
    end

    plan_mod.add_task(plan, plan_mod.ACTION_RMDIR, target_dir)
    plan_mod.add_task(plan, plan_mod.ACTION_LINK, target_dir, parent_link)
end

function module.unfold(target_path, plan)
    local plan_mod = require("lnko.plan")

    local link_dest = fs.symlink_target(target_path)
    if not link_dest then
        return false
    end

    local resolved = fs.resolve_symlink(target_path)
    if not resolved or not fs.is_directory(resolved) then
        return false
    end

    plan_mod.add_task(plan, plan_mod.ACTION_UNLINK, target_path)
    plan_mod.add_task(plan, plan_mod.ACTION_MKDIR, target_path)

    local entries = fs.dir(resolved)
    for _, entry in ipairs(entries) do
        local source_path = fs.join(resolved, entry)
        local new_target = fs.join(target_path, entry)
        local rel_source = fs.relative(fs.dirname(new_target), source_path)
        plan_mod.add_task(plan, plan_mod.ACTION_LINK, new_target, rel_source)
    end

    return true
end

function module.find_foldable(target_dir, source_dir)
    local foldable = {}

    local function check_dir(dir)
        local can, parent = module.can_fold(dir, source_dir)
        if can then
            foldable[#foldable + 1] = { dir = dir, parent = parent }
        else
            local entries = fs.dir(dir)
            for _, entry in ipairs(entries) do
                local path = fs.join(dir, entry)
                if fs.is_directory(path) and not fs.is_symlink(path) then
                    check_dir(path)
                end
            end
        end
    end

    if fs.is_directory(target_dir) then
        check_dir(target_dir)
    end

    return foldable
end

return module
