#!/bin/sh
# Package manager abstraction for OpenWrt: opkg (23.05, 24.10) vs apk (25.x).
# Source this after ui.sh. Sets PKG_IS_APK (0|1) and PKG_EXT (ipk|apk).

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
        show_message "No package manager (opkg/apk) found." 2>/dev/null || true
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

# Print "retry in N seconds" via show_message.
_pkg_retry_wait() {
    local delay="$1"
    local attempt="$2"
    local max="$3"
    show_message "Error on attempt $attempt/$max. Retrying in ${delay}s..." 2>/dev/null || true
    sleep "$delay"
}

# Compute exponential backoff delay: base * 2^(n-1), where n = retry number (1-based).
# First retry → base, second → base*2, third → base*4, ...
_pkg_backoff() {
    local base="${PKG_RETRY_DELAY:-5}"
    local n="$1"
    local delay="$base"
    local i=1
    while [ "$i" -lt "$n" ]; do
        delay=$((delay * 2))
        i=$((i + 1))
    done
    echo "$delay"
}

# Update package lists. Retries on failure (transient SSL/EOF on OpenWrt).
pkg_list_update() {
    local max="${PKG_UPDATE_RETRIES:-10}"
    local attempt=1
    while [ "$attempt" -le "$max" ]; do
        if [ "$PKG_IS_APK" -eq 1 ]; then
            apk update && return 0
        else
            opkg update && return 0
        fi
        if [ "$attempt" -lt "$max" ]; then
            _pkg_retry_wait "$(_pkg_backoff "$attempt")" "$attempt" "$max"
        fi
        attempt=$((attempt + 1))
    done
    show_message "pkg_list_update failed after $max attempts." 2>/dev/null || true
    return 1
}

# Install package(s) from repo. Retries on failure (transient SSL/EOF).
pkg_install() {
    local max="${PKG_INSTALL_RETRIES:-10}"
    local attempt=1
    while [ "$attempt" -le "$max" ]; do
        if [ "$PKG_IS_APK" -eq 1 ]; then
            apk add "$@" && return 0
        else
            opkg install "$@" && return 0
        fi
        if [ "$attempt" -lt "$max" ]; then
            _pkg_retry_wait "$(_pkg_backoff "$attempt")" "$attempt" "$max"
        fi
        attempt=$((attempt + 1))
    done
    show_message "pkg_install failed after $max attempts." 2>/dev/null || true
    return 1
}

# Install with force-reinstall (opkg) / reinstall (apk). Retries on failure.
pkg_install_force() {
    local max="${PKG_INSTALL_RETRIES:-10}"
    local attempt=1
    while [ "$attempt" -le "$max" ]; do
        if [ "$PKG_IS_APK" -eq 1 ]; then
            apk add --force-overwrite "$@" && return 0
        else
            opkg install --force-reinstall "$@" && return 0
        fi
        if [ "$attempt" -lt "$max" ]; then
            _pkg_retry_wait "$(_pkg_backoff "$attempt")" "$attempt" "$max"
        fi
        attempt=$((attempt + 1))
    done
    show_message "pkg_install_force failed after $max attempts." 2>/dev/null || true
    return 1
}

# Install from local file (.ipk or .apk). Retries on failure.
# For apk, uses --allow-untrusted (self-built / third-party packages).
pkg_install_file() {
    local path="$1"
    local max="${PKG_INSTALL_RETRIES:-10}"
    local attempt=1
    while [ "$attempt" -le "$max" ]; do
        if [ "$PKG_IS_APK" -eq 1 ]; then
            apk add --allow-untrusted "$path" && return 0
        else
            opkg install "$path" && return 0
        fi
        if [ "$attempt" -lt "$max" ]; then
            _pkg_retry_wait "$(_pkg_backoff "$attempt")" "$attempt" "$max"
        fi
        attempt=$((attempt + 1))
    done
    show_message "pkg_install_file failed after $max attempts." 2>/dev/null || true
    return 1
}
