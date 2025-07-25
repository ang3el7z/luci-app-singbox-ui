# luci-app-singbox-ui
Веб-интерфейс для Sing-Box на OpenWrt 23/24

[🇬🇧 Read in English](./README.md)

**luci-app-singbox-ui** — это простая панель управления Sing-Box для OpenWRT.

> ⚠️ **Warning**
>
> This material is provided strictly for **educational and research purposes only**.  
> The author **is not responsible** for any distribution, misuse, damage to devices, or violations caused by using this software.  
> You use all provided content **at your own risk**.  
> The author **does not encourage** any commercial or malicious use.  
> If you do not agree with these terms, **delete all files** obtained from this repository.

## Возможности
- Управление сервисом Sing-Box (запуск/остановка/перезапуск)
- Добавление подписок через URL или вручную (JSON)
- Хранение и редактирование нескольких конфигов
- Сервис автоматического обновления
- Сервис поддержка здоровья автообновления и sing-box
- Сервис низкой памяти (перезапуск sing-box)


# Установка

## Установить singbox (tun mode) + singbox-ui
```shell
wget -O /root/install-singbox+singbox-ui.sh https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/main/other/install-singbox+singbox-ui.sh && chmod 0755 /root/install-singbox+singbox-ui.sh && sh /root/install-singbox+singbox-ui.sh
```

## Установить singbox-ui
```shell
wget -O /root/install-singbox-ui.sh https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/main/other/install-singbox-ui.sh && chmod 0755 /root/install-singbox-ui.sh && sh /root/install-singbox-ui.sh
```

## Установить singbox (tun mode)
```shell
wget -O /root/install-singbox.sh https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/main/other/install-singbox.sh && chmod 0755 /root/install-singbox.sh && sh /root/install-singbox.sh
```

# [Скриншот](./preview.md)

# Дополнительно
 - ssh-keygen -R 192.168.1.1
 - Подключение к роутеру -> ssh root@192.168.1.1
 - Обновить OPENWRT (Fix visibility plugin) -> CNTRL + SHIFT + I
 - [openwrt-template-original-openwrt_2.11.json](https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/main/other/file/openwrt-template-original-openwrt_2.11.json)
 - [openwrt-template-bot-openwrt_2.11.json](https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/main/other/file/openwrt-template-bot-openwrt_2.11.json)
 - ["tun" interface выдает низкую скорость](https://github.com/ang3el7z/luci-app-singbox-ui/issues/1)
 - лайт версия Singbox-ui v1.2.1

# Спасибо
[@strayge](https://github.com/strayge)
