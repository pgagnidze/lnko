<div align="center">

<img src="assets/lnko.svg" alt="lnko logo" width="128"/>

# lnko

A modern GNU Stow alternative for managing dotfiles.

<p align="center">
  <img src="assets/demo.gif" alt="lnko demo" width="600"/>
</p>

[![CI](https://github.com/pgagnidze/lnko/actions/workflows/ci.yml/badge.svg)](https://github.com/pgagnidze/lnko/actions/workflows/ci.yml)
![LuaRocks](https://img.shields.io/luarocks/v/pgagnidze/lnko?color=1e3a8a)
![License: GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-000080)

</div>

## Features

<table>
<tr>
<td width="50%">

**Conflict handling**

Interactive prompt with backup, skip, overwrite, and diff options when files already exist.

</td>
<td width="50%">

**Orphan cleanup**

`lnko clean` removes stale symlinks pointing to non-existent targets.

</td>
</tr>
<tr>
<td width="50%">

**Stow-compatible**

Works with existing GNU Stow symlinks. Supports tree folding for cleaner directory structures.

</td>
<td width="50%">

**Relative symlinks**

Portable across machines. Symlinks use relative paths, not absolute.

</td>
</tr>
</table>

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/pgagnidze/lnko/main/install.sh | sh
```

Or if you have LuaRocks:

```bash
sudo luarocks install lnko
```

## Usage

```bash
# Link packages from current directory to $HOME
lnko link bash git nvim

# Specify source and target directories
lnko link -d ~/dotfiles/config -t ~ bash git nvim

# Unlink packages
lnko unlink bash

# Show status of all packages
lnko status

# Remove orphan symlinks
lnko clean
```

### Options

| Option | Description |
|--------|-------------|
| `-d, --dir <dir>` | Source directory containing packages (default: cwd) |
| `-t, --target <dir>` | Target directory (default: $HOME) |
| `-n, --dry-run` | Show what would be done |
| `-v, --verbose` | Show debug output |
| `-b, --backup` | Auto-backup conflicts to `<target>/.lnko-backup/` |
| `-s, --skip` | Auto-skip conflicts |
| `-f, --force` | Auto-overwrite conflicts (dangerous) |
| `--ignore <pattern>` | Ignore files matching pattern (can be repeated) |

### Conflict Handling

When lnko encounters existing files, it prompts for action:

- **[b]ackup** - Move existing file to `.lnko-backup/`
- **[s]kip** - Leave existing file, skip this link
- **[o]verwrite** - Replace existing file
- **[d]iff** - Show diff between source and target
- **[q]uit** - Abort operation

Use `-b`, `-s`, or `-f` flags to auto-resolve conflicts.

## How It Works

lnko creates relative symlinks from a source directory (containing "packages") to a target directory. Each package is a directory whose contents mirror the target structure.

```
dotfiles/
  bash/
    .bashrc
    .bash_profile
  git/
    .gitconfig
```

Running `lnko link -d dotfiles -t ~ bash git` creates:

```
~/.bashrc -> ../dotfiles/bash/.bashrc
~/.bash_profile -> ../dotfiles/bash/.bash_profile
~/.gitconfig -> ../dotfiles/git/.gitconfig
```

### Tree Folding

Like GNU Stow, lnko supports tree folding. If a target directory contains only symlinks pointing to the same package, it can be "folded" into a single directory symlink. When adding files from another package, the directory is "unfolded" back into individual symlinks.

## Development

```bash
# Run from source
./bin/lnko.lua --help

# Run linter
luacheck lnko/ bin/ spec/

# Run tests
busted spec/
```

## License

[GPL-3.0](LICENSE)
