#!/bin/sh
set -e

CORE_ID="mihomo"
CORE_DIR="/opt/simo/cores/mihomo"
BIN="$CORE_DIR/bin/mihomo"
RULES="$CORE_DIR/bin/mihomo-rules"
CONFIG="$CORE_DIR/config.yaml"
URL_CONFIG="$CORE_DIR/url_config.yaml"
RELEASE_API="https://api.github.com/repos/MetaCubeX/mihomo/releases/latest"

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
	mkdir -p "$CORE_DIR/bin" "$CORE_DIR/lst"
	[ -f "$CONFIG" ] || printf 'mode: rule\nmixed-port: 7890\nallow-lan: true\n' > "$CONFIG"
	[ -x "$BIN" ] || {
		echo "mihomo core is not installed: $BIN" >&2
		return 1
	}
	[ -x "$RULES" ] && "$RULES" start || true
}

run() {
	prepare
	exec "$BIN" -d "$CORE_DIR"
}

check() {
	prepare
	"$BIN" -d "$CORE_DIR" -t
}

version() {
	[ -x "$BIN" ] || {
		echo "not-installed"
		return 1
	}
	"$BIN" -v 2>&1 | sed -n 's/.* \([0-9][0-9.][^ ]*\).*/\1/p; t; 1p' | head -n 1
}

download_latest() {
	local arch asset url archive work core
	arch="$(arch_name)"
	asset="$(curl -fsSL "$RELEASE_API" | jq -r --arg arch "$arch" '
		.assets[]
		| select(.name | test("linux-" + $arch + ".*\\.(gz|tar.gz)$"; "i"))
		| .name
	' | head -n 1)"
	[ -n "$asset" ] || {
		echo "No mihomo asset for $arch" >&2
		return 1
	}
	url="$(curl -fsSL "$RELEASE_API" | jq -r --arg name "$asset" '.assets[] | select(.name == $name) | .browser_download_url')"
	archive="/tmp/$asset"
	work="/tmp/simo-mihomo.$$"
	rm -rf "$work"
	mkdir -p "$work"
	mkdir -p "$CORE_DIR/bin"
	curl -L -fsS "$url" -o "$archive"
	case "$archive" in
		*.tar.gz) tar -xzf "$archive" -C "$work" ;;
		*.gz) gzip -dc "$archive" > "$BIN" ;;
		*) echo "Unsupported archive: $archive" >&2; return 1 ;;
	esac
	if [ ! -s "$BIN" ]; then
		core="$(find "$work" -type f -name 'mihomo*' | head -n 1)"
		[ -n "$core" ] || core="$(find "$work" -type f -name 'clash*' | head -n 1)"
		[ -n "$core" ] || {
			echo "mihomo binary not found in archive" >&2
			return 1
		}
		mv "$core" "$BIN"
	fi
	chmod 0755 "$BIN"
	rm -rf "$work" "$archive"
	version
}

update_config() {
	local url_file="${1:-$URL_CONFIG}"
	local target="${2:-$CONFIG}"
	/usr/bin/simo/simo-updater "$CORE_ID" "$url_file" "$target"
}

netenv() {
	printf "%s\n" \
		"SIMO_CORE='mihomo'" \
		"SIMO_TUN_IFACE='simo-mihomo-tun'" \
		"SIMO_TPROXY_PORT='7894'" \
		"SIMO_REDIR_PORT='7892'" \
		"SIMO_DNS_PORT='7874'" \
		"SIMO_BYPASS_MARK='0x0002'" \
		"SIMO_RULE_PORTS='{7890, 7891, 7892, 7893, 7894}'"
}

set_setting() {
	local key="$1"
	local value="$2"
	local tmp="$CORE_DIR/.settings.$$"
	mkdir -p "$CORE_DIR"
	if [ -f "$CORE_DIR/settings" ]; then
		grep -v "^${key}=" "$CORE_DIR/settings" > "$tmp" || true
	else
		: > "$tmp"
	fi
	printf '%s=%s\n' "$key" "$value" >> "$tmp"
	mv "$tmp" "$CORE_DIR/settings"
}

set_simo_mode() {
	uci set simo.main.mode="$1"
	uci commit simo
}

cleanup() {
	[ -x "$RULES" ] && "$RULES" stop >/dev/null 2>&1 || true
}

rules() {
	[ -x "$RULES" ] || {
		echo "mihomo-rules script is not installed: $RULES" >&2
		return 1
	}
	case "${1:-}" in
		enable-tun)
			set_simo_mode tun
			set_setting PROXY_MODE tun
			"$RULES" restart
			;;
		enable-tproxy)
			set_simo_mode tproxy
			set_setting PROXY_MODE tproxy
			"$RULES" restart
			;;
		enable-mixed)
			set_simo_mode mixed
			set_setting PROXY_MODE mixed
			"$RULES" restart
			;;
		disable-tun|disable-tproxy)
			"$RULES" stop
			;;
		*)
			"$RULES" "$@"
			;;
	esac
}

case "${1:-status}" in
	id) echo "$CORE_ID" ;;
	bin) echo "$BIN" ;;
	config) echo "$CONFIG" ;;
	url) echo "$URL_CONFIG" ;;
	netenv) netenv ;;
	prepare) prepare ;;
	run) run ;;
	check) check ;;
	version) version ;;
	install_latest|update_core) download_latest ;;
	update_config) shift; update_config "$@" ;;
	rules|mode) shift; rules "$@" ;;
	cleanup) cleanup ;;
	status) [ -x "$BIN" ] && echo installed || echo missing ;;
	*) echo "Usage: $0 {id|bin|config|url|netenv|prepare|run|check|version|install_latest|update_config|rules|cleanup|status}" >&2; exit 1 ;;
esac
