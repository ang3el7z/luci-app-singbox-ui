# 🌐 luci-app-singbox-ui

[Read in English](./README.md)

Веб-интерфейс для Sing-Box под **OpenWrt 23/24 и 25**

**luci-app-singbox-ui** — это простой персональный веб-интерфейс для управления сервисом **Sing-Box** на OpenWRT.

> ⚠️ **Предупреждение**  
> Этот материал предоставлен **исключительно в образовательных и исследовательских целях**.  
> Автор **не несёт ответственности** за распространение, неправильное использование, поломку устройств или иные последствия.  
> Вы используете всё содержимое **на свой страх и риск**.  
> Коммерческое или вредоносное использование **не поощряется**.

---

## 📸 Screenshots

<img width="972" height="858" alt="chrome_T3g08LVqwe" src="https://github.com/user-attachments/assets/026aca3e-ba20-479a-b8bd-3e42344f9eff" />

---

## ✨ Возможности

- ✅ Старт / Стоп / Перезапуск сервиса Sing-Box
- 🔧 Добавление подписок через URL или вручную (JSON)
- 💾 Хранение и редактирование нескольких конфигураций в браузере
- ♻️ Автоматическое обновление сервиса
- 🔍 Проверка состояния сервиса и бинарника
- 🧠 Перезапуск при нехватке памяти

---

## ⚙️ Установка

### 1. Запустите установочный скрипт:
```bash
wget -O /root/install.sh https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/main/install.sh && chmod 0755 /root/install.sh && BRANCH="main" sh /root/install.sh
```

### 2. Выберите режим:
- `Singbox-ui`
- `Singbox (tproxy/tun mode)`
- `Singbox (tproxy/tun mode) + singbox-ui`

### 3. Выберите операцию:
- Установка
- Удаление
- Переустановка / Обновление

---

## 🧩 Подсказки для пользователей

### 🔑 Очистка SSH-ключа:
```bash 
ssh-keygen -R 192.168.1.1 
```

### 🛜 Подключение к роутеру:
```bash
ssh root@192.168.1.1
```

### 🔄 Обновление OpenWrt-интерфейса (если плагин не виден, нужно сбросить кэш):
`Ctrl + Shift + I`

Или нажмите F12, чтобы открыть DevTools, затем кликните правой кнопкой на кнопку «Обновить» и выберите «Жёсткая перезагрузка».

### 🗂️ Шаблоны конфигураций

- [`openwrt-template`](https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/main/other/file/openwrt-template.json)
- [`openwrt-template-tproxy`](https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/main/other/file/openwrt-template-tproxy.json)
> Изучайте официальную документацию и статьи по ссылке: [`Sing-Box Configuration`](https://sing-box.sagernet.org/configuration/)

### 🛠️ Исправления

- [`Исправление низкой скорости в tun-режиме`](https://github.com/ang3el7z/luci-app-singbox-ui/issues/1)
- `установите tun в конфиге -> singtun0`

---

## 🙏 Благодарности

Вы также можете создать Pull Request или Issue. И не забудьте нажать на значок звезды ⭐, чтобы поддержать проект.

---

## Stargazers over time

[![Stargazers over time](https://starchart.cc/ang3el7z/luci-app-singbox-ui.svg?variant=adaptive)](https://starchart.cc/ang3el7z/luci-app-singbox-ui)
