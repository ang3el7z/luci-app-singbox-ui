# Simo

Simo is a LuCI proxy manager for OpenWrt with pluggable cores.

The project is based on the MiClash architecture and adds a provider layer so
Mihomo and sing-box live side by side:

```text
/opt/simo/cores/
  mihomo/
    bin/mihomo
    bin/mihomo-rules
    config.yaml
    config2.yaml
    config3.yaml
    url_config.yaml
  singbox/
    bin/sing-box
    bin/singbox-rules
    config.json
    config2.json
    config3.json
    url_config.json

/usr/libexec/simo/cores/
  mihomo/core.sh
  singbox/core.sh

/usr/libexec/simo/net/
  openwrt.sh
```

To add another core, add a new folder under both trees and implement the same
provider interface: `prepare`, `run`, `check`, `version`, `install_latest`,
`update_config`, `url`, `netenv`, `rules`, and `cleanup`.

OpenWrt-specific TUN, TPROXY, firewall, policy-routing and guard work is shared
through `simo-net`; providers only publish their network parameters through
`netenv`.

LuCI has a single Simo entrypoint at `view/simo/simo.js`. Buttons are shared;
provider-specific work is routed through the active core provider.

## Features

- Single Simo LuCI page for service, engine, network mode and config control
- Core switcher for `mihomo` and `sing-box`
- Core install/update from LuCI
- Shared `/etc/init.d/simo` service
- Shared TUN/TPROXY/Mixed mode controls
- Shared DNS/TUN settings with provider adapters for Mihomo YAML and sing-box JSON
- Config autoupdater service
- Health autoupdater service
- Low-memory restart service
- No external install scripts

## Installation

Download the package from the latest release and install it with your OpenWrt
package manager.

OpenWrt 23/24:
```bash
opkg update
wget -O /tmp/luci-app-simo.ipk https://github.com/ang3el7z/luci-app-simo/releases/latest/download/luci-app-simo.ipk
opkg install /tmp/luci-app-simo.ipk
```

OpenWrt 25:
```bash
wget -O /tmp/luci-app-simo.apk https://github.com/ang3el7z/luci-app-simo/releases/latest/download/luci-app-simo.apk
apk add --allow-untrusted /tmp/luci-app-simo.apk
```

After package installation, open LuCI and install the desired core from Simo.
