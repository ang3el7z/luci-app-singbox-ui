#!/bin/sh
# Shared OpenWrt network backend for Simo core providers.

set -e

CORE="${1:-}"
[ -n "$CORE" ] || {
	echo "Usage: $0 <core> <action>" >&2
	exit 1
}
shift || true
ACTION="${1:-start}"

load_provider_env() {
	local env
	env="$(/usr/bin/simo/simo-core "$CORE" netenv 2>/dev/null)" || {
		echo "Simo provider '$CORE' does not expose netenv" >&2
		exit 1
	}
	eval "$env"
}

load_provider_env

SIMO_CORE="${SIMO_CORE:-$CORE}"
SIMO_TUN_IFACE="${SIMO_TUN_IFACE:-simo-${SIMO_CORE}-tun}"
SIMO_TPROXY_PORT="${SIMO_TPROXY_PORT:-7894}"
SIMO_DNS_PORT="${SIMO_DNS_PORT:-}"
SIMO_BYPASS_MARK="${SIMO_BYPASS_MARK:-0x0002}"
SIMO_RULE_PORTS="${SIMO_RULE_PORTS:-7890-7894}"
SIMO_BLOCK_QUIC="${SIMO_BLOCK_QUIC:-$(uci -q get simo.main.block_quic 2>/dev/null || echo 1)}"

MARK_TPROXY="${SIMO_MARK_TPROXY:-0x0001}"
MARK_TUN_UDP="${SIMO_MARK_TUN_UDP:-0x0003}"
TABLE_TPROXY="${SIMO_TABLE_TPROXY:-100}"
TABLE_TUN_UDP="${SIMO_TABLE_TUN_UDP:-101}"
PREF_TPROXY="${SIMO_PREF_TPROXY:-1000}"
PREF_TUN_UDP="${SIMO_PREF_TUN_UDP:-1001}"
RESERVED_NETWORKS="${SIMO_RESERVED_NETWORKS:-0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12 192.0.2.0/24 192.88.99.0/24 192.168.0.0/16 198.18.0.0/15 198.51.100.0/24 203.0.113.0/24 224.0.0.0/4 240.0.0.0/4 255.255.255.255/32}"
RESERVED_NETWORKS6="${SIMO_RESERVED_NETWORKS6:-::/128 ::1/128 fc00::/7 fe80::/10 ff00::/8}"

CORE_SAFE="$(printf '%s' "$SIMO_CORE" | tr -c 'A-Za-z0-9_' '_')"
TUN_NET_SECTION="simo_${CORE_SAFE}_tun"
TUN_ZONE_SECTION="simo_${CORE_SAFE}_zone"
TUN_FWD_SECTION="simo_${CORE_SAFE}_fwd"
TUN_ZONE_NAME="simo_${CORE_SAFE}"
TPROXY_RULE_SECTION="simo_${CORE_SAFE}_tproxy_rule"
TPROXY_ROUTE_SECTION="simo_${CORE_SAFE}_tproxy_route"
TPROXY_INCLUDE_SECTION="simo_${CORE_SAFE}_tproxy"
NFT_TABLE="simo_${CORE_SAFE}"
NFT_RULE_FILE="/var/etc/simo-${SIMO_CORE}-tproxy.nft"
SYSCTL_CONF_FILE="/etc/sysctl.d/99-simo-${SIMO_CORE}-tproxy.conf"
GUARD_NFT_TABLE="simo_guard"
GUARD_FORWARD_CHAIN="SIMO_GUARD_FORWARD"
GUARD_OUTPUT_CHAIN="SIMO_GUARD_OUTPUT"

msg() {
	logger -p daemon.info -t "simo-net[$SIMO_CORE]" "$*"
}

warn() {
	logger -p daemon.warn -t "simo-net[$SIMO_CORE]" "$*"
}

mode() {
	uci -q get simo.main.mode 2>/dev/null || echo tproxy
}

set_simo_mode() {
	uci set simo.main.mode="$1"
	uci commit simo
}

firewall_reload() {
	service firewall reload >/dev/null 2>&1 || /etc/init.d/firewall reload >/dev/null 2>&1 || true
}

network_reload() {
	uci commit network
	/etc/init.d/network reload >/dev/null 2>&1 || true
	ifup "$TUN_NET_SECTION" 2>/dev/null || true
}

configure_tun_interface() {
	uci set network."$TUN_NET_SECTION"=interface
	uci set network."$TUN_NET_SECTION".proto='none'
	uci set network."$TUN_NET_SECTION".device="$SIMO_TUN_IFACE"
	uci set network."$TUN_NET_SECTION".defaultroute='0'
	uci set network."$TUN_NET_SECTION".delegate='0'
	uci set network."$TUN_NET_SECTION".peerdns='0'
	uci set network."$TUN_NET_SECTION".auto='1'
	uci commit network
}

remove_tun_interface() {
	uci -q delete network."$TUN_NET_SECTION"
	uci commit network
}

configure_tun_firewall() {
	uci set firewall."$TUN_ZONE_SECTION"=zone
	uci set firewall."$TUN_ZONE_SECTION".name="$TUN_ZONE_NAME"
	uci set firewall."$TUN_ZONE_SECTION".forward='REJECT'
	uci set firewall."$TUN_ZONE_SECTION".output='ACCEPT'
	uci set firewall."$TUN_ZONE_SECTION".input='ACCEPT'
	uci set firewall."$TUN_ZONE_SECTION".masq='1'
	uci set firewall."$TUN_ZONE_SECTION".mtu_fix='1'
	uci set firewall."$TUN_ZONE_SECTION".device="$SIMO_TUN_IFACE"
	uci set firewall."$TUN_ZONE_SECTION".family='ipv4'
	uci -q delete firewall."$TUN_ZONE_SECTION".network
	uci add_list firewall."$TUN_ZONE_SECTION".network="$TUN_NET_SECTION"

	uci set firewall."$TUN_FWD_SECTION"=forwarding
	uci set firewall."$TUN_FWD_SECTION".src='lan'
	uci set firewall."$TUN_FWD_SECTION".dest="$TUN_ZONE_NAME"
	uci set firewall."$TUN_FWD_SECTION".family='ipv4'
	uci commit firewall
}

remove_tun_firewall() {
	uci -q delete firewall."$TUN_FWD_SECTION"
	uci -q delete firewall."$TUN_ZONE_SECTION"
	uci commit firewall
}

install_sysctl_config() {
	local iface
	for iface in /proc/sys/net/ipv4/conf/*/route_localnet; do
		[ -e "$iface" ] && echo 1 > "$iface" 2>/dev/null || true
	done
	mkdir -p /etc/sysctl.d
	cat > "$SYSCTL_CONF_FILE" << EOF
net.ipv4.conf.all.route_localnet=1
net.ipv4.conf.default.route_localnet=1
EOF
	sysctl -p "$SYSCTL_CONF_FILE" >/dev/null 2>&1 || true
}

uninstall_sysctl_config() {
	local iface
	for iface in /proc/sys/net/ipv4/conf/*/route_localnet; do
		[ -e "$iface" ] && echo 0 > "$iface" 2>/dev/null || true
	done
	rm -f "$SYSCTL_CONF_FILE"
}

setup_tproxy_routing() {
	cleanup_tproxy_routing
	ip rule add pref "$PREF_TPROXY" fwmark "$MARK_TPROXY" table "$TABLE_TPROXY" 2>/dev/null || true
	ip route replace local 0.0.0.0/0 dev lo table "$TABLE_TPROXY" 2>/dev/null || true

	uci set network."$TPROXY_RULE_SECTION"=rule
	uci set network."$TPROXY_RULE_SECTION".mark="$MARK_TPROXY"
	uci set network."$TPROXY_RULE_SECTION".lookup="$TABLE_TPROXY"
	uci set network."$TPROXY_RULE_SECTION".priority="$PREF_TPROXY"

	uci set network."$TPROXY_ROUTE_SECTION"=route
	uci set network."$TPROXY_ROUTE_SECTION".interface='loopback'
	uci set network."$TPROXY_ROUTE_SECTION".target='0.0.0.0'
	uci set network."$TPROXY_ROUTE_SECTION".netmask='0.0.0.0'
	uci set network."$TPROXY_ROUTE_SECTION".table="$TABLE_TPROXY"
	uci set network."$TPROXY_ROUTE_SECTION".type='local'
	uci commit network
}

cleanup_tproxy_routing() {
	while ip rule del fwmark "$MARK_TPROXY" table "$TABLE_TPROXY" 2>/dev/null; do :; done
	while ip rule del fwmark "$MARK_TUN_UDP" table "$TABLE_TUN_UDP" 2>/dev/null; do :; done
	ip route flush table "$TABLE_TPROXY" 2>/dev/null || true
	ip route flush table "$TABLE_TUN_UDP" 2>/dev/null || true
	uci -q delete network."$TPROXY_RULE_SECTION"
	uci -q delete network."$TPROXY_ROUTE_SECTION"
	uci commit network
}

setup_tun_policy_route() {
	local current_mode
	current_mode="$(mode)"
	case "$current_mode" in
		tun)
			while ip rule del fwmark "$MARK_TPROXY" table "$TABLE_TPROXY" 2>/dev/null; do :; done
			ip rule add pref "$PREF_TPROXY" fwmark "$MARK_TPROXY" table "$TABLE_TPROXY" 2>/dev/null || true
			ip route replace default dev "$SIMO_TUN_IFACE" table "$TABLE_TPROXY" 2>/dev/null || true
			;;
		mixed)
			while ip rule del fwmark "$MARK_TUN_UDP" table "$TABLE_TUN_UDP" 2>/dev/null; do :; done
			ip rule add pref "$PREF_TUN_UDP" fwmark "$MARK_TUN_UDP" table "$TABLE_TUN_UDP" 2>/dev/null || true
			ip route replace default dev "$SIMO_TUN_IFACE" table "$TABLE_TUN_UDP" 2>/dev/null || true
			;;
	esac
}

validate_policy() {
	local current_mode
	current_mode="$(mode)"
	case "$current_mode" in
		tun)
			ip rule show 2>/dev/null | grep -Eq "fwmark (0x0*1|1)(/[0-9xa-fA-F]+)? .*lookup ${TABLE_TPROXY}( |$)" || return 1
			ip route show table "$TABLE_TPROXY" 2>/dev/null | grep -q "default dev $SIMO_TUN_IFACE" || return 1
			;;
		mixed)
			ip rule show 2>/dev/null | grep -Eq "fwmark (0x0*1|1)(/[0-9xa-fA-F]+)? .*lookup ${TABLE_TPROXY}( |$)" || return 1
			ip route show table "$TABLE_TPROXY" 2>/dev/null | grep -q 'local 0.0.0.0/0 dev lo' || return 1
			ip rule show 2>/dev/null | grep -Eq "fwmark (0x0*3|3)(/[0-9xa-fA-F]+)? .*lookup ${TABLE_TUN_UDP}( |$)" || return 1
			ip route show table "$TABLE_TUN_UDP" 2>/dev/null | grep -q "default dev $SIMO_TUN_IFACE" || return 1
			;;
		*)
			ip rule show 2>/dev/null | grep -Eq "fwmark (0x0*1|1)(/[0-9xa-fA-F]+)? .*lookup ${TABLE_TPROXY}( |$)" || return 1
			ip route show table "$TABLE_TPROXY" 2>/dev/null | grep -q 'local 0.0.0.0/0 dev lo' || return 1
			;;
	esac
}

write_tproxy_nft_file() {
	local current_mode udp_rule tcp_rule block_quic_rule
	current_mode="$(mode)"
	tcp_rule="ip protocol tcp tproxy to 127.0.0.1:${SIMO_TPROXY_PORT} meta mark set \$PROXY_FWMARK"
	case "$current_mode" in
		mixed)
			udp_rule="ip protocol udp meta mark set ${MARK_TUN_UDP}"
			;;
		*)
			udp_rule="ip protocol udp tproxy to 127.0.0.1:${SIMO_TPROXY_PORT} meta mark set \$PROXY_FWMARK"
			;;
	esac
	case "$SIMO_BLOCK_QUIC" in
		1|true|yes|on) block_quic_rule="        udp dport 443 drop" ;;
		*) block_quic_rule="" ;;
	esac
	mkdir -p "$(dirname "$NFT_RULE_FILE")"
	cat > "$NFT_RULE_FILE" << EOF
table ip $NFT_TABLE {}
delete table ip $NFT_TABLE

define PROXY_FWMARK = ${MARK_TPROXY}
define BYPASS_MARK = ${SIMO_BYPASS_MARK}
define RESERVED_IP = {
    0.0.0.0/8,
    10.0.0.0/8,
    100.64.0.0/10,
    127.0.0.0/8,
    169.254.0.0/16,
    172.16.0.0/12,
    192.0.2.0/24,
    192.88.99.0/24,
    192.168.0.0/16,
    198.18.0.0/15,
    198.51.100.0/24,
    203.0.113.0/24,
    224.0.0.0/4,
    240.0.0.0/4,
    255.255.255.255/32
}

table ip $NFT_TABLE {
    chain prerouting {
        type filter hook prerouting priority mangle; policy accept;
        ct status dnat return
        ip daddr \$RESERVED_IP return
        meta mark \$BYPASS_MARK return
        tcp dport ${SIMO_RULE_PORTS} return
        udp dport ${SIMO_RULE_PORTS} return
        tcp sport ${SIMO_RULE_PORTS} return
        udp sport ${SIMO_RULE_PORTS} return
${block_quic_rule}
        $tcp_rule
        $udp_rule
    }
}
EOF
}

install_tproxy_nft_rule() {
	write_tproxy_nft_file
	nft -f "$NFT_RULE_FILE"
}

uninstall_tproxy_nft_rule() {
	nft delete table ip "$NFT_TABLE" 2>/dev/null || true
	rm -f "$NFT_RULE_FILE"
}

flush_tproxy_table() {
	nft delete table ip "$NFT_TABLE" 2>/dev/null || true
}

ensure_tproxy_firewall_include() {
	uci set firewall."$TPROXY_INCLUDE_SECTION"=include
	uci set firewall."$TPROXY_INCLUDE_SECTION".type='nftables'
	uci set firewall."$TPROXY_INCLUDE_SECTION".path="$NFT_RULE_FILE"
	uci set firewall."$TPROXY_INCLUDE_SECTION".position='ruleset-prepend'
	uci -q delete firewall."$TPROXY_INCLUDE_SECTION".chain || true
	uci set firewall."$TPROXY_INCLUDE_SECTION".enabled='1'
	uci commit firewall
}

remove_tproxy_firewall_include() {
	uci -q delete firewall."$TPROXY_INCLUDE_SECTION"
	uci commit firewall
}

guard_enabled() {
	[ "$(uci -q get simo.main.internet_only 2>/dev/null)" = "1" ]
}

detect_wan_ifaces() {
	local configured
	configured="$(uci -q get simo.main.guard_wan_ifaces 2>/dev/null || true)"
	if [ -n "$configured" ]; then
		printf '%s\n' "$configured"
		return 0
	fi
	ip route show default 2>/dev/null | awk '{ for (i = 1; i <= NF; i++) if ($i == "dev") print $(i + 1) }' | sort -u
}

remove_guard_rules() {
	nft delete table inet "$GUARD_NFT_TABLE" 2>/dev/null || true
	if command -v iptables >/dev/null 2>&1; then
		while iptables -D FORWARD -j "$GUARD_FORWARD_CHAIN" 2>/dev/null; do :; done
		while iptables -D OUTPUT -j "$GUARD_OUTPUT_CHAIN" 2>/dev/null; do :; done
		iptables -F "$GUARD_FORWARD_CHAIN" 2>/dev/null || true
		iptables -X "$GUARD_FORWARD_CHAIN" 2>/dev/null || true
		iptables -F "$GUARD_OUTPUT_CHAIN" 2>/dev/null || true
		iptables -X "$GUARD_OUTPUT_CHAIN" 2>/dev/null || true
	fi
}

apply_guard_rules() {
	local ifaces iface
	ifaces="$(detect_wan_ifaces)"
	remove_guard_rules
	[ -n "$ifaces" ] || return 0

	if command -v nft >/dev/null 2>&1; then
		nft add table inet "$GUARD_NFT_TABLE"
		nft add set inet "$GUARD_NFT_TABLE" local4 '{ type ipv4_addr; flags interval; auto-merge; }'
		nft add set inet "$GUARD_NFT_TABLE" local6 '{ type ipv6_addr; flags interval; auto-merge; }'
		nft add element inet "$GUARD_NFT_TABLE" local4 "{ $(printf '%s\n' $RESERVED_NETWORKS | tr '\n' ',' | sed 's/,$//') }" 2>/dev/null || true
		nft add element inet "$GUARD_NFT_TABLE" local6 "{ $(printf '%s\n' $RESERVED_NETWORKS6 | tr '\n' ',' | sed 's/,$//') }" 2>/dev/null || true
		nft add chain inet "$GUARD_NFT_TABLE" forward '{ type filter hook forward priority 1; policy accept; }'
		nft add chain inet "$GUARD_NFT_TABLE" output '{ type filter hook output priority 1; policy accept; }'
		nft add rule inet "$GUARD_NFT_TABLE" forward ct state established,related accept
		nft add rule inet "$GUARD_NFT_TABLE" forward iifname "$SIMO_TUN_IFACE" accept 2>/dev/null || true
		nft add rule inet "$GUARD_NFT_TABLE" forward oifname "$SIMO_TUN_IFACE" accept 2>/dev/null || true
		nft add rule inet "$GUARD_NFT_TABLE" forward ct status dnat accept
		nft add rule inet "$GUARD_NFT_TABLE" forward udp sport 67 udp dport 68 accept
		nft add rule inet "$GUARD_NFT_TABLE" forward udp sport 68 udp dport 67 accept
		nft add rule inet "$GUARD_NFT_TABLE" forward ip daddr @local4 accept
		nft add rule inet "$GUARD_NFT_TABLE" forward ip6 daddr @local6 accept
		nft add rule inet "$GUARD_NFT_TABLE" output ct state established,related accept
		nft add rule inet "$GUARD_NFT_TABLE" output oifname lo accept
		nft add rule inet "$GUARD_NFT_TABLE" output meta mark "$MARK_TPROXY" accept
		nft add rule inet "$GUARD_NFT_TABLE" output meta mark "$MARK_TUN_UDP" accept
		nft add rule inet "$GUARD_NFT_TABLE" output meta mark "$SIMO_BYPASS_MARK" accept
		nft add rule inet "$GUARD_NFT_TABLE" output ip daddr @local4 accept
		nft add rule inet "$GUARD_NFT_TABLE" output ip6 daddr @local6 accept
		printf '%s\n' "$ifaces" | while IFS= read -r iface; do
			[ -n "$iface" ] || continue
			nft add rule inet "$GUARD_NFT_TABLE" forward oifname "$iface" drop comment "simo-guard" 2>/dev/null || true
			nft add rule inet "$GUARD_NFT_TABLE" output oifname "$iface" drop comment "simo-guard" 2>/dev/null || true
		done
		return 0
	fi

	if command -v iptables >/dev/null 2>&1; then
		iptables -N "$GUARD_FORWARD_CHAIN" 2>/dev/null || true
		iptables -N "$GUARD_OUTPUT_CHAIN" 2>/dev/null || true
		iptables -F "$GUARD_FORWARD_CHAIN" 2>/dev/null || true
		iptables -F "$GUARD_OUTPUT_CHAIN" 2>/dev/null || true
		iptables -C FORWARD -j "$GUARD_FORWARD_CHAIN" 2>/dev/null || iptables -A FORWARD -j "$GUARD_FORWARD_CHAIN"
		iptables -C OUTPUT -j "$GUARD_OUTPUT_CHAIN" 2>/dev/null || iptables -A OUTPUT -j "$GUARD_OUTPUT_CHAIN"
		iptables -A "$GUARD_FORWARD_CHAIN" -i "$SIMO_TUN_IFACE" -j RETURN 2>/dev/null || true
		iptables -A "$GUARD_FORWARD_CHAIN" -o "$SIMO_TUN_IFACE" -j RETURN 2>/dev/null || true
		iptables -A "$GUARD_OUTPUT_CHAIN" -m mark --mark "$MARK_TPROXY" -j RETURN 2>/dev/null || true
		iptables -A "$GUARD_OUTPUT_CHAIN" -m mark --mark "$MARK_TUN_UDP" -j RETURN 2>/dev/null || true
		iptables -A "$GUARD_OUTPUT_CHAIN" -m mark --mark "$SIMO_BYPASS_MARK" -j RETURN 2>/dev/null || true
		printf '%s\n' "$ifaces" | while IFS= read -r iface; do
			[ -n "$iface" ] || continue
			iptables -A "$GUARD_FORWARD_CHAIN" -o "$iface" -j DROP 2>/dev/null || true
			iptables -A "$GUARD_OUTPUT_CHAIN" -o "$iface" -j DROP 2>/dev/null || true
		done
	fi
}

refresh_guard_rules() {
	if guard_enabled; then
		apply_guard_rules
	else
		remove_guard_rules
	fi
}

case "$ACTION" in
	start)
		refresh_guard_rules
		echo ok
		;;
	stop)
		remove_guard_rules
		echo ok
		;;
	restart)
		"$0" "$CORE" stop
		"$0" "$CORE" start
		;;
	enable-tun)
		set_simo_mode tun
		configure_tun_interface
		configure_tun_firewall
		firewall_reload
		network_reload
		setup_tun_policy_route
		refresh_guard_rules
		echo ok
		;;
	disable-tun)
		remove_tun_interface
		remove_tun_firewall
		cleanup_tproxy_routing
		firewall_reload
		network_reload
		refresh_guard_rules
		echo ok
		;;
	enable-tproxy)
		set_simo_mode tproxy
		setup_tproxy_routing
		install_sysctl_config
		install_tproxy_nft_rule
		ensure_tproxy_firewall_include
		flush_tproxy_table
		firewall_reload
		refresh_guard_rules
		echo ok
		;;
	enable-mixed)
		set_simo_mode mixed
		configure_tun_interface
		configure_tun_firewall
		setup_tproxy_routing
		setup_tun_policy_route
		install_sysctl_config
		install_tproxy_nft_rule
		ensure_tproxy_firewall_include
		flush_tproxy_table
		firewall_reload
		network_reload
		setup_tun_policy_route
		refresh_guard_rules
		echo ok
		;;
	disable-tproxy)
		remove_tproxy_firewall_include
		firewall_reload
		uninstall_tproxy_nft_rule
		cleanup_tproxy_routing
		uninstall_sysctl_config
		refresh_guard_rules
		echo ok
		;;
	validate_policy)
		validate_policy
		echo ok
		;;
	repair_policy)
		case "$(mode)" in
			tun) setup_tun_policy_route ;;
			mixed)
				setup_tproxy_routing
				setup_tun_policy_route
				;;
			*) setup_tproxy_routing ;;
		esac
		validate_policy
		echo ok
		;;
	guard_start)
		apply_guard_rules
		echo ok
		;;
	guard_stop)
		remove_guard_rules
		echo ok
		;;
	guard_refresh)
		refresh_guard_rules
		echo ok
		;;
	tun_route_setup|tun_route_watch)
		setup_tun_policy_route
		echo ok
		;;
	full_cleanup)
		"$0" "$CORE" disable-tproxy >/dev/null 2>&1 || true
		"$0" "$CORE" disable-tun >/dev/null 2>&1 || true
		remove_guard_rules
		echo ok
		;;
	*)
		echo "Usage: $0 <core> {start|stop|restart|enable-tun|disable-tun|enable-tproxy|enable-mixed|disable-tproxy|validate_policy|repair_policy|guard_start|guard_stop|guard_refresh|tun_route_setup|tun_route_watch|full_cleanup}" >&2
		exit 1
		;;
esac
