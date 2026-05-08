#!/bin/sh
set -e

CORE_ID="singbox"
CORE_DIR="/opt/simo/cores/singbox"
BIN="$CORE_DIR/bin/sing-box"
RULES="$CORE_DIR/bin/singbox-rules"
CONFIG="$CORE_DIR/config.json"
URL_CONFIG="$CORE_DIR/url_config.json"
RELEASE_API="https://api.github.com/repos/SagerNet/sing-box/releases/latest"

arch_name() {
	. /etc/openwrt_release 2>/dev/null || true
	case "${DISTRIB_ARCH:-}" in
		aarch64_*) echo arm64 ;;
		x86_64) echo amd64 ;;
		i386_*) echo 386 ;;
		riscv64_*) echo riscv64 ;;
		loongarch64_*) echo loong64 ;;
		arm_*neon-vfp*) echo armv7 ;;
		arm_*neon*|arm_*vfp*) echo armv6 ;;
		arm_*) echo armv5 ;;
		mips64el_*) echo mips64le ;;
		mips64_*) echo mips64 ;;
		mipsel_*) echo mipsle-softfloat ;;
		mips_*) echo mips-softfloat ;;
		*) echo amd64 ;;
	esac
}

prepare() {
	mkdir -p "$CORE_DIR/bin"
	[ -f "$CONFIG" ] || printf '{}\n' > "$CONFIG"
	[ -x "$RULES" ] || {
		echo "singbox-rules script is not installed: $RULES" >&2
		return 1
	}
	[ -x "$BIN" ] || {
		echo "sing-box core is not installed: $BIN" >&2
		return 1
	}
	"$RULES" start >/dev/null 2>&1 || true
}

run() {
	prepare
	exec "$BIN" run -c "$CONFIG"
}

check() {
	prepare
	"$BIN" check -c "$CONFIG"
}

version() {
	[ -x "$BIN" ] || {
		echo "not-installed"
		return 1
	}
	"$BIN" version | sed -n 's/.*version \([0-9][^ ]*\).*/\1/p; t; 1p' | head -n 1
}

download_latest() {
	local arch tag asset url archive work core
	arch="$(arch_name)"
	tag="$(curl -fsSL "$RELEASE_API" | jq -r '.tag_name')"
	[ -n "$tag" ] && [ "$tag" != "null" ] || {
		echo "Could not resolve sing-box release tag" >&2
		return 1
	}
	asset="$(curl -fsSL "$RELEASE_API" | jq -r --arg arch "$arch" '
		.assets[]
		| select(.name | test("^sing-box-.*-linux-" + $arch + "\\.tar\\.(gz|xz)$"))
		| .name
	' | head -n 1)"
	[ -n "$asset" ] || {
		echo "No sing-box asset for $arch" >&2
		return 1
	}
	url="$(curl -fsSL "$RELEASE_API" | jq -r --arg name "$asset" '.assets[] | select(.name == $name) | .browser_download_url')"
	archive="/tmp/$asset"
	work="/tmp/simo-singbox.$$"
	rm -rf "$work"
	mkdir -p "$work" "$CORE_DIR/bin"
	curl -L -fsS "$url" -o "$archive"
	case "$archive" in
		*.tar.gz) tar -xzf "$archive" -C "$work" ;;
		*.tar.xz) tar -xJf "$archive" -C "$work" ;;
		*) echo "Unsupported archive: $archive" >&2; return 1 ;;
	esac
	core="$(find "$work" -type f -name sing-box | head -n 1)"
	[ -n "$core" ] || {
		echo "sing-box binary not found in archive" >&2
		return 1
	}
	mv "$core" "$BIN"
	chmod 0755 "$BIN"
	rm -rf "$work" "$archive"
	version
}

update_config() {
	local url_file="${1:-$URL_CONFIG}"
	local target="${2:-$CONFIG}"
	/usr/bin/simo/simo-updater "$CORE_ID" "$url_file" "$target"
}

cleanup() {
	[ -x "$RULES" ] && "$RULES" full_cleanup >/dev/null 2>&1 || true
}

rules() {
	[ -x "$RULES" ] || {
		echo "singbox-rules script is not installed: $RULES" >&2
		return 1
	}
	"$RULES" "$@"
}

case "${1:-status}" in
	id) echo "$CORE_ID" ;;
	bin) echo "$BIN" ;;
	config) echo "$CONFIG" ;;
	url) echo "$URL_CONFIG" ;;
	prepare) prepare ;;
	run) run ;;
	check) check ;;
	version) version ;;
	install_latest|update_core) download_latest ;;
	update_config) shift; update_config "$@" ;;
	rules|mode) shift; rules "$@" ;;
	cleanup) cleanup ;;
	status) [ -x "$BIN" ] && echo installed || echo missing ;;
	*) echo "Usage: $0 {id|bin|config|url|prepare|run|check|version|install_latest|update_config|cleanup|status}" >&2; exit 1 ;;
esac
