local module = {}

local fs = require("lnko.fs")
local plan_mod = require("lnko.plan")

function module.can_unfold(target_path, pkg_path, source_dir, plan)
  if not plan_mod.is_a_link(plan, target_path) or not fs.is_directory(pkg_path) then return nil end

  local link_dest = plan_mod.read_a_link(plan, target_path)
  if not link_dest then return nil end

  local resolved
  if link_dest:sub(1, 1) == "/" then
    resolved = link_dest
  else
    resolved = fs.normalize(fs.join(fs.dirname(target_path), link_dest))
  end

  if not fs.is_directory(resolved) then return nil end

  if resolved:sub(1, #source_dir) ~= source_dir then return nil end

  return resolved
end

function module.unfold(target_path, existing_pkg_path, plan)
  plan_mod.add_task(plan, plan_mod.ACTION_UNLINK, target_path)
  plan_mod.add_task(plan, plan_mod.ACTION_MKDIR, target_path)

  local entries = fs.dir(existing_pkg_path)
  for _, entry in ipairs(entries) do
    local source_path = fs.join(existing_pkg_path, entry)
    local new_target = fs.join(target_path, entry)
    local rel_source = fs.relative(fs.dirname(new_target), source_path)
    plan_mod.add_task(plan, plan_mod.ACTION_LINK, new_target, rel_source)
  end
end

return module
