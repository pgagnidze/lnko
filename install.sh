#!/usr/bin/env bash

set -euo pipefail

setup_colors() {
    if [[ -n "${FORCE_COLOR:-}" ]]; then
        USE_COLOR=true
    elif [[ -n "${NO_COLOR:-}" ]]; then
        USE_COLOR=false
    elif [[ -t 1 ]]; then
        USE_COLOR=true
    else
        USE_COLOR=false
    fi

    if [[ "$USE_COLOR" == true ]]; then
        green=$'\e[32m'
        yellow=$'\e[33m'
        blue=$'\e[34m'
        red=$'\e[31m'
        reset=$'\e[0m'
    else
        green='' yellow='' blue='' red='' reset=''
    fi
}

log() {
    local level=$1
    shift
    local color
    case "$level" in
        info) color="$blue" ;;
        success) color="$green" ;;
        warn) color="$yellow" ;;
        error) color="$red" ;;
        *) color="" ;;
    esac
    if [[ "$level" == "error" ]]; then
        printf "%s[%s]%s %s\n" "$color" "$level" "$reset" "$*" >&2
    else
        printf "%s[%s]%s %s\n" "$color" "$level" "$reset" "$*"
    fi
}

check_lua() {
    if command -v lua &>/dev/null; then
        log info "Lua found: $(lua -v 2>&1 | head -1)"
        return
    fi

    log warn "Lua not found. Installing..."
    install_lua
}

install_lua() {
    if command -v apt-get &>/dev/null; then
        sudo apt-get update && sudo apt-get install -y lua5.4 liblua5.4-dev
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y lua lua-devel
    elif command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm lua
    elif command -v apk &>/dev/null; then
        sudo apk add lua5.4 lua5.4-dev
    elif command -v brew &>/dev/null; then
        brew install lua
    elif command -v zypper &>/dev/null; then
        sudo zypper install -y lua54 lua54-devel
    else
        log error "Could not detect package manager"
        log info "Install Lua manually: https://www.lua.org/download.html"
        exit 1
    fi
}

check_luarocks() {
    if command -v luarocks &>/dev/null; then
        log info "LuaRocks found: $(luarocks --version | head -1)"
        return
    fi

    log warn "LuaRocks not found. Installing..."
    install_luarocks
}

install_luarocks() {
    if command -v apt-get &>/dev/null; then
        sudo apt-get install -y luarocks
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y luarocks
    elif command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm luarocks
    elif command -v apk &>/dev/null; then
        sudo apk add luarocks5.4
    elif command -v brew &>/dev/null; then
        brew install luarocks
    elif command -v zypper &>/dev/null; then
        sudo zypper install -y lua54-luarocks
    else
        log error "Could not detect package manager"
        log info "Install LuaRocks manually: https://luarocks.org/#quick-start"
        exit 1
    fi
}

install_lnko() {
    log info "Installing lnko..."
    luarocks install lnko
}

verify_install() {
    if command -v lnko &>/dev/null; then
        log success "Installed successfully!"
        log info "Run 'lnko --help' to get started"
    else
        log warn "lnko installed but not in PATH"
        log info "Add LuaRocks bin to your PATH:"
        printf "  export PATH=\"\$PATH:\$(luarocks path --lr-bin)\"\n"
    fi
}

main() {
    setup_colors
    check_lua
    check_luarocks
    install_lnko
    verify_install
    exit 0
}

main "$@"
