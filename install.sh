#!/bin/sh
set -e

# lnko installer - works on any POSIX system with a package manager

REPO="pgagnidze/lnko"

main() {
    check_lua
    check_luarocks
    install_lnko
    verify_install
}

check_lua() {
    if command -v lua >/dev/null 2>&1; then
        printf "Lua found: %s\n" "$(lua -v 2>&1 | head -1)"
        return
    fi

    printf "Lua not found. Installing...\n"
    install_lua
}

install_lua() {
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update && sudo apt-get install -y lua5.4 liblua5.4-dev
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y lua lua-devel
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --noconfirm lua
    elif command -v apk >/dev/null 2>&1; then
        sudo apk add lua5.4 lua5.4-dev
    elif command -v brew >/dev/null 2>&1; then
        brew install lua
    elif command -v zypper >/dev/null 2>&1; then
        sudo zypper install -y lua54 lua54-devel
    else
        printf "Error: Could not detect package manager.\n"
        printf "Install Lua manually: https://www.lua.org/download.html\n"
        exit 1
    fi
}

check_luarocks() {
    if command -v luarocks >/dev/null 2>&1; then
        printf "LuaRocks found: %s\n" "$(luarocks --version | head -1)"
        return
    fi

    printf "LuaRocks not found. Installing...\n"
    install_luarocks
}

install_luarocks() {
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get install -y luarocks
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y luarocks
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --noconfirm luarocks
    elif command -v apk >/dev/null 2>&1; then
        sudo apk add luarocks5.4
    elif command -v brew >/dev/null 2>&1; then
        brew install luarocks
    elif command -v zypper >/dev/null 2>&1; then
        sudo zypper install -y lua54-luarocks
    else
        printf "Error: Could not detect package manager.\n"
        printf "Install LuaRocks manually: https://luarocks.org/#quick-start\n"
        exit 1
    fi
}

install_lnko() {
    printf "Installing lnko...\n"
    luarocks install lnko
}

verify_install() {
    if command -v lnko >/dev/null 2>&1; then
        printf "\nInstalled successfully!\n"
        printf "Run 'lnko --help' to get started.\n"
    else
        printf "\nlnko installed but not in PATH.\n"
        printf "Add LuaRocks bin to your PATH:\n"
        printf "  export PATH=\"\$PATH:\$(luarocks path --lr-bin)\"\n"
    fi
}

main "$@"
