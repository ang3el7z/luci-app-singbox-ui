include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-singbox-ui
PKG_VERSION:=1.3.3
PKG_RELEASE:=1

PKG_MAINTAINER:=Ang3el <singboxui@ang3el.world>
PKG_LICENSE:=GPL-2.0-or-later
PKG_LICENSE_FILES:=LICENSE

LUCI_TITLE:=LuCI Sing-Box UI
LUCI_DESCRIPTION:=Web interface for managing Sing-Box service on OpenWrt
LUCI_DEPENDS:=+luci-base +luci-mod-admin-full +sing-box +curl +jq
LUCI_PKGARCH:=all

# Language support
LUCI_LANGUAGES:=en ru
LUCI_LANG.ru:=Русский (Russian)
LUCI_LANG.en:=English

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
