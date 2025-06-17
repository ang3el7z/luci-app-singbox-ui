include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-singbox-ui
PKG_VERSION:=1.2.1
PKG_RELEASE:=13

LUCI_TITLE:=LuCI singbox-ui app
LUCI_DEPENDS:=+luci-base +sing-box +nano +curl +jq
LUCI_PKGARCH:=all
LUCI_LANG.ru:=Русский (Russian)
LUCI_LANG.en:=English

PKG_LICENSE:=GPL-2.0-or-later
PKG_MAINTAINER:=ang3el <ang3el7z@gmail.com>

LUCI_LANGUAGES:=en ru

define Package/$(PKG_NAME)/install
	$(CP) ./root/* $(1)/
	chmod 0755 $(1)/etc/init.d/singbox-ui-autoupdater
	chmod 0755 $(1)/usr/bin/singbox-ui/singbox-ui-updater
	chmod 0755 $(1)/usr/bin/singbox-ui/singbox-ui-autoupdater-wrapper
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
