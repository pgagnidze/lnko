#!/usr/bin/env lua

-- Configuration
local CC = os.getenv("CC") or "cc"
local NM = os.getenv("NM") or "nm"
local BUILD_DIR = os.getenv("BUILD_DIR") or ".build"

-- Colors
local colors = { red = "", green = "", yellow = "", blue = "", bold = "", reset = "" }

local function setup_colors()
    local force = os.getenv("FORCE_COLOR")
    local no_color = os.getenv("NO_COLOR")
    local is_tty = os.getenv("TERM") and os.getenv("TERM") ~= "dumb"

    local use_color = false
    if force and force ~= "" then
        use_color = true
    elseif no_color and no_color ~= "" then
        use_color = false
    elseif is_tty then
        use_color = true
    end

    if use_color then
        colors.red = "\27[31m"
        colors.green = "\27[32m"
        colors.yellow = "\27[33m"
        colors.blue = "\27[34m"
        colors.bold = "\27[1m"
        colors.reset = "\27[0m"
    end
end

local function log(level, msg)
    local color = ({
        info = colors.blue,
        success = colors.green,
        warn = colors.yellow,
        error = colors.red,
    })[level] or ""

    local out = string.format("%s[%s]%s %s\n", color, level, colors.reset, msg)
    if level == "error" then
        io.stderr:write(out)
    else
        io.write(out)
    end
end

local function show_help()
    print(string.format([[
%sluas%s - lua static build

Build a standalone static binary from a LuaRocks project or Lua files.

Usage: lua luas.lua [options] [output-name]

Arguments:
    output-name     Name of output binary (default: <package>-static)

Options:
    -h, --help      Show this help message
    -r, --rockspec  Path to rockspec file (default: auto-detect)
    -m, --main      Main Lua script (entry point)
    -l, --lua       Lua module files (can be repeated or use globs)
    -c, --clib      Static C library to link (can be repeated)
    --lfs           Shorthand for --clib that builds LuaFileSystem

Environment:
    BUILD_DIR       Build directory (default: .build)
    CC              C compiler (default: cc)
    NM              nm tool (default: nm)
    LUA_INCDIR      Lua include directory (default: auto-detect)
    LUA_STATIC_LIB  Path to liblua.a (default: auto-detect)

Examples:
    lua luas.lua
    lua luas.lua myapp-linux_x86_64
    lua luas.lua -r myapp-1.0-1.rockspec myapp
    lua luas.lua --main bin/app.lua --lua "lib/*.lua" --clib lpeg.a myapp
    lua luas.lua --lfs --clib lpeg.a myapp
]], colors.bold, colors.reset))
end

-- utility functions --

local function execute(cmd)
    local ok = os.execute(cmd)
    return (ok == true or ok == 0)
end

local function shellout(command)
    local handle = io.popen(command .. " 2>/dev/null")
    if not handle then
        return ""
    end
    local stdout = handle:read("*a")
    handle:close()
    return stdout and stdout:gsub("%s+$", "") or ""
end

local function file_exists(path)
    local f = io.open(path, "r")
    if f then
        f:close()
        return true
    end
    return false
end

local function dir_exists(path)
    local ok, _, code = os.rename(path .. "/", path .. "/")
    return ok or code == 13
end

local function mkdir(path)
    local sep = package.config:sub(1, 1)
    local cmd = sep == "\\" and 'mkdir "' .. path .. '" 2>nul' or 'mkdir -p "' .. path .. '"'
    os.execute(cmd)
end

local function glob(pattern)
    local sep = package.config:sub(1, 1)
    local cmd = sep == "\\" and 'dir /b "' .. pattern .. '" 2>nul' or 'ls -1 ' .. pattern .. ' 2>/dev/null'
    local handle = io.popen(cmd)
    if not handle then
        return {}
    end
    local files = {}
    for line in handle:lines() do
        table.insert(files, line)
    end
    handle:close()
    return files
end

local function basename(path)
    return path:gsub([[(.*[\/])(.*)]], "%2")
end

-- detect os and paths --

local function detect_os()
    local sep = package.config:sub(1, 1)
    if sep == "\\" then
        return "Windows", os.getenv("PROCESSOR_ARCHITECTURE") or "x86_64"
    end
    local os_name = shellout("uname -s")
    local arch = shellout("uname -m")
    return os_name ~= "" and os_name or "Unknown", arch ~= "" and arch or "x86_64"
end

local function find_lua_paths(os_name)
    log("info", "detecting lua installation")

    local lua_incdir = os.getenv("LUA_INCDIR")
    local lua_static_lib = os.getenv("LUA_STATIC_LIB")

    if not lua_incdir then
        local result = shellout("pkg-config --variable=includedir lua5.4 2>/dev/null")
        if result == "" then
            result = shellout("pkg-config --variable=includedir lua 2>/dev/null")
        end
        if result ~= "" then
            lua_incdir = result
            for _, subdir in ipairs({ "/lua5.4", "/lua54", "/lua", "" }) do
                if file_exists(lua_incdir .. subdir .. "/lua.h") then
                    lua_incdir = lua_incdir .. subdir
                    break
                end
            end
        end
    end

    if not lua_incdir then
        local search_paths = {
            "/usr/include/lua5.4", "/usr/include/lua54", "/usr/include/lua", "/usr/include",
            "/usr/local/include/lua54", "/usr/local/include",
            "/opt/homebrew/include/lua", "/opt/homebrew/include",
        }
        for _, dir in ipairs(search_paths) do
            if file_exists(dir .. "/lua.h") then
                lua_incdir = dir
                break
            end
        end
    end

    if not lua_static_lib then
        local search_paths = {
            "/usr/lib64", "/usr/lib/x86_64-linux-gnu", "/usr/lib/aarch64-linux-gnu",
            "/usr/lib", "/usr/local/lib", "/opt/homebrew/lib",
        }
        local lib_names = { "liblua.a", "liblua5.4.a", "liblua54.a" }

        for _, dir in ipairs(search_paths) do
            for _, name in ipairs(lib_names) do
                local path = dir .. "/" .. name
                if file_exists(path) then
                    lua_static_lib = path
                    break
                end
            end
            if lua_static_lib then break end
        end
    end

    if not lua_static_lib and os_name == "Darwin" then
        local prefix = shellout("brew --prefix lua 2>/dev/null")
        if prefix ~= "" then
            local path = prefix .. "/lib/liblua.a"
            if file_exists(path) then
                lua_static_lib = path
            end
        end
    end

    if not lua_incdir or not file_exists(lua_incdir .. "/lua.h") then
        log("error", "cannot find lua.h (set LUA_INCDIR)")
        os.exit(1)
    end

    if not lua_static_lib or not file_exists(lua_static_lib) then
        log("error", "cannot find liblua.a (set LUA_STATIC_LIB)")
        os.exit(1)
    end

    log("success", "lua include: " .. lua_incdir)
    log("success", "lua static lib: " .. lua_static_lib)

    return lua_incdir, lua_static_lib
end

-- rockspec parsing --

local function find_rockspec(specified)
    if specified then
        if not file_exists(specified) then
            log("error", "rockspec not found: " .. specified)
            os.exit(1)
        end
        return specified
    end

    local files = glob("*.rockspec")
    if #files == 0 then
        log("error", "no rockspec found in current directory")
        os.exit(1)
    end

    log("success", "found rockspec: " .. files[1])
    return files[1]
end

local function parse_rockspec(path)
    log("info", "parsing rockspec")

    local env = {}
    local chunk, err = loadfile(path, "t", env)
    if not chunk then
        log("error", "failed to load rockspec: " .. err)
        os.exit(1)
    end
    chunk()

    local package_name = env.package
    if not package_name then
        log("error", "cannot find package name in rockspec")
        os.exit(1)
    end

    local bin_script
    if env.build and env.build.install and env.build.install.bin then
        for _, script in pairs(env.build.install.bin) do
            bin_script = script
            break
        end
    end

    if not bin_script or not file_exists(bin_script) then
        log("error", "cannot find bin script in rockspec")
        os.exit(1)
    end

    local module_files = {}
    if env.build and env.build.modules then
        for _, file in pairs(env.build.modules) do
            if type(file) == "string" and file:match("%.lua$") then
                table.insert(module_files, file)
            end
        end
    end
    table.sort(module_files)

    log("success", "package: " .. package_name)
    log("success", "bin script: " .. bin_script)
    log("success", "modules: " .. #module_files .. " files")

    return {
        name = package_name,
        bin = bin_script,
        modules = module_files,
    }
end

-- build luafilesystem --

local function build_lfs_static(lua_incdir)
    log("info", "building luafilesystem static library")

    local lfs_a = BUILD_DIR .. "/lfs.a"
    if file_exists(lfs_a) then
        log("success", "lfs.a exists, skipping")
        return lfs_a
    end

    local lfs_dir = BUILD_DIR .. "/luafilesystem"
    if not dir_exists(lfs_dir) then
        log("info", "cloning luafilesystem")
        if not execute("git clone --quiet --depth 1 https://github.com/lunarmodules/luafilesystem.git " .. lfs_dir) then
            log("error", "failed to clone luafilesystem")
            os.exit(1)
        end
    end

    local cmd = string.format('%s -c -O2 -fPIC -I"%s" "%s/src/lfs.c" -o "%s/lfs.o"',
        CC, lua_incdir, lfs_dir, BUILD_DIR)
    if not execute(cmd) then
        log("error", "failed to compile lfs.c")
        os.exit(1)
    end

    cmd = string.format('ar rcs "%s" "%s/lfs.o"', lfs_a, BUILD_DIR)
    if not execute(cmd) then
        log("error", "failed to create lfs.a")
        os.exit(1)
    end

    log("success", "built lfs.a")
    return lfs_a
end

-- embedded luastatic --

local function string_to_c_hex_literal(characters)
    local hex = {}
    for character in characters:gmatch(".") do
        table.insert(hex, ("0x%02x"):format(string.byte(character)))
    end
    return table.concat(hex, ", ")
end

local function luastatic_build(lua_source_files, module_library_files, dep_library_files, output_name, lua_incdir, other_args)
    local mainlua = lua_source_files[1]

    local outfilename = BUILD_DIR .. "/" .. basename(mainlua.path):gsub("%.lua$", "") .. ".luastatic.c"
    local outfile = io.open(outfilename, "w+")
    if not outfile then
        log("error", "cannot create file: " .. outfilename)
        os.exit(1)
    end

    local function out(...)
        outfile:write(...)
    end

    local function outhex(str)
        outfile:write(string_to_c_hex_literal(str), ", ")
    end

    local function out_lua_source(file)
        local f = io.open(file.path, "r")
        if not f then
            log("error", "cannot open file: " .. file.path)
            os.exit(1)
        end
        local prefix = f:read(4)
        if prefix then
            if prefix:match("\xef\xbb\xbf") then
                prefix = prefix:sub(4)
            end
            if prefix:match("#") then
                local _ = f:read("*line") -- discard shebang line
                prefix = "\n"
            end
            out(string_to_c_hex_literal(prefix), ", ")
        end
        while true do
            local strdata = f:read(4096)
            if strdata then
                out(string_to_c_hex_literal(strdata), ", ")
            else
                break
            end
        end
        f:close()
    end

    out([[
#ifdef __cplusplus
extern "C" {
#endif
#include <lauxlib.h>
#include <lua.h>
#include <lualib.h>
#ifdef __cplusplus
}
#endif
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if LUA_VERSION_NUM == 501
    #define LUA_OK 0
#endif

static lua_State *globalL = NULL;

static void lstop (lua_State *L, lua_Debug *ar) {
    (void)ar;
    lua_sethook(L, NULL, 0, 0);
    luaL_error(L, "interrupted!");
}

static void laction (int i) {
    signal(i, SIG_DFL);
    lua_sethook(globalL, lstop, LUA_MASKCALL | LUA_MASKRET | LUA_MASKCOUNT, 1);
}

static void createargtable (lua_State *L, char **argv, int argc, int script) {
    int i, narg;
    if (script == argc) script = 0;
    narg = argc - (script + 1);
    lua_createtable(L, narg, script + 1);
    for (i = 0; i < argc; i++) {
        lua_pushstring(L, argv[i]);
        lua_rawseti(L, -2, i - script);
    }
    lua_setglobal(L, "arg");
}

static int msghandler (lua_State *L) {
    const char *msg = lua_tostring(L, 1);
    if (msg == NULL) {
        if (luaL_callmeta(L, 1, "__tostring") && lua_type(L, -1) == LUA_TSTRING)
            return 1;
        else
            msg = lua_pushfstring(L, "(error object is a %s value)", luaL_typename(L, 1));
    }
    lua_getglobal(L, "debug");
    lua_getfield(L, -1, "traceback");
    lua_remove(L, -2);
    lua_pushstring(L, msg);
    lua_remove(L, -3);
    lua_pushinteger(L, 2);
    lua_call(L, 2, 1);
    return 1;
}

static int docall (lua_State *L, int narg, int nres) {
    int status;
    int base = lua_gettop(L) - narg;
    lua_pushcfunction(L, msghandler);
    lua_insert(L, base);
    globalL = L;
    signal(SIGINT, laction);
    status = lua_pcall(L, narg, nres, base);
    signal(SIGINT, SIG_DFL);
    lua_remove(L, base);
    return status;
}

#ifdef __cplusplus
extern "C" {
#endif
]])

    for _, library in ipairs(module_library_files) do
        out(('    int luaopen_%s(lua_State *L);\n'):format(library.dotpath_underscore))
    end

    out([[
#ifdef __cplusplus
}
#endif

int main(int argc, char *argv[])
{
    lua_State *L = luaL_newstate();
    luaL_openlibs(L);
    createargtable(L, argv, argc, 0);

    static const unsigned char lua_loader_program[] = {
        ]])

    outhex([[
local args = {...}
local lua_bundle = args[1]

local function load_string(str, name)
    if _VERSION == "Lua 5.1" then
        return loadstring(str, name)
    else
        return load(str, name)
    end
end

local function lua_loader(name)
    local separator = package.config:sub(1, 1)
    name = name:gsub(separator, ".")
    local mod = lua_bundle[name] or lua_bundle[name .. ".init"]
    if mod then
        if type(mod) == "string" then
            local chunk, errstr = load_string(mod, name)
            if chunk then
                return chunk
            else
                error(
                    ("error loading module '%s' from luastatic bundle:\n\t%s"):format(name, errstr),
                    0
                )
            end
        elseif type(mod) == "function" then
            return mod
        end
    else
        return ("\n\tno module '%s' in luastatic bundle"):format(name)
    end
end
table.insert(package.loaders or package.searchers, 2, lua_loader)

local unpack = unpack or table.unpack
]])

    outhex(([[
local func = lua_loader("%s")
if type(func) == "function" then
    func(unpack(arg))
else
    error(func, 0)
end
]]):format(mainlua.dotpath_noextension))

    out(([[

    };
    if (luaL_loadbuffer(L, (const char*)lua_loader_program, sizeof(lua_loader_program), "%s") != LUA_OK)
    {
        fprintf(stderr, "luaL_loadbuffer: %%s\n", lua_tostring(L, -1));
        lua_close(L);
        return 1;
    }

    lua_newtable(L);
]]):format(mainlua.basename_noextension))

    for i, file in ipairs(lua_source_files) do
        out(('    static const unsigned char lua_require_%i[] = {\n        '):format(i))
        out_lua_source(file)
        out("\n    };\n")
        out(([[
    lua_pushlstring(L, (const char*)lua_require_%i, sizeof(lua_require_%i));
]]):format(i, i))
        out(('    lua_setfield(L, -2, "%s");\n\n'):format(file.dotpath_noextension))
    end

    for _, library in ipairs(module_library_files) do
        out(('    lua_pushcfunction(L, luaopen_%s);\n'):format(library.dotpath_underscore))
        out(('    lua_setfield(L, -2, "%s");\n\n'):format(library.dotpath_noextension))
    end

    out([[
    if (docall(L, 1, LUA_MULTRET))
    {
        const char *errmsg = lua_tostring(L, 1);
        if (errmsg)
        {
            fprintf(stderr, "%s\n", errmsg);
        }
        lua_close(L);
        return 1;
    }
    lua_close(L);
    return 0;
}
]])

    outfile:close()

    local UNAME = shellout("uname -s")
    local rdynamic = "-rdynamic"

    if UNAME == "" or shellout(CC .. " -dumpmachine"):match("mingw") then
        rdynamic = ""
    end

    local link_with_libdl = ""
    if UNAME == "Linux" or UNAME == "SunOS" then
        link_with_libdl = "-ldl"
    end

    local module_libs = {}
    for _, lib in ipairs(module_library_files) do
        table.insert(module_libs, lib.path)
    end

    local output_path = BUILD_DIR .. "/" .. output_name

    local compile_command = table.concat({
        CC,
        "-Os",
        outfilename,
        table.concat(module_libs, " "),
        table.concat(dep_library_files, " "),
        rdynamic,
        "-lm",
        link_with_libdl,
        "-I" .. lua_incdir,
        "-o " .. output_path,
        table.concat(other_args or {}, " "),
    }, " ")

    if not execute(compile_command) then
        log("error", "compilation failed")
        os.exit(1)
    end

    execute("strip " .. output_path .. " 2>/dev/null")

    return output_path
end

-- build binary --

local function build_binary(spec, output_name, lua_incdir, lua_static_lib, clib_files)
    log("info", "building static binary")

    local lua_source_files = {}

    local function add_source(path)
        local info = {}
        info.path = path
        info.basename = basename(path)
        info.basename_noextension = info.basename:match("(.+)%.") or info.basename
        info.dotpath = path:gsub("^%.%/", ""):gsub("[\\/]", ".")
        info.dotpath_noextension = info.dotpath:match("(.+)%.") or info.dotpath
        info.dotpath_underscore = info.dotpath_noextension:gsub("[.-]", "_")
        table.insert(lua_source_files, info)
    end

    add_source(spec.bin)
    for _, f in ipairs(spec.modules) do
        add_source(f)
    end

    local module_library_files = {}
    for _, clib in ipairs(clib_files or {}) do
        local nmout = shellout(NM .. " " .. clib)
        for luaopen in nmout:gmatch("[^dD] _?luaopen_([%a%p%d]+)") do
            table.insert(module_library_files, {
                path = clib,
                dotpath_underscore = luaopen,
                dotpath_noextension = luaopen:gsub("_", "."),
            })
        end
    end

    local dep_library_files = { lua_static_lib }

    local output_path = luastatic_build(
        lua_source_files,
        module_library_files,
        dep_library_files,
        output_name,
        lua_incdir,
        {}
    )

    log("success", "built " .. output_path)
    return output_path
end

-- finalize --

local function finalize(binary_path, output_name)
    local dst = "./" .. output_name

    local src_file = io.open(binary_path, "rb")
    if not src_file then
        log("error", "cannot open binary: " .. binary_path)
        os.exit(1)
    end

    local dst_file = io.open(dst, "wb")
    if not dst_file then
        log("error", "cannot create output: " .. dst)
        src_file:close()
        os.exit(1)
    end

    dst_file:write(src_file:read("*a"))
    src_file:close()
    dst_file:close()

    execute("chmod +x " .. dst .. " 2>/dev/null")

    local size = shellout("du -h " .. dst):match("^%S+") or "?"
    log("success", "output: " .. dst .. " (" .. size .. ")")
end

-- main --

local function parse_args(args)
    local opts = {
        rockspec = nil,
        output = nil,
        main = nil,
        lua_files = {},
        clibs = {},
        lfs = false,
    }
    local i = 1
    while i <= #args do
        local a = args[i]
        if a == "-h" or a == "--help" then
            show_help()
            os.exit(0)
        elseif a == "-r" or a == "--rockspec" then
            i = i + 1
            opts.rockspec = args[i]
        elseif a == "-m" or a == "--main" then
            i = i + 1
            opts.main = args[i]
        elseif a == "-l" or a == "--lua" then
            i = i + 1
            local pattern = args[i]
            if pattern:match("[*?]") then
                for _, f in ipairs(glob(pattern)) do
                    table.insert(opts.lua_files, f)
                end
            else
                table.insert(opts.lua_files, pattern)
            end
        elseif a == "-c" or a == "--clib" then
            i = i + 1
            table.insert(opts.clibs, args[i])
        elseif a == "--lfs" then
            opts.lfs = true
        else
            if not opts.output then
                opts.output = a
            end
        end
        i = i + 1
    end
    return opts
end

local function check_dependencies()
    log("info", "checking dependencies")

    if not execute(CC .. " --version >/dev/null 2>&1") then
        log("error", "C compiler not found (set CC)")
        os.exit(1)
    end

    if not execute("ar --version >/dev/null 2>&1") then
        log("error", "ar not found")
        os.exit(1)
    end

    if not execute("git --version >/dev/null 2>&1") then
        log("error", "git not found")
        os.exit(1)
    end

    log("success", "all dependencies found")
end

local function build_spec_from_opts(opts)
    if not opts.main then
        log("error", "no main script specified (use --main)")
        os.exit(1)
    end

    if not file_exists(opts.main) then
        log("error", "main script not found: " .. opts.main)
        os.exit(1)
    end

    local modules = {}
    for _, f in ipairs(opts.lua_files) do
        if file_exists(f) then
            table.insert(modules, f)
        else
            log("warn", "file not found: " .. f)
        end
    end

    local name = basename(opts.main):gsub("%.lua$", "")

    log("success", "main script: " .. opts.main)
    log("success", "modules: " .. #modules .. " files")

    return {
        name = name,
        bin = opts.main,
        modules = modules,
    }
end

local function main(args)
    setup_colors()
    local opts = parse_args(args)

    print(colors.bold .. "lua static build" .. colors.reset .. "\n")

    mkdir(BUILD_DIR)

    local spec
    local use_rockspec = not opts.main and #opts.lua_files == 0

    if use_rockspec then
        local rockspec_path = find_rockspec(opts.rockspec)
        spec = parse_rockspec(rockspec_path)
    else
        spec = build_spec_from_opts(opts)
    end

    local output_name = opts.output or (spec.name .. "-static")

    local os_name, arch = detect_os()
    log("info", "detected " .. os_name .. " " .. arch)

    check_dependencies()

    local lua_incdir, lua_static_lib = find_lua_paths(os_name)

    local clib_files = {}

    if opts.lfs then
        local lfs_a = build_lfs_static(lua_incdir)
        table.insert(clib_files, lfs_a)
    end

    for _, clib in ipairs(opts.clibs) do
        if file_exists(clib) then
            table.insert(clib_files, clib)
            log("success", "clib: " .. clib)
        else
            log("error", "clib not found: " .. clib)
            os.exit(1)
        end
    end

    local binary_path = build_binary(spec, output_name, lua_incdir, lua_static_lib, clib_files)
    finalize(binary_path, output_name)
    os.exit(0)
end

main(arg)
