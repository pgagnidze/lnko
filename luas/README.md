# luas

Build standalone Lua binaries with no runtime dependencies.

## Overview

luas embeds Lua source files and the Lua interpreter into a single executable. It converts Lua source to C arrays and compiles them with a static Lua interpreter.

## GitHub Action

```yaml
- uses: pgagnidze/lnko/luas@main
  with:
    output: myapp-linux_x86_64
    lfs: true
```

### Inputs

| Input | Description | Required |
|-------|-------------|----------|
| `output` | Output binary name | No (defaults to package name) |
| `rockspec` | Path to rockspec file | No (auto-detected) |
| `main` | Main Lua script (entry point) | No |
| `lua` | Lua module files (space-separated) | No |
| `clib` | Static C libraries to link (space-separated) | No |
| `lfs` | Include LuaFileSystem (`true`/`false`) | No (default: `false`) |

### Examples

**Build from rockspec:**
```yaml
- uses: pgagnidze/lnko/luas@main
  with:
    output: myapp-${{ matrix.target }}
    lfs: true
```

**Build without rockspec:**
```yaml
- uses: pgagnidze/lnko/luas@main
  with:
    main: bin/app.lua
    lua: "lib/*.lua"
    output: myapp
```

**Build with additional C libraries:**
```yaml
- uses: pgagnidze/lnko/luas@main
  with:
    output: myapp
    lfs: true
    clib: "lpeg.a luasocket.a"
```

### Full workflow example

```yaml
name: Build

on:
  push:
    tags: ["v*"]

jobs:
  build:
    strategy:
      matrix:
        include:
          - target: linux_x86_64
            os: ubuntu-latest
          - target: linux_arm64
            os: ubuntu-24.04-arm
          - target: darwin_x86_64
            os: macos-15-intel
          - target: darwin_arm64
            os: macos-latest
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: pgagnidze/lnko/luas@main
        with:
          output: myapp-${{ matrix.target }}
          lfs: true
      - uses: actions/upload-artifact@v4
        with:
          name: myapp-${{ matrix.target }}
          path: myapp-${{ matrix.target }}
```

## CLI Usage

You can also run luas directly:

```bash
lua luas [options] [output-name]
```

### Options

| Option | Description |
|--------|-------------|
| `-h, --help` | Show help message |
| `-r, --rockspec <file>` | Path to rockspec file |
| `-m, --main <file>` | Main Lua script (entry point) |
| `-l, --lua <files>` | Lua module files (can be repeated) |
| `-c, --clib <file>` | Static C library to link (can be repeated) |
| `--lfs` | Build and include LuaFileSystem |

### Examples

```bash
# Build from rockspec
lua luas --lfs myapp

# Build without rockspec
lua luas --main bin/app.lua --lua "lib/*.lua" myapp

# Build with multiple C libraries
lua luas --lfs --clib lpeg.a myapp
```

## Requirements

- Lua 5.4
- C compiler (gcc/clang)
- Lua development files (lua.h, liblua.a)
- git (for --lfs flag)

## How It Works

1. Parses rockspec or command-line arguments
2. Converts Lua source to C hex arrays
3. Generates a C file with embedded loader
4. Compiles and links with static Lua interpreter
5. Strips debug symbols

Output binary dynamically links only glibc (present on all Linux systems).

## Supported Platforms

- Linux x86_64
- Linux arm64
- macOS x86_64
- macOS arm64

## Credits

Based on [luastatic](https://github.com/ers35/luastatic) by ers35.

## License

GPL-3.0
