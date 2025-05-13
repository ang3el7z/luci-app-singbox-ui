# luci-app-singbox-ui
Веб-интерфейс для Sing-Box на OpenWRT

[🇬🇧 Read in English](./README.md)

**luci-app-singbox-ui** — это простая панель управления Sing-Box для OpenWRT.

## Возможности
- Управление сервисом Sing-Box (запуск/остановка/перезапуск)
- Добавление подписок через URL или вручную (JSON)
- Хранение и редактирование нескольких конфигов
- Включение автообновления конфигурации по ссылке

# Установка

## Установить singbox+singbox-ui
wget -O /root/install-singbox+singbox-ui.sh https://raw.githubusercontent.com/Vancltkin/luci-app-singbox-ui/main/other/install-singbox+singbox-ui.sh && chmod 0755 /root/install-singbox+singbox-ui.sh && sh /root/install-singbox+singbox-ui.sh

## Установить singbox-ui
wget -O /root/install-singbox-ui.sh https://raw.githubusercontent.com/Vancltkin/luci-app-singbox-ui/main/other/install-singbox-ui.sh && chmod 0755 /root/install-singbox-ui.sh && sh /root/install-singbox-ui.sh

## Установить singbox
wget -O /root/install-singbox.sh https://raw.githubusercontent.com/Vancltkin/luci-app-singbox-ui/main/other/install-singbox.sh && chmod 0755 /root/install.sh && sh /root/install-singbox.sh

# Скриншот

![image](https://github.com/user-attachments/assets/aae527ac-74c7-4359-8807-62fbe6826df0)
![image](https://github.com/user-attachments/assets/64757656-c961-4daa-9fab-0fed6fb32cc3)
![image](https://github.com/user-attachments/assets/74739f36-c734-4787-afb0-1cc70b07bf7d)

# Дополнительно
 - Connect router -> ssh root@192.168.1.1
 - REFRESH OPENWRT (Fix visibility plugin) -> CNTRL + SHIFT + I
