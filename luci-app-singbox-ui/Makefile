include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-singbox-ui

PKG_VERSION:=1.2.1
PKG_RELEASE:=1

LUCI_TITLE:=LuCI singbox-ui app
LUCI_DEPENDS:=+luci-base +sing-box +curl +jq
LUCI_PKGARCH:=all
LUCI_LANG.ru:=Русский (Russian)
LUCI_LANG.en:=English

PKG_LICENSE:=GPL-2.0-or-later
PKG_MAINTAINER:=ang3el <ang3el7z@gmail.com>

LUCI_LANGUAGES:=en ru

#define Package/$(PKG_NAME)/install
#	# etc | Optional defaults config
#	$(INSTALL_DIR) $(1)/etc/config
#	$(INSTALL_DATA) ./root/etc/config/* $(1)/etc/config/
#
#	# etc | Init script (singbox-ui-autoupdater)
#	$(INSTALL_DIR) $(1)/etc/init.d
#	$(INSTALL_BIN) ./root/etc/init.d/singbox-ui-autoupdater $(1)/etc/init.d/
#
#	# etc | Need defaults (config files)
#	$(INSTALL_DIR) $(1)/etc/sing-box
#	$(INSTALL_DATA) ./root/etc/sing-box/* $(1)/etc/sing-box/
#
#	# etc | Optional defaults
#	$(INSTALL_DIR) $(1)/etc/uci-defaults
#	$(INSTALL_BIN) ./root/etc/uci-defaults/* $(1)/etc/uci-defaults/
#
#	# User binaries (Updater, Health)
#	$(INSTALL_DIR) $(1)/usr/bin/singbox-ui
#	$(INSTALL_BIN) ./root/usr/bin/singbox-ui/* $(1)/usr/bin/singbox-ui/
#
#	# usr | LuCI menu
#	$(INSTALL_DIR) $(1)/usr/share/luci/menu.d
#	$(INSTALL_DATA) ./root/usr/share/luci/menu.d/* $(1)/usr/share/luci/menu.d/
#
#	# usr | LuCI acl
#	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
#	$(INSTALL_DATA) ./root/usr/share/rpcd/acl.d/* $(1)/usr/share/rpcd/acl.d/
#endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
