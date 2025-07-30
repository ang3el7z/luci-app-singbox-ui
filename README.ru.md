# 🌐 luci-app-singbox-ui

[🇬🇧 Read in English](./README.md)

Веб-интерфейс для Sing-Box под **OpenWrt 23/24**

**luci-app-singbox-ui** — это простой персональный веб-интерфейс для управления сервисом **Sing-Box** на OpenWRT.

> ⚠️ **Предупреждение**  
> Этот материал предоставлен **исключительно в образовательных и исследовательских целях**.  
> Автор **не несёт ответственности** за распространение, неправильное использование, поломку устройств или иные последствия.  
> Вы используете всё содержимое **на свой страх и риск**.  
> Коммерческое или вредоносное использование **не поощряется**.

---

## 📸 [Скриншоты](./preview.md)

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
- `Singbox (tun режим)`
- `Singbox (tun режим) + singbox-ui`

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

### 🔄 Обновление OpenWrt-интерфейса (если плагин не виден):
`Ctrl + Shift + I` (Откройте DevTools → обновите)

---

## 🗂️ Шаблоны конфигураций

- [`openwrt-template-original-2.11`](https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/main/other/file/openwrt-template-original-openwrt_2.11.json)  
- [`openwrt-template-bot-2.11`](https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/main/other/file/openwrt-template-bot-openwrt_2.11.json)

---

## 🛠️ Исправления

- [`Исправление низкой скорости в tun-режиме`](https://github.com/ang3el7z/luci-app-singbox-ui/issues/1)

---

## 👨‍💻 Подсказки для разработчика

### Установка в одно нажатие:
```bash
wget -O install-one-click.sh https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/main/other/install-one-click.sh && chmod +x install-one-click.sh && ./install-one-click.sh
```

---

## 🙏 Благодарности

Особая благодарность [@strayge](https://github.com/strayge) за вклад.
