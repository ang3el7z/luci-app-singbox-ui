# luci-app-singbox-ui

[Read in English](./README.md)

Веб-интерфейс для управления Sing-Box на OpenWrt 23/24/25.

## Скриншот

<img width="972" height="858" alt="Скриншот luci-app-singbox-ui" src="https://github.com/user-attachments/assets/026aca3e-ba20-479a-b8bd-3e42344f9eff" />

## Предупреждение

> **Предупреждение**  
> Этот проект предназначен **исключительно для образовательных и исследовательских целей**.  
> Автор **не несет ответственности** за распространение, неправильное использование, поломку устройств или иные последствия.  
> Вы используете проект **на свой страх и риск**. Коммерческое или вредоносное использование **не поощряется**.

## Возможности

- Запуск, остановка и перезапуск сервиса Sing-Box
- Добавление подписок по URL или вручную через JSON
- Хранение и редактирование нескольких конфигов в браузере
- Автоматическое обновление сервиса Sing-Box
- Проверка состояния сервиса и бинарника
- Автоперезапуск при нехватке памяти

## Установка

```bash
wget -O /root/install.sh https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/main/install.sh && chmod 0755 /root/install.sh && BRANCH="main" sh /root/install.sh
```

После запуска скрипта:

1. Выберите режим:
- `Singbox-ui`
- `Singbox (tproxy/tun mode)`
- `Singbox (tproxy/tun mode) + singbox-ui`
2. Выберите действие:
- `Установить`
- `Удалить`
- `Переустановить / Обновить`

## Быстрые подсказки

Очистить старый SSH-ключ:

```bash
ssh-keygen -R 192.168.1.1
```

Подключиться к роутеру:

```bash
ssh root@192.168.1.1
```

Если страница LuCI не появилась после установки, выполните жесткое обновление страницы в браузере.

## Шаблоны конфигураций

- [openwrt-template](https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/main/other/file/openwrt-template.json)
- [openwrt-template-tproxy](https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/main/other/file/openwrt-template-tproxy.json)
- [Sing-Box Configuration](https://sing-box.sagernet.org/configuration/)

## Вклад

Issue и pull request приветствуются.

## Лицензия

GNU General Public License v2.0 (GPL-2.0-only). См. [LICENSE](./LICENSE).

## Stargazers over time

[![Stargazers over time](https://starchart.cc/ang3el7z/luci-app-singbox-ui.svg?variant=adaptive)](https://starchart.cc/ang3el7z/luci-app-singbox-ui)
