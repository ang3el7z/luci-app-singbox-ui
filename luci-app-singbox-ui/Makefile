include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-singbox-ui
PKG_VERSION:=1.3.2
PKG_RELEASE:=1

LUCI_TITLE:=LuCI singbox-ui app
LUCI_DEPENDS:=+luci-base +sing-box +curl +jq
LUCI_PKGARCH:=all
LUCI_LANG.ru:=Русский (Russian)
LUCI_LANG.en:=English

PKG_LICENSE:=GPL-2.0-or-later
PKG_MAINTAINER:=Ang3el <singboxui@ang3el.world>
LUCI_LANGUAGES:=en ru

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
