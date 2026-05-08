include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-simo
PKG_VERSION:=0.1.0
PKG_RELEASE:=1
PKG_MAINTAINER:=Ang3el <singboxui@ang3el.world>

LUCI_TITLE:=LuCI Simo proxy manager
LUCI_DEPENDS:=+luci-base +curl +jq +coreutils-base64 +kmod-tun +nftables +kmod-nft-nat +kmod-nft-tproxy +kmod-nft-socket
LUCI_PKGARCH:=all

PKG_BUILD_DEPENDS:=luci-base/host

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
	SECTION:=luci
	CATEGORY:=LuCI
	SUBMENU:=3. Applications
	TITLE:=$(LUCI_TITLE)
	DEPENDS:=$(LUCI_DEPENDS)
	PKGARCH:=$(LUCI_PKGARCH)
endef

define Package/$(PKG_NAME)/description
	Simo is a LuCI proxy manager with pluggable core providers.
	Mihomo and sing-box live side by side under /opt/simo/cores.
endef

define Build/Prepare
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/conffiles
/etc/config/simo
/opt/simo/cores/mihomo/config.yaml
/opt/simo/cores/mihomo/config2.yaml
/opt/simo/cores/mihomo/config3.yaml
/opt/simo/cores/mihomo/settings
/opt/simo/cores/singbox/config.json
/opt/simo/cores/singbox/config2.json
/opt/simo/cores/singbox/config3.json
/opt/simo/cores/singbox/url_config.json
/opt/simo/cores/singbox/url_config2.json
/opt/simo/cores/singbox/url_config3.json
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./rootfs/etc/config/simo $(1)/etc/config/simo

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./rootfs/etc/init.d/simo $(1)/etc/init.d/simo
	$(INSTALL_BIN) ./rootfs/etc/init.d/simo-autoupdater-service $(1)/etc/init.d/simo-autoupdater-service
	$(INSTALL_BIN) ./rootfs/etc/init.d/simo-health-autoupdater-service $(1)/etc/init.d/simo-health-autoupdater-service
	$(INSTALL_BIN) ./rootfs/etc/init.d/simo-memdoc-service $(1)/etc/init.d/simo-memdoc-service

	$(INSTALL_DIR) $(1)/etc/hotplug.d/iface
	$(INSTALL_BIN) ./rootfs/etc/hotplug.d/iface/40-simo-mihomo $(1)/etc/hotplug.d/iface/
	$(INSTALL_DIR) $(1)/etc/hotplug.d/net
	$(INSTALL_BIN) ./rootfs/etc/hotplug.d/net/99-simo-mihomo-tun $(1)/etc/hotplug.d/net/

	$(INSTALL_DIR) $(1)/opt/simo/cores/mihomo/bin
	$(INSTALL_BIN) ./rootfs/opt/simo/cores/mihomo/bin/mihomo-rules $(1)/opt/simo/cores/mihomo/bin/
	$(INSTALL_DIR) $(1)/opt/simo/cores/mihomo
	$(INSTALL_DATA) ./rootfs/opt/simo/cores/mihomo/config.yaml $(1)/opt/simo/cores/mihomo/
	$(INSTALL_DIR) $(1)/opt/simo/cores/mihomo/ui
	$(CP) ./rootfs/opt/simo/cores/mihomo/ui/* $(1)/opt/simo/cores/mihomo/ui/
	$(INSTALL_DIR) $(1)/opt/simo/cores/mihomo/lst

	$(INSTALL_DIR) $(1)/opt/simo/cores/singbox
	$(INSTALL_DATA) ./rootfs/opt/simo/cores/singbox/config.json $(1)/opt/simo/cores/singbox/
	$(INSTALL_DATA) ./rootfs/opt/simo/cores/singbox/config2.json $(1)/opt/simo/cores/singbox/
	$(INSTALL_DATA) ./rootfs/opt/simo/cores/singbox/config3.json $(1)/opt/simo/cores/singbox/
	$(INSTALL_DATA) ./rootfs/opt/simo/cores/singbox/url_config.json $(1)/opt/simo/cores/singbox/
	$(INSTALL_DATA) ./rootfs/opt/simo/cores/singbox/url_config2.json $(1)/opt/simo/cores/singbox/
	$(INSTALL_DATA) ./rootfs/opt/simo/cores/singbox/url_config3.json $(1)/opt/simo/cores/singbox/
	$(INSTALL_DIR) $(1)/opt/simo/cores/singbox/bin

	$(INSTALL_DIR) $(1)/usr/bin/simo
	$(INSTALL_BIN) ./rootfs/usr/bin/simo/* $(1)/usr/bin/simo/

	$(INSTALL_DIR) $(1)/usr/libexec/simo/cores/mihomo
	$(INSTALL_BIN) ./rootfs/usr/libexec/simo/cores/mihomo/core.sh $(1)/usr/libexec/simo/cores/mihomo/
	$(INSTALL_DATA) ./rootfs/usr/libexec/simo/cores/mihomo/manifest.json $(1)/usr/libexec/simo/cores/mihomo/
	$(INSTALL_DIR) $(1)/usr/libexec/simo/cores/singbox
	$(INSTALL_BIN) ./rootfs/usr/libexec/simo/cores/singbox/core.sh $(1)/usr/libexec/simo/cores/singbox/
	$(INSTALL_DATA) ./rootfs/usr/libexec/simo/cores/singbox/manifest.json $(1)/usr/libexec/simo/cores/singbox/
	$(INSTALL_DATA) ./rootfs/usr/libexec/simo/cores/singbox/tproxy.nft $(1)/usr/libexec/simo/cores/singbox/

	$(INSTALL_DIR) $(1)/usr/share/luci/menu.d
	$(INSTALL_DATA) ./rootfs/usr/share/luci/menu.d/luci-app-simo.json $(1)/usr/share/luci/menu.d/
	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DATA) ./rootfs/usr/share/rpcd/acl.d/luci-app-simo.json $(1)/usr/share/rpcd/acl.d/

	$(INSTALL_DIR) $(1)/www/luci-static/resources/view/simo
	$(CP) ./rootfs/www/luci-static/resources/view/simo/* $(1)/www/luci-static/resources/view/simo/

ifdef CONFIG_USE_APK
	$(INSTALL_DIR) $(1)/etc/apk/protected_paths.d
	$(INSTALL_DATA) ./rootfs/etc/apk/protected_paths.d/simo.list $(1)/etc/apk/protected_paths.d/
endif
endef

define Package/$(PKG_NAME)/postinst
#!/bin/sh
[ -n "$$IPKG_INSTROOT" ] || {
	mkdir -p /opt/simo/cores/mihomo/bin /opt/simo/cores/mihomo/lst
	mkdir -p /opt/simo/cores/singbox/bin
	[ -f /opt/simo/cores/singbox/config.json ] || printf '{}\n' > /opt/simo/cores/singbox/config.json
	[ -f /etc/config/simo ] || {
		uci set simo.main=simo
		uci set simo.main.core='mihomo'
		uci commit simo
	}
	/etc/init.d/simo disable >/dev/null 2>&1 || true
	/etc/init.d/simo-autoupdater-service disable >/dev/null 2>&1 || true
	/etc/init.d/simo-health-autoupdater-service disable >/dev/null 2>&1 || true
	/etc/init.d/simo-memdoc-service disable >/dev/null 2>&1 || true
	rm -f /var/luci-indexcache* /tmp/luci-indexcache* 2>/dev/null
	find /tmp -name 'luci-*cache*' -delete 2>/dev/null
	[ -x /etc/init.d/rpcd ] && /etc/init.d/rpcd reload >/dev/null 2>&1 || true
	[ -x /etc/init.d/uhttpd ] && /etc/init.d/uhttpd restart >/dev/null 2>&1 || true
}
exit 0
endef

define Package/$(PKG_NAME)/prerm
#!/bin/sh
[ -n "$$IPKG_INSTROOT" ] || {
	[ -x /etc/init.d/simo-autoupdater-service ] && /etc/init.d/simo-autoupdater-service stop >/dev/null 2>&1 || true
	[ -x /etc/init.d/simo-health-autoupdater-service ] && /etc/init.d/simo-health-autoupdater-service stop >/dev/null 2>&1 || true
	[ -x /etc/init.d/simo-memdoc-service ] && /etc/init.d/simo-memdoc-service stop >/dev/null 2>&1 || true
	[ -x /etc/init.d/simo ] && /etc/init.d/simo stop >/dev/null 2>&1 || true
	[ -x /usr/bin/simo/simo-mode-switch ] && /usr/bin/simo/simo-mode-switch disable-tproxy >/dev/null 2>&1 || true
	[ -x /usr/bin/simo/simo-mode-switch ] && /usr/bin/simo/simo-mode-switch disable-tun >/dev/null 2>&1 || true
}
exit 0
endef

define Package/$(PKG_NAME)/postrm
#!/bin/sh
[ -n "$$IPKG_INSTROOT" ] || {
	rm -f /var/luci-indexcache* /tmp/luci-indexcache* 2>/dev/null
	find /tmp -name 'luci-*cache*' -delete 2>/dev/null
	[ -x /etc/init.d/rpcd ] && /etc/init.d/rpcd reload >/dev/null 2>&1 || true
	[ -x /etc/init.d/uhttpd ] && /etc/init.d/uhttpd restart >/dev/null 2>&1 || true
	case "$$1" in
		upgrade|update)
			;;
		*)
			rm -f /opt/simo/cores/mihomo/bin/mihomo
			rm -f /opt/simo/cores/singbox/bin/sing-box
			;;
	esac
}
exit 0
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
