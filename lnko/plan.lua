local module = {}

local fs = require("lnko.fs")

module.ACTION_LINK = "link"
module.ACTION_UNLINK = "unlink"
module.ACTION_MKDIR = "mkdir"
module.ACTION_RMDIR = "rmdir"
module.ACTION_BACKUP = "backup"

function module.new()
    return {
        tasks = {},
        conflicts = {},
    }
end

function module.add_task(plan, action, path, source, options)
    plan.tasks[#plan.tasks + 1] = {
        action = action,
        path = path,
        source = source,
        options = options or {},
    }
end

function module.add_conflict(plan, path, message)
    plan.conflicts[#plan.conflicts + 1] = {
        path = path,
        message = message,
    }
end

function module.has_conflicts(plan)
    return #plan.conflicts > 0
end

function module.get_conflicts(plan)
    return plan.conflicts
end

function module.get_tasks(plan)
    return plan.tasks
end

function module.execute(plan, options)
    options = options or {}
    local dry_run = options.dry_run
    local verbose = options.verbose
    local on_action = options.on_action

    local executed = 0
    local failed = 0

    for _, task in ipairs(plan.tasks) do
        local ok, err = true, nil

        if on_action then
            on_action(task.action, task.path, task.source)
        end

        if not dry_run then
            if task.action == module.ACTION_LINK then
                local target_dir = fs.dirname(task.path)
                if not fs.exists(target_dir) then
                    fs.mkdir_p(target_dir)
                end
                ok, err = fs.symlink(task.source, task.path)

            elseif task.action == module.ACTION_UNLINK then
                ok, err = fs.remove(task.path)

            elseif task.action == module.ACTION_MKDIR then
                ok, err = fs.mkdir_p(task.path)

            elseif task.action == module.ACTION_RMDIR then
                ok, err = fs.rmdir(task.path)

            elseif task.action == module.ACTION_BACKUP then
                local backup_path = task.options.backup_path
                local backup_dir = fs.dirname(backup_path)
                if not fs.exists(backup_dir) then
                    fs.mkdir_p(backup_dir)
                end
                ok, err = os.rename(task.path, backup_path)
            end
        end

        if ok then
            executed = executed + 1
        else
            failed = failed + 1
            if verbose and err then
                io.stderr:write("error: " .. task.path .. ": " .. tostring(err) .. "\n")
            end
        end
    end

    return executed, failed
end

function module.clear(plan)
    plan.tasks = {}
    plan.conflicts = {}
end

return module
