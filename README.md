# luci-app-singbox-ui

[🇷🇺 Читать на русском](./README.ru.md)

Web interface for Sing-Box on OpenWrt 23/24

**luci-app-singbox-ui** is a simple, personal web interface for managing the Sing-Box service on OpenWRT.

> ⚠️ **Warning**
>
> This material is provided strictly for **educational and research purposes only**.  
> The author **is not responsible** for any distribution, misuse, damage to devices, or violations caused by using this software.  
> You use all provided content **at your own risk**.  
> The author **does not encourage** any commercial or malicious use.  
> If you do not agree with these terms, **delete all files** obtained from this repository.

# [Screenshots](./preview.md)

## Features
- Control the Sing-Box service (start/stop/restart)
- Add subscriptions via URL or paste JSON manually
- Store and edit multiple configs in the browser
- Service autoupdate
- Service health autoupdate && sing-Box
- Service memory low (restat sing-box)

# Installation

## Install singbox (tun mode) + singbox-ui
```shell
wget -O /root/install-singbox+singbox-ui.sh https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/main/other/install-singbox+singbox-ui.sh && chmod 0755 /root/install-singbox+singbox-ui.sh && sh /root/install-singbox+singbox-ui.sh
```

## Install singbox-ui
```shell
wget -O /root/install-singbox-ui.sh https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/main/other/install-singbox-ui.sh && chmod 0755 /root/install-singbox-ui.sh && sh /root/install-singbox-ui.sh
```

## Install singbox (tun mode)
```shell
wget -O /root/install-singbox.sh https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/main/other/install-singbox.sh && chmod 0755 /root/install-singbox.sh && sh /root/install-singbox.sh
```

# other helps
 - ssh keygen clear
```shell
ssh-keygen -R 192.168.1.1
```
 - connect router
```shell
ssh root@192.168.1.1
```
 - refresh openwrt (fix visibility plugin) -> `Cntrl + Shift + I`
 - [`openwrt template original 2.11`](https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/main/other/file/openwrt-template-original-openwrt_2.11.json)
 - [`openwrt template bot 2.11`](https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/main/other/file/openwrt-template-bot-openwrt_2.11.json)
 - [`fix low "tun mode" speed`](https://github.com/ang3el7z/luci-app-singbox-ui/issues/1)
 - install one click
```shell
wget -O install-one-click.sh https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/main/other/install-one-click.sh && chmod +x install-one-click.sh && ./install-one-click.sh
```

# Thanks
[@strayge](https://github.com/strayge)
