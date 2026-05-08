#!/bin/sh
set -e

CORE_ID="singbox"
CORE_DIR="/opt/simo/cores/singbox"
BIN="$CORE_DIR/bin/sing-box"
RULES="$CORE_DIR/bin/singbox-rules"
CONFIG="$CORE_DIR/config.json"
URL_CONFIG="$CORE_DIR/url_config.json"
TPROXY_PORT="2080"
DNS_PORT="1053"
TUN_IFACE="singtun0"
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
	prepare_runtime_config
	case "$(active_mode)" in
		tun) "$RULES" enable-tun >/dev/null 2>&1 || true ;;
		mixed) "$RULES" enable-mixed >/dev/null 2>&1 || true ;;
		tproxy) "$RULES" enable-tproxy >/dev/null 2>&1 || true ;;
		*) "$RULES" start >/dev/null 2>&1 || true ;;
	esac
}

active_mode() {
	uci -q get simo.main.mode 2>/dev/null || echo tproxy
}

prepare_runtime_config() {
	local mode tmp
	mode="$(active_mode)"
	tmp="$CONFIG.tmp.$$"
	jq \
		--arg mode "$mode" \
		--arg tun_iface "$TUN_IFACE" \
		--argjson tproxy_port "$TPROXY_PORT" \
		'
		.log = (.log // {"level":"info"})
		| .outbounds = (
			(.outbounds // [])
			| if any(.[]; .tag == "direct") then . else . + [{"type":"direct","tag":"direct"}] end
		)
		| .route = (.route // {})
		| .route.final = (.route.final // "direct")
		| .inbounds = (
			(.inbounds // [])
			| map(select(.tag != "simo-tproxy-in" and .tag != "simo-tun-in"))
			| if $mode == "tun" then
				. + [{
					"type":"tun",
					"tag":"simo-tun-in",
					"interface_name":$tun_iface,
					"address":["172.19.0.1/30"],
					"mtu":9000,
					"auto_route":false,
					"strict_route":false,
					"stack":"system"
				}]
			  elif $mode == "mixed" then
				. + [
					{"type":"tproxy","tag":"simo-tproxy-in","listen":"0.0.0.0","listen_port":$tproxy_port},
					{
						"type":"tun",
						"tag":"simo-tun-in",
						"interface_name":$tun_iface,
						"address":["172.19.0.1/30"],
						"mtu":9000,
						"auto_route":false,
						"strict_route":false,
						"stack":"system"
					}
				]
			  else
				. + [{"type":"tproxy","tag":"simo-tproxy-in","listen":"0.0.0.0","listen_port":$tproxy_port}]
			  end
		)
		' "$CONFIG" > "$tmp"
	mv "$tmp" "$CONFIG"
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

netenv() {
	printf "%s\n" \
		"SIMO_CORE='singbox'" \
		"SIMO_TUN_IFACE='$TUN_IFACE'" \
		"SIMO_TPROXY_PORT='$TPROXY_PORT'" \
		"SIMO_DNS_PORT='$DNS_PORT'" \
		"SIMO_BYPASS_MARK='0x0002'" \
		"SIMO_RULE_PORTS='{2080, 1053}'"
}

cleanup() {
	[ -x "$RULES" ] && "$RULES" full_cleanup >/dev/null 2>&1 || true
}

rules() {
	[ -x "$RULES" ] || {
		echo "singbox-rules script is not installed: $RULES" >&2
		return 1
	}
	local action="${1:-}"
	"$RULES" "$@"
	case "$action" in
		enable-tun|enable-tproxy|enable-mixed)
			prepare_runtime_config
			if /etc/init.d/simo status 2>/dev/null | grep -q running; then
				/etc/init.d/simo restart >/dev/null 2>&1 || true
			fi
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
	*) echo "Usage: $0 {id|bin|config|url|netenv|prepare|run|check|version|install_latest|update_config|cleanup|status}" >&2; exit 1 ;;
esac
