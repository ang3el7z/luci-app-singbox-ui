# luci-app-singbox-ui
Web interface for Sing-Box on OpenWrt 23.05.5

[🇷🇺 Читать на русском](./README.ru.md)

**luci-app-singbox-ui** is a simple, personal web interface for managing the Sing-Box service on OpenWRT.

## Features
- Control the Sing-Box service (start/stop/restart)
- Add subscriptions via URL or paste JSON manually
- Store and edit multiple configs in the browser
- Enable auto-update of config via URL

# Installation

## Install singbox (tun mode) + singbox-ui
wget -O /root/install-singbox+singbox-ui.sh https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/main/other/install-singbox+singbox-ui.sh && chmod 0755 /root/install-singbox+singbox-ui.sh && sh /root/install-singbox+singbox-ui.sh

## Install singbox-ui
wget -O /root/install-singbox-ui.sh https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/main/other/install-singbox-ui.sh && chmod 0755 /root/install-singbox-ui.sh && sh /root/install-singbox-ui.sh

## Install singbox (tun mode)
wget -O /root/install-singbox.sh https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/main/other/install-singbox.sh && chmod 0755 /root/install-singbox.sh && sh /root/install-singbox.sh

# [Screenshot](./preview.md)

# other helps
 - Ssh-keygen -R 192.168.1.1
 - Connect router -> ssh root@192.168.1.1
 - REFRESH OPENWRT (Fix visibility plugin) -> CNTRL + SHIFT + I
 - [openwrt-template-openwrt_2.11.json](https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/main/other/file/openwrt-template-openwrt_2.11.json)
 - ["tun" interface with "auto_route" option limited performance on routers](https://github.com/ang3el7z/luci-app-singbox-ui/issues/1)

# Thanks
[@strayge](https://github.com/strayge)
