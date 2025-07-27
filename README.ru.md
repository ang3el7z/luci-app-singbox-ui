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

1. Запустите скрипт
```shell
wget -O /root/install.sh https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/main/install.sh && chmod 0755 /root/install.sh && sh /root/install.sh
```

2. Выберите действие:
    - Установка singbox-ui
    - Установка singbox (tun mode)
    - Установка singbox (tun mode) + singbox-ui

# Подсказки для пользователей
очистить ssh keygen 
```shell
ssh-keygen -R 192.168.1.1
```

подключение к роутеру
```shell
ssh root@192.168.1.1
```

обновить openwrt (исправления видиммости плагина) -> `Cntrl + Shift + I`

Шаблоны
 - [`openwrt template original 2.11`](https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/main/other/file/openwrt-template-original-openwrt_2.11.json)
 - [`openwrt template bot 2.11`](https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/main/other/file/openwrt-template-bot-openwrt_2.11.json)

Исправления
 - [`исправление низкой скорости в "tun режиме"`](https://github.com/ang3el7z/luci-app-singbox-ui/issues/1)

# Подсказки для меня
 - установить в одно нажатие
```shell
wget -O install-one-click.sh https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/main/other/install-one-click.sh && chmod +x install-one-click.sh && ./install-one-click.sh
```

# Спасибо
[@strayge](https://github.com/strayge)
