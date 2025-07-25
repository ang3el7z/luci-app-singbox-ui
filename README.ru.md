# luci-app-singbox-ui

[🇬🇧 Read in English](./README.md)

Веб-интерфейс для Sing-Box на OpenWrt 23/24

**luci-app-singbox-ui** — это простой персональный веб-интерфейс для управления сервисом Sing-Box на OpenWRT.

> ⚠️ **Предупреждение**
>
> Данный материал предоставлен строго в **научно-исследовательских и учебных целях**.  
> Автор **не несёт ответственности** за распространение, неправильное использование, повреждение устройств или иные последствия.  
> Вы используете всё содержимое **на свой страх и риск**.  
> Автор **не поощряет** коммерческое или вредоносное использование.  
> Если вы **не согласны** с этими условиями, удалите все полученные из репозитория материалы.

# [Скриншоты](./preview.md)

## Возможности
- Управление сервисом Sing-Box (старт/стоп/перезапуск)
- Добавление подписок через URL или вставка JSON вручную
- Хранение и редактирование нескольких конфигураций в браузере
- Автоматическое обновление сервиса
- Автоматическая проверка состояния сервиса и Sing-Box
- Перезапуск Sing-Box при нехватке памяти

# Установка

## Установить singbox (tun режим) + singbox-ui
```shell
wget -O /root/install-singbox+singbox-ui.sh https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/main/other/install-singbox+singbox-ui.sh && chmod 0755 /root/install-singbox+singbox-ui.sh && sh /root/install-singbox+singbox-ui.sh
```

## Установить singbox-ui
```shell
wget -O /root/install-singbox-ui.sh https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/main/other/install-singbox-ui.sh && chmod 0755 /root/install-singbox-ui.sh && sh /root/install-singbox-ui.sh
```

## Установить singbox (tun режим)
```shell
wget -O /root/install-singbox.sh https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/main/other/install-singbox.sh && chmod 0755 /root/install-singbox.sh && sh /root/install-singbox.sh
```

# Дополнительно
 - очистить ssh keygen 
```shell
ssh-keygen -R 192.168.1.1
```
 - подключение к роутеру
```shell
ssh root@192.168.1.1
```
 - обновить openwrt (исправления видиммости плагина) -> `Cntrl + Shift + I`
 - [`openwrt template original 2.11`](https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/main/other/file/openwrt-template-original-openwrt_2.11.json)
 - [`openwrt template bot 2.11`](https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/main/other/file/openwrt-template-bot-openwrt_2.11.json)
 - [`исправление низкой скорости в "tun режиме"`](https://github.com/ang3el7z/luci-app-singbox-ui/issues/1)
 - установить в одно нажатие
```shell
hash -r && rm -f ./install-one-click.sh && wget -O install-one-click.sh https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/main/other/install-one-click.sh && chmod +x install-one-click.sh && ./install-one-click.sh
```

# Спасибо
[@strayge](https://github.com/strayge)
