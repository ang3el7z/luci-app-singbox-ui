# luci-app-singbox-ui

[Читать на русском](./README.ru.md)

Web interface for managing Sing-Box on OpenWrt 23/24/25.

## Disclaimer

This project is for educational and research use.
Use at your own risk. The author is not responsible for misuse or damage.

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
