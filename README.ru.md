# luci-app-singbox-ui
Веб-интерфейс для Sing-Box на OpenWrt 23/24

[🇬🇧 Read in English](./README.md)

**luci-app-singbox-ui** — это простая панель управления Sing-Box для OpenWRT.

> ⚠️ **Предупреждение**
>
> Данный материал предоставлен строго в **научно-исследовательских и учебных целях**.  
> Автор **не несёт ответственности** за распространение, неправильное использование, повреждение устройств или иные последствия.  
> Вы используете всё содержимое **на свой страх и риск**.  
> Автор **не поощряет** коммерческое или вредоносное использование.  
> Если вы **не согласны** с этими условиями, удалите все полученные из репозитория материалы.

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
