# 🌐 luci-app-singbox-ui

[Читать на русском](./README.ru.md)

Web interface for Sing-Box on **OpenWrt 23/24**

**luci-app-singbox-ui** is a simple personal web interface to manage the **Sing-Box** service on OpenWRT.

> ⚠️ **Disclaimer**  
> This project is intended **strictly for educational and research purposes**.  
> The author **takes no responsibility** for misuse, damage to devices, or any consequences of use.  
> You use everything at **your own risk**. Commercial or malicious use is **not encouraged**.

---

## 📸 [Screenshots](./preview.md)

---

## ✨ Features

- ✅ Start / Stop / Restart the Sing-Box service
- 🔧 Add subscriptions via URL or manually paste JSON
- 💾 Store and edit multiple configs in your browser
- ♻️ Auto-update Sing-Box service
- 🔍 Auto-check service & binary status
- 🧠 Auto-restart when memory is low

---

## ⚙️ Installation

### 1. Run installation script:
```bash
wget -O /root/install.sh https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/main/install.sh && chmod 0755 /root/install.sh && BRANCH="main" sh /root/install.sh
```

### 2. Select mode:
- `Singbox-ui`
- `Singbox (tun mode)`
- `Singbox (tun mode) + singbox-ui`

### 3. Choose operation:
- Install
- Uninstall
- Reinstall / Update

---

## 🧩 User Tips

### 🔑 Clear SSH key:
```bash
ssh-keygen -R 192.168.1.1
```

### 🛜 Connect to router:
```bash
ssh root@192.168.1.1
```

### 🔄 Refresh OpenWrt UI (if plugin not visible, need clear cache):
`Ctrl + Shift + I` (DevTools → refresh)

Press F12 to open DevTools, then right-click the “Reload” button and select “Hard Reload”.

### 🗂️ Config Templates

- [`openwrt-template-original-2.11`](https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/main/other/file/openwrt-template-original-openwrt_2.11.json)  
- [`openwrt-template-bot-2.11`](https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/main/other/file/openwrt-template-bot-openwrt_2.11.json)

### 🛠️ Fixes

- [`Fix low speed in tun mode`](https://github.com/ang3el7z/luci-app-singbox-ui/issues/1)
- `set tun in config -> singtun0`

---

## 🙏 Credits

You can also create a Pull Request or Issue. And don’t forget to click the star ⭐ icon to support the project.

---

## Stargazers over time

[![Stargazers over time](https://starchart.cc/ang3el7z/luci-app-singbox-ui.svg?variant=adaptive)](https://starchart.cc/ang3el7z/luci-app-singbox-ui)
