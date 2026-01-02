# luast

Build static Lua binaries with cross-compilation support.

## Overview

luast builds single-file static executables from LuaRocks projects using Zig. It embeds Lua source files into a binary that runs without any runtime dependencies.

All builds use Zig as the compiler toolchain, producing fully static binaries.

## Quick Start

```bash
# Build for current platform (static binary)
luast myapp

# Build for multiple targets
luast -t linux-x86_64 -t darwin-arm64 -t windows-x86_64 myapp
```

## CLI Usage

```
luast [options] [modules...] [output-name]

Options:
    -h, --help      Show help message
    -q, --quiet     Only show errors and warnings
    -v, --verbose   Show detailed output
    -m, --main      Main entry point (standalone mode, no rockspec needed)
    -c, --clib      C library dependency (can be repeated)
    -e, --embed     Embed data file/directory (can be repeated)
    -r, --rockspec  Path to rockspec file (default: auto-detect)
    -t, --target    Target platform (default: native)

Available targets:
    linux-x86_64, linux-arm64
    darwin-x86_64, darwin-arm64 (macos-* also works)
    windows-x86_64, windows-arm64

Environment:
    BUILD_DIR       Build directory (default: .build)
    LUAST_CACHE     Cache directory for zig/lua (default: ~/.cache/luast)
    LUA_VERSION     Lua version to build (default: 5.4.8)
```

## Standalone Mode

Build without a rockspec using the `--main` flag:

```bash
luast -m app.lua myapp
luast -m app.lua lib/ src/ myapp
luast -m app.lua -c lfs -c lpeg myapp
```

### Using LuaRocks Modules

Include modules installed via LuaRocks by specifying their paths:

```bash
luarocks install --local inspect
luast -m app.lua ~/.luarocks/share/lua/5.4/inspect.lua myapp
```

Module names are computed relative to parent directory:

- `~/.luarocks/share/lua/5.4/inspect.lua` → `require("inspect")`
- `~/.luarocks/share/lua/5.4/pl/path.lua` → `require("pl.path")`

## Embedding Data Files

Embed static assets into the binary:

```bash
luast -m app.lua -e templates/ -e config.json myapp
```

Access at runtime:

```lua
local embed = require("luast.embed")
local html = embed.read("templates/page.html")
```

## How It Works

1. Parses rockspec (or uses `--main` for standalone mode)
2. Downloads and caches Zig toolchain
3. Builds Lua from source with Zig
4. Fetches and builds C library sources
5. Embeds Lua source and data files as C arrays
6. Links everything into a static binary

## C Library Support

| Dependency | Status |
|------------|--------|
| luafilesystem | Built-in |
| lpeg | Built-in |
| lua-cjson | Built-in |
| lsqlite3complete | Built-in (includes SQLite3) |

### Custom C Libraries

Add custom C libraries via `.luastrc`:

```lua
return {
    mylib = {
        url = "https://github.com/user/mylib.git",
        sources = { "src/mylib.c" },
    },
}
```

Fields:

- `url` (required): Git repo, tarball, or zip URL
- `sources` (required): List of C source files
- `name`: Library name (defaults to key)
- `type`: `"git"`, `"tarball"`, or `"zip"` (auto-detected)
- `luaopen`: C function name suffix (defaults to key)
- `modname`: Lua module name for package.preload
- `defines`: List of C preprocessor definitions

## Requirements

- Linux or macOS
- Lua 5.1+
- git, curl or wget

Zig is downloaded automatically on first run.

## Output Binaries

| Target | Binary Type |
|--------|-------------|
| linux-x86_64 | Static ELF (musl) |
| linux-arm64 | Static ELF (musl) |
| darwin-x86_64 | Mach-O x86_64 |
| darwin-arm64 | Mach-O arm64 |
| windows-x86_64 | PE32+ executable |
| windows-arm64 | PE32+ executable (ARM64) |

Linux binaries are fully static (musl libc). No runtime dependencies.

## GitHub Action

```yaml
- uses: pgagnidze/lnko/luast@main
  with:
    output: myapp
    targets: linux-x86_64 linux-arm64 darwin-arm64 windows-x86_64
```

### Inputs

| Input | Description | Required |
|-------|-------------|----------|
| `output` | Output binary name | No (defaults to package name) |
| `rockspec` | Path to rockspec file | No (auto-detected) |
| `targets` | Space-separated list of targets | No (native if empty) |

## Limitations

- Linux binaries use musl libc (not glibc)
- No automatic dependency resolution from LuaRocks
- No LuaJIT support
- No OpenSSL/TLS support (libraries requiring OpenSSL cannot be built)
- C libraries with complex build systems (autoconf, cmake) not supported

## Credits

Based on [luastatic](https://github.com/ers35/luastatic) by ers35.

Powered by [Zig](https://ziglang.org/).

## License

GPL-3.0
