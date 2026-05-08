# Simo

Simo - LuCI-менеджер прокси для OpenWrt с подключаемыми ядрами.

Проект строится на подходе MiClash, но ядра вынесены в простую provider-архитектуру:

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
```

Чтобы добавить новое ядро, нужно добавить соседнюю папку и реализовать тот же
интерфейс: `prepare`, `run`, `check`, `version`, `install_latest`,
`update_config`, `url`, `rules`, `cleanup`.

## Возможности

- база UI и логика Mihomo из MiClash;
- переключение активного ядра: `mihomo` или `sing-box`;
- установка и обновление ядра из LuCI;
- общий сервис `/etc/init.d/simo`;
- TUN/TPROXY для sing-box;
- autoupdate service;
- health service;
- memory restart service;
- без внешних install scripts.

## Установка

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

После установки пакета откройте LuCI и установите нужное ядро из Simo.
