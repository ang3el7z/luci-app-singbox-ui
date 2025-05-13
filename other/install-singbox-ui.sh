#!/bin/sh

# Цветовая палитра (приглушенные тона)
BG_DARK='\033[48;5;236m'
BG_ACCENT='\033[48;5;24m'
FG_MAIN='\033[38;5;252m'
FG_ACCENT='\033[38;5;85m'
FG_WARNING='\033[38;5;214m'
FG_SUCCESS='\033[38;5;41m'
FG_ERROR='\033[38;5;203m'
RESET='\033[0m'

# Символы оформления
SEP_CHAR="◈"
ARROW="▸"
CHECK="✓"
CROSS="✗"
INDENT="  "

# Функция разделителя
separator() {
    echo -e "${WHITE}                -------------------------------------                ${RESET}"
}

header() {
    clear
    separator
    echo -e "${BG_ACCENT}${FG_MAIN}                Установка и настройка singbox-ui                ${RESET}"
    separator
}

show_progress() {
    echo -e "${INDENT}${ARROW} ${FG_ACCENT}$1${RESET}"
}

show_success() {
    echo -e "${INDENT}${CHECK} ${FG_SUCCESS}$1${RESET}\n"
}

header
show_progress "Начало установки singbox-ui..."
wget -O /root/luci-app-singbox-ui.ipk https://github.com/Vancltkin/singb/releases/latest/download/luci-app-singbox-ui.ipk
chmod 0755 /root/luci-app-singbox-ui.ipk
opkg update && opkg install openssh-sftp-server nano curl jq
opkg install /root/luci-app-singb.ipk
/etc/init.d/uhttpd restart
show_success "Установка завершена"
