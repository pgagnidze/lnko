rockspec_format = "3.0"
local package_name = "lnko"
local package_version = "scm"
local rockspec_revision = "1"
local github_account_name = "pgagnidze"
local github_repo_name = "lnko"

package = package_name
version = package_version .. "-" .. rockspec_revision

source = {
  url = "git+https://github.com/" .. github_account_name .. "/" .. github_repo_name .. ".git",
  branch = (package_version == "scm") and "main" or nil,
  tag = (package_version ~= "scm") and package_version or nil,
}

description = {
  summary = "A symlink farm manager, simpler alternative to GNU Stow",
  detailed = [[
    lnko is a symlink farm manager that helps organize dotfiles and
    configuration files. It creates symlinks from a source directory
    to a target directory, with support for tree folding, conflict
    handling, and two-phase execution.
  ]],
  license = "MIT",
  homepage = "https://github.com/" .. github_account_name .. "/" .. github_repo_name,
}

dependencies = {
  "lua >= 5.1, < 5.5",
  "luafilesystem >= 1.8.0",
}

test_dependencies = {
  "busted >= 2.0",
  "luacheck >= 1.0",
}

build = {
  type = "builtin",

  modules = {
    ["lnko.init"] = "src/lnko/init.lua",
    ["lnko.fs"] = "src/lnko/fs.lua",
    ["lnko.plan"] = "src/lnko/plan.lua",
    ["lnko.tree"] = "src/lnko/tree.lua",
    ["lnko.output"] = "src/lnko/output.lua",
    ["lnko.utils"] = "src/lnko/utils.lua",
  },

  install = {
    bin = {
      ["lnko"] = "bin/lnko.lua",
    }
  },
}
