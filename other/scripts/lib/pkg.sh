#!/bin/sh
# Package manager abstraction for OpenWrt: opkg (23.05, 24.10) vs apk (25.x).
# Source this after ui.sh. Sets PKG_IS_APK (0|1) and PKG_EXT (ipk|apk).

detect_pkg_manager() {
    if command -v opkg >/dev/null 2>&1; then
        PKG_IS_APK=0
        PKG_EXT="ipk"
    elif command -v apk >/dev/null 2>&1; then
        PKG_IS_APK=1
        PKG_EXT="apk"
    else
        echo "No package manager (opkg/apk) found." >&2
        return 1
    fi
}

pkg_is_installed() {
    local pkg_name="$1"
    if [ "$PKG_IS_APK" -eq 1 ]; then
        apk list --installed 2>/dev/null | grep -q "$pkg_name"
    else
        opkg list-installed 2>/dev/null | grep -q "$pkg_name"
    fi
}

pkg_remove() {
    local pkg_name="$1"
    if [ "$PKG_IS_APK" -eq 1 ]; then
        apk del "$pkg_name"
    else
        opkg remove --force-depends "$pkg_name"
    fi
}

pkg_list_update() {
    if [ "$PKG_IS_APK" -eq 1 ]; then
        apk update
    else
        opkg update
    fi
}

# Install package(s) from repo. Args: pkg1 [pkg2 ...]
pkg_install() {
    if [ "$PKG_IS_APK" -eq 1 ]; then
        apk add "$@"
    else
        opkg install "$@"
    fi
}

# Install with force-reinstall (opkg) / reinstall (apk). Args: pkg1 [pkg2 ...]
pkg_install_force() {
    if [ "$PKG_IS_APK" -eq 1 ]; then
        apk add --force-overwrite "$@"
    else
        opkg install --force-reinstall "$@"
    fi
}

# Install from local file (.ipk or .apk). Path must be exact.
# For apk, uses --allow-untrusted (self-built / third-party packages).
pkg_install_file() {
    local path="$1"
    if [ "$PKG_IS_APK" -eq 1 ]; then
        apk add --allow-untrusted "$path"
    else
        opkg install "$path"
    fi
}
