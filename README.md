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
  singbox/
    bin/sing-box
    config.json

/usr/libexec/simo/cores/
  mihomo/core.sh
  singbox/core.sh
```

To add another core, add a new folder under both trees and implement the same
provider interface: `prepare`, `run`, `check`, `version`, `install_latest`,
`update_config`, and `cleanup`.

## Features

- MiClash-style LuCI base and Mihomo rules/dashboard assets
- Core switcher for `mihomo` and `sing-box`
- Core install/update from LuCI
- Shared `/etc/init.d/simo` service
- sing-box TUN/TPROXY mode switch
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
