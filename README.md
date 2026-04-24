# luci-app-singbox-ui

[Читать на русском](./README.ru.md)

Web interface for managing Sing-Box on OpenWrt 23/24/25.

## Screenshot

<img width="972" height="858" alt="luci-app-singbox-ui screenshot" src="https://github.com/user-attachments/assets/198efa7a-6861-4f5f-9685-c717f3bb82a1" />

## Disclaimer

> **Disclaimer**  
> This project is intended **strictly for educational and research purposes**.  
> The author **takes no responsibility** for misuse, damage to devices, or any consequences of use.  
> You use everything at **your own risk**. Commercial or malicious use is **not encouraged**.

## Features

- Start, stop, and restart the Sing-Box service
- Add subscriptions via URL or manual JSON
- Store and edit multiple configs in the browser
- Auto-update the Sing-Box service
- Check service and binary status
- Auto-restart on low memory

## Installation

```bash
wget -O /root/install.sh https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/main/install.sh && chmod 0755 /root/install.sh && BRANCH="main" sh /root/install.sh
```

After running the script:

1. Choose mode:
- `Singbox-ui`
- `Singbox (tproxy/tun mode)`
- `Singbox (tproxy/tun mode) + singbox-ui`
2. Choose operation:
- `Install`
- `Uninstall`
- `Reinstall / Update`

## Quick Tips

Clear old SSH key:

```bash
ssh-keygen -R 192.168.1.1
```

Connect to router:

```bash
ssh root@192.168.1.1
```

If the LuCI page is not visible after install, do a hard refresh in the browser.

## Config Templates

- [openwrt-template](https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/main/other/file/openwrt-template.json)
- [openwrt-template-tproxy](https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/main/other/file/openwrt-template-tproxy.json)
- [Sing-Box Configuration](https://sing-box.sagernet.org/configuration/)

## Contributing

Issues and pull requests are welcome.

## License

GNU General Public License v2.0 (GPL-2.0-only). See [LICENSE](./LICENSE).

## Stargazers over time

[![Stargazers over time](https://starchart.cc/ang3el7z/luci-app-singbox-ui.svg?variant=adaptive)](https://starchart.cc/ang3el7z/luci-app-singbox-ui)
