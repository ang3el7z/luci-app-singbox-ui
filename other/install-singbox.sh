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
    separator
    echo -e "${BG_ACCENT}${FG_MAIN}                Установка и настройка sing-box                ${RESET}"
    separator
}

show_progress() {
    echo -e "${INDENT}${ARROW} ${FG_ACCENT}$1${RESET}"
}

show_success() {
    echo -e "${INDENT}${CHECK} ${FG_SUCCESS}$1${RESET}\n"
}

show_error() {
    echo -e "${INDENT}${CROSS} ${FG_ERROR}$1${RESET}\n"
}

show_warning() {
    echo -e "${INDENT}! ${FG_WARNING}$1${RESET}\n"
}

header

# Обновление репозиториев и установка зависимостей
show_progress "Обновление пакетов и установка зависимостей..."
opkg update && opkg install openssh-sftp-server nano curl jq
[ $? -eq 0 ] && show_success "Зависимости успешно установлены" || show_error "Ошибка установки зависимостей"
separator

# Установка sing-box
show_progress "Установка последней версии sing-box..."
opkg install sing-box
if [ $? -eq 0 ]; then
    show_success "Sing-box успешно установлен"
else
    show_error "Ошибка установки sing-box"
    exit 1
fi

# Конфигурация сервиса
show_progress "Настройка системного сервиса..."
uci set sing-box.main.enabled="1"
uci set sing-box.main.user="root"
uci commit sing-box
show_success "Конфигурация сервиса применена"

# Отключение сервиса
service sing-box disable
show_warning "Сервис временно отключен"

# Очистка конфигурации
echo '{}' > /etc/sing-box/config.json
show_warning "Конфигурационный файл сброшен"

# Автоматическая настройка конфигурации
separator
AUTO_CONFIG_SUCCESS=0
show_progress "Импорт конфигурации sing-box"

# Создание сетевого интерфейса
configure_proxy() {
    show_progress "Создание сетевого интерфейса proxy..."
    uci set network.proxy=interface
    uci set network.proxy.proto="none"
    uci set network.proxy.device="singtun0"
    uci set network.proxy.defaultroute="0"
    uci set network.proxy.delegate="0"
    uci set network.proxy.peerdns="0"
    uci set network.proxy.auto="1"
    uci commit network
}
configure_proxy

# Настройка фаервола
configure_firewall() {
    show_progress "Конфигурация правил фаервола..."
    
    # Добавляем зону только если её не существует
    if ! uci -q get firewall.proxy >/dev/null; then
        uci add firewall zone >/dev/null
        uci set firewall.@zone[-1].name="proxy"
        uci set firewall.@zone[-1].forward="REJECT"
        uci set firewall.@zone[-1].output="ACCEPT"
        uci set firewall.@zone[-1].input="ACCEPT"
        uci set firewall.@zone[-1].masq="1"
        uci set firewall.@zone[-1].mtu_fix="1"
        uci set firewall.@zone[-1].device="singtun0"
        uci set firewall.@zone[-1].family="ipv4"
        uci add_list firewall.@zone[-1].network="singtun0"
    fi

    # Добавляем forwarding только если не существует
    if ! uci -q get firewall.@forwarding[-1].dest="proxy" >/dev/null; then
        uci add firewall forwarding >/dev/null
        uci set firewall.@forwarding[-1].dest="proxy"
        uci set firewall.@forwarding[-1].src="lan"
        uci set firewall.@forwarding[-1].family="ipv4"
    fi
    uci commit firewall >/dev/null 2>&1
    show_success "Правила фаервола применены"
}
configure_firewall

show_progress "Перезапуск firewall..."
service firewall reload >/dev/null 2>&1

show_progress "Перезапуск network..."
service network restart

show_progress "Очистка файлов..."
rm -- "$0"
show_success "Файлы удалены!"

