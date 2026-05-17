include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-singbox-ui
PKG_VERSION:=2.3.11
PKG_RELEASE:=1

LUCI_TITLE:=LuCI singbox-ui app
LUCI_DEPENDS:=+luci-base +sing-box +curl +jq
LUCI_PKGARCH:=all
PKG_LICENSE:=GPL-2.0-only
PKG_MAINTAINER:=Ang3el <singboxui@ang3el.world>

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
