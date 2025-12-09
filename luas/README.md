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
./luas -t linux-x86_64 -t linux-arm64 -t macos-arm64 -t windows-x86_64 myapp
```

## CLI Usage

```
luas [options] [output-name]

Options:
    -h, --help      Show help message
    -r, --rockspec  Path to rockspec file (default: auto-detect)
    -t, --target    Cross-compile for target (can be repeated)

Available targets:
    linux-x86_64, linux-arm64
    macos-x86_64, macos-arm64 (darwin-* also works)
    windows-x86_64

Environment:
    BUILD_DIR       Build directory (default: .build)
    LUAS_CACHE      Cache directory for zig/lua (default: ~/.cache/luas)
    CC              C compiler (default: cc, ignored with --target)
```

## How It Works

1. Parses rockspec to find entry point and modules
2. Auto-detects C dependencies (lpeg, luafilesystem) from rockspec
3. Downloads and caches Zig toolchain for cross-compilation
4. Builds Lua and C libraries from source for each target
5. Embeds Lua source as C arrays
6. Compiles to static binary

## C Library Support

C dependencies listed in rockspec are automatically built:

| Dependency | Status |
|------------|--------|
| luafilesystem | Supported |
| lpeg | Supported |

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
| macos-x86_64 | Mach-O x86_64 |
| macos-arm64 | Mach-O arm64 |
| windows-x86_64 | PE32+ executable |
| windows-arm64 | PE32+ executable (ARM64) |

Linux binaries are fully static (musl libc). No runtime dependencies.

## GitHub Action

```yaml
- uses: pgagnidze/lnko/luas@main
  with:
    output: myapp
    targets: linux-x86_64 linux-arm64 macos-arm64 windows-x86_64
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
          targets: linux-x86_64 linux-arm64 macos-arm64 windows-x86_64
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
