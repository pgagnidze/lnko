# luas

Build standalone Lua binaries with cross-compilation support.

## Overview

luas builds single-file executables from LuaRocks projects. It embeds Lua source files into a static binary that runs without any runtime dependencies.

**Key feature:** Cross-compile from Linux/macOS to any supported target using Zig as the C compiler.

## Quick Start

```bash
# Build for current platform
./luas myapp

# Cross-compile for multiple targets
./luas -t linux-x86_64 -t linux-arm64 -t darwin-arm64 -t windows-x86_64 myapp
```

## CLI Usage

```
luas [options] [modules...] [output-name]

Options:
    -h, --help      Show help message
    -q, --quiet     Only show errors and warnings
    -v, --verbose   Show detailed output
    -m, --main      Main entry point (standalone mode, no rockspec needed)
    -c, --clib      C library dependency (can be repeated)
    -e, --embed     Embed data file/directory (can be repeated)
    -r, --rockspec  Path to rockspec file (default: auto-detect)
    -t, --target    Cross-compile for target (can be repeated)

Available targets:
    linux-x86_64, linux-arm64
    darwin-x86_64, darwin-arm64 (macos-* also works)
    windows-x86_64, windows-arm64

Environment:
    BUILD_DIR       Build directory (default: .build)
    LUAS_CACHE      Cache directory for zig/lua (default: ~/.cache/luas)
    LUA_VERSION     Lua version to build (default: 5.4.7)
    CC              C compiler (default: cc, ignored with --target)
```

## Standalone Mode

Build without a rockspec using the `--main` flag:

```bash
# Simple script
luas -m app.lua myapp

# With module directories
luas -m app.lua lib/ src/ myapp

# With C libraries
luas -m app.lua -c lfs -c lpeg myapp

# Cross-compile
luas -m app.lua lib/ -c lfs -t linux-x86_64 -t darwin-arm64 myapp
```

## Embedding Data Files

Embed static assets (templates, configs, etc.) into the binary:

```bash
luas -m app.lua -e templates/ -e config.json myapp
```

Access embedded files at runtime:

```lua
local embed = require("luas.embed")

-- Read file contents
local html = embed.read("templates/page.html")

-- Check if file exists
if embed.exists("config.json") then
    local config = embed.read("config.json")
end

-- List all embedded files
for _, path in ipairs(embed.list()) do
    print(path)
end
```

## How It Works

1. Parses rockspec (or uses `--main` for standalone mode)
2. Auto-detects C dependencies from rockspec (or uses `-c` flags)
3. Downloads and caches Zig toolchain for cross-compilation
4. Fetches C library sources in parallel
5. Builds Lua and C libraries with content-hashed caching
6. Embeds Lua source and data files as C arrays
7. Compiles to static binary

## C Library Support

C dependencies listed in rockspec are automatically built:

| Dependency | Status |
|------------|--------|
| luafilesystem | Built-in |
| lpeg | Built-in |

### Custom C Libraries

Add custom C libraries via `.luasrc` config file:

```lua
return {
    mylib = {
        url = "https://github.com/user/mylib.git",
        sources = { "src/mylib.c" },
    },
}
```

Fields:
- `url` (required): Git repo or tarball URL
- `sources` (required): List of C source files
- `name`: Library name (defaults to key)
- `type`: `"git"` or `"tarball"` (auto-detected from URL)
- `luaopen`: Lua module name (defaults to key)

## Requirements

**Host (where luas runs):**
- Linux or macOS
- Lua 5.1+
- C compiler, ar, git
- curl or wget

**For native builds:**
- Lua development files (lua.h, liblua.a)

**For cross-compilation:**
- No additional requirements (Zig is downloaded automatically)

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
- uses: pgagnidze/lnko/luas@main
  with:
    output: myapp
    targets: linux-x86_64 linux-arm64 darwin-arm64 windows-x86_64
```

### Inputs

| Input | Description | Required |
|-------|-------------|----------|
| `output` | Output binary name | No (defaults to package name) |
| `rockspec` | Path to rockspec file | No (auto-detected) |
| `targets` | Space-separated list of targets | No (native build if empty) |

### Example Workflow

```yaml
name: Build

on:
  push:
    tags: ["v*"]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pgagnidze/lnko/luas@main
        with:
          output: myapp
          targets: linux-x86_64 linux-arm64 darwin-arm64 windows-x86_64
      - uses: actions/upload-artifact@v4
        with:
          name: binaries
          path: myapp-*
```

## Credits

Based on [luastatic](https://github.com/ers35/luastatic) by ers35.

Cross-compilation powered by [Zig](https://ziglang.org/).

## License

GPL-3.0
