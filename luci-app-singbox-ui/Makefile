include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-singb
PKG_VERSION:=0.1.6
PKG_RELEASE:=7

LUCI_TITLE:=LuCI singb app
LUCI_DEPENDS:=+luci-base +sing-box
LUCI_PKGARCH:=all
LUCI_LANG.ru:=Русский (Russian)
LUCI_LANG.en:=English

PKG_LICENSE:=GPL-2.0-or-later
PKG_MAINTAINER:=ITDog <singb@singb.singb>

LUCI_LANGUAGES:=en ru

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
