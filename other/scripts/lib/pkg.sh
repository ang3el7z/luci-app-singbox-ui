#!/bin/sh
# Package manager abstraction for OpenWrt: opkg (23.05, 24.10) vs apk (25.x).
# Source this after ui.sh. Sets PKG_IS_APK (0|1) and PKG_EXT (ipk|apk).
# Style aligned with itdoginfo/podkop.

detect_pkg_manager() {
    PKG_IS_APK=0
    command -v apk >/dev/null 2>&1 && PKG_IS_APK=1

    if [ "$PKG_IS_APK" -eq 1 ]; then
        PKG_EXT="apk"
        PKG_MODE_LABEL="apk (.apk) — OpenWrt 25"
    elif command -v opkg >/dev/null 2>&1; then
        PKG_EXT="ipk"
        PKG_MODE_LABEL="opkg (.ipk) — OpenWrt 23/24"
    else
        echo "No package manager (opkg/apk) found." >&2
        return 1
    fi

    # Показать режим наглядно (show_message из ui.sh, подключается до pkg.sh)
    [ -n "$PKG_MODE_LABEL" ] && show_message "Package manager: $PKG_MODE_LABEL" 2>/dev/null || true
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
