# Lua Style Guide

Style conventions for Lua scripts and projects in this repository.

## Header

Every executable script starts with:

```lua
#!/usr/bin/env lua
```

## Comments

Avoid comments. Code should be self-explanatory through clear naming and structure.

If logic isn't obvious, refactor into a well-named function instead of adding a comment.

Use section headers to organize larger files:

```lua
-- patterns --

-- captures --

-- grammar --
```

Use `TODO` and `FIXME` tags when needed.

## Structure

Organize scripts in this order:

1. Shebang (for executables)
2. Local requires
3. Module table (if applicable)
4. Constants
5. Helper functions
6. Public functions
7. Main logic or module return

```lua
#!/usr/bin/env lua

local utils = require("utils")

local module = {}

local VERSION = "1.0.0"

local function helper()
end

function module.public_function()
end

return module
```

For executables, use a `main()` pattern:

```lua
#!/usr/bin/env lua

local function main()
    local args = parse_args(arg)
    do_work(args)
    os.exit(0)
end

main()
```

## Types

Primitives work directly on value: `string`, `number`, `boolean`, `nil`

Complex types work on reference: `table`, `function`, `userdata`

```lua
local foo = { 1, 2 }
local bar = foo
bar[1] = 9
print(foo[1]) -- 9 (same reference)
```

## Formatting

Use 4 spaces. No tabs. Use LF (Unix) line endings. No semicolons.

```lua
for i, pkg in ipairs(packages) do
    for name, version in pairs(pkg) do
        if name == searched then
            print(version)
        end
    end
end
```

Space after `--`, commas, around operators, and inside braces:

```lua
-- good comment
local x = y * 9
local numbers = { 1, 2, 3 }
local player = { name = "Jack" }
```

No spaces inside parentheses. Blank lines between functions:

```lua
local function foo()
end

local function bar()
end
```

Indent tables to the start of the line:

```lua
-- bad
local my_table = {
                   "hello",
                 }

-- good
local my_table = {
    "hello",
}
```

Avoid aligning variable declarations (produces noisy diffs).

## Variables

Always use `local` to declare variables:

```lua
-- bad
superpower = get_superpower()

-- good
local superpower = get_superpower()
```

Variables with larger scope need more descriptive names. One-letter names only for small scopes (under 10 lines) or iterators.

Use `_` for ignored variables:

```lua
for _, item in ipairs(items) do
  process(item)
end
```

Assign variables with the smallest possible scope.

## Naming Conventions

- `snake_case` for variables and functions
- `PascalCase` for classes (`MyClass`, `XmlParser`)
- `is_` or `has_` prefix for boolean functions
- `UPPER_CASE` sparingly for true constants
- Never `_UPPERCASE` (reserved by Lua)

```lua
local user_name = "jack"
local MAX_RETRIES = 3

local function is_valid(input)
    return input ~= nil
end

local Player = require("player")
```

## Strings

Use double quotes for consistency:

```lua
local name = "LuaRocks"
local path = "/usr/local/bin"
```

Use single quotes when the string contains double quotes:

```lua
local html = '<div class="container">'
```

Long strings across multiple lines using concatenation. The concatenation operator can omit spaces:

```lua
local message = "Hello, "..user.."! Day #"..day
```

## Tables

Prefer populating fields all at once. Trailing commas are encouraged:

```lua
local player = {
    name = "Jack",
    class = "Rogue",
}
```

Use plain `key` syntax when possible, `["key"]` for invalid identifiers:

```lua
local codes = { ["UTF-8"] = val1, ["1394-E"] = val2 }
```

Be aware that `nil` values don't count in `#` length. When tables have methods, use `self`:

```lua
local me = {
    fullname = function(self)
        return self.first_name .. " " .. self.last_name
    end
}
```

## Functions

Prefer function syntax over variable syntax:

```lua
-- bad
local nope = function(name) end

-- good
local function yup(name) end
```

Never name a parameter `arg` (conflicts with legacy Lua). Return early for validation:

```lua
local function is_good_name(name)
    if #name < 3 or #name > 30 then return false end
    return true
end
```

Always use parentheses in function calls:

```lua
-- bad
local bar = require "bar"

-- good
local bar = require("bar")
```

Exception: table arguments spanning multiple lines may omit parentheses:

```lua
local instance = module.new {
    param = 42,
}
```

### Functions in Tables

Declare module/class functions external to the table:

```lua
local module = {}

function module.hello()
    print("hello")
end
```

Declare metatable functions internal to the table:

```lua
local version_mt = {
    __eq = function(a, b) return a.major == b.major end,
    __lt = function(a, b) return a.major < b.major end,
}
```

## Properties

Use dot notation for known properties, brackets for dynamic access:

```lua
local is_jedi = luke.jedi
local value = config[key]
```

## Conditionals

False and nil are falsy. Use shortcuts:

```lua
-- bad
if name ~= nil then end

-- good
if name then end

local name = input or "default"
local result = condition and value_if_true or value_if_false
```

Note: `x and y or z` doesn't work if `y` can be `nil` or `false`.

Prefer true statements over false. Prefer defaults to else:

```lua
local function full_name(first, last)
    local name = "John Smith"
    if first and last then
        name = first .. " " .. last
    end
    return name
end
```

## Blocks

Single-line blocks for simple returns, breaks, and lambdas:

```lua
if not ok then return nil, "failed" end
if done then break end
use_callback(x, function(k) return k.last end)
```

## Type Checking

Use explicit conversion functions, not coercion:

```lua
-- bad
local total = score .. ""

-- good
local total = tostring(score)
local val = tonumber(input)
```

Add type assertions for function arguments when useful:

```lua
function load_manifest(repo_url, lua_version)
    assert(type(repo_url) == "string")
    assert(type(lua_version) == "string" or not lua_version)
end
```

## Error Handling

Return `nil` and error message for expected failures:

```lua
local function read_file(path)
    local file = io.open(path, "r")
    if not file then
        return nil, "cannot open: "..path
    end
    local content = file:read("*a")
    file:close()
    return content
end
```

Use `error()` or `assert()` for programming errors (API misuse):

```lua
local function process(config)
    assert(type(config) == "table", "config must be a table")
end
```

## Modules

Start with a local table named `module`. Return it at the end:

```lua
local module = {}

function module.say(greeting)
    print(greeting)
end

return module
```

For modules with circular dependencies, register early in `package.loaded`:

```lua
local module = {}
package.loaded["myproject.mymodule"] = module

local other = require("myproject.other")  -- can now require this module back
```

Require into local variables named after the last component:

```lua
-- bad
local skt = require("socket")

-- good
local socket = require("socket")
local client = require("http.client")
```

Create local aliases for frequently used functions (performance and readability):

```lua
local insert, concat = table.insert, table.concat
local match, gsub = string.match, string.gsub
```

Module rules:

- Do not set globals
- Requiring should cause no side effects (except loading dependencies)
- Modules are loaded as singletons; use factories for stateful objects

```lua
-- bad: module state
local mp = require("messagepack")
mp.set_integer("unsigned")

-- good: factory pattern
local messagepack = require("messagepack")
local mp = messagepack.new({ integer = "unsigned" })
```

## OOP

Use the idiomatic Lua OOP pattern with `Class:new(o)`:

```lua
local module = {}

local Player = {}

function Player:new(o)
    o = o or {
        name = "unknown",
        health = 100,
    }
    self.__index = self
    setmetatable(o, self)
    return o
end

function Player:take_damage(amount)
    self.health = self.health - amount
end

-- Expose class and convenience function
module.Player = Player

function module.create_player(name)
    return Player:new({ name = name, health = 100 })
end

return module
```

Use method notation (`:`) for method calls:

```lua
-- bad
my_object.my_method(my_object)

-- good
my_object:my_method()
```

Do not rely on `__gc` for non-memory resources. Add explicit `close` methods.

## Colors

Support `NO_COLOR` and `FORCE_COLOR` environment variables:

```lua
local function should_use_color()
    if os.getenv("FORCE_COLOR") then return true end
    if os.getenv("NO_COLOR") then return false end
    local term = os.getenv("TERM")
    if not term or term == "dumb" then return false end
    return true
end
```

Priority:

1. `FORCE_COLOR` set and non-empty: colors on
2. `NO_COLOR` set and non-empty: colors off
3. `TERM` is set and not `dumb`: colors on
4. Otherwise: colors off

References:

- <https://no-color.org>
- <https://force-color.org>

## Project Structure

```
project/
  bin/                    # Executables
  project/                # Main module directory
    init.lua              # Main module (require('project'))
    submodule.lua         # Submodules
  spec/                   # Tests (busted)
  project.rockspec.template  # LuaRocks template (for CI)
  README.md
  LICENSE
```

- Files named in lowercase with underscores
- Main module matches project name
- Tests mirror source structure

## Rockspec

```lua
local package_name = "myproject"
local package_version = "scm"
local rockspec_revision = "1"

package = package_name
version = package_version.."-"..rockspec_revision

source = {
    url = "git+https://github.com/user/myproject.git",
    branch = (package_version == "scm") and "main" or nil,
    tag = (package_version ~= "scm") and package_version or nil,
}

description = {
    summary = "Short description",
    license = "MIT",
}

dependencies = {
    "lua >= 5.1, < 5.5",
}

build = {
    type = "builtin",
    modules = {
        ["myproject"] = "myproject/init.lua",
    },
    install = {
        bin = { ["myproject"] = "bin/myproject.lua" },
    },
}
```

## Testing

Use busted. Write tests in `spec/` mirroring source structure.

Use descriptive `describe` and `it` blocks:

```lua
describe("utils", function()
    describe("parse_args", function()
        it("returns empty table for no arguments", function()
            assert.same({}, utils.parse_args({}))
        end)

        it("parses flags correctly", function()
            local result = utils.parse_args({ "-v", "--help" })
            assert.is_true(result.v)
            assert.is_true(result.help)
        end)
    end)
end)
```

Test interfaces, not private methods.

## Static Checking

Use luacheck:

```bash
luacheck myproject/ bin/ spec/
```

Configuration in `.luacheckrc`:

```lua
std = "lua51+lua52+lua53+lua54"
ignore = { "212" }  -- unused argument
```

Acceptable to ignore:

- 6xx warnings (whitespace)
- 211/212/213 (unused variables) when intentional for clarity
- 542 (empty if branch) in switch-style constructs

## References

- <https://github.com/luarocks/lua-style-guide>
- <https://github.com/Olivine-Labs/lua-style-guide>
- <http://lua-users.org/wiki/LuaStyleGuide>
