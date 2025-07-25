#!/bin/sh

# Цветовая палитра / Color palette
BG_DARK='\033[48;5;236m'
BG_ACCENT='\033[48;5;24m'
FG_MAIN='\033[38;5;252m'
FG_ACCENT='\033[38;5;85m'
FG_WARNING='\033[38;5;214m'
FG_SUCCESS='\033[38;5;41m'
FG_ERROR='\033[38;5;203m'
RESET='\033[0m'

# Символы оформления / UI symbols
SEP_CHAR="◈"
ARROW="▸"
CHECK="✓"
CROSS="✗"
INDENT="  "

# Функция разделителя / Separator function
separator() {
    echo -e "${FG_MAIN}                -------------------------------------                ${RESET}"
}

header() {
    separator
    echo -e "${BG_ACCENT}${FG_MAIN}                $MSG_INSTALL_TITLE                ${RESET}"
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

# Инициализация языка / Language initialization
init_language() {
    # Если язык уже выбран (через переменную окружения), пропускаем запрос
    # If language already selected (via env var), skip prompt
    if [ -z "$LANG_CHOICE" ]; then
        echo -e "\n  ▷ Выберите язык / Select language [1/2]:"
        echo -e "  1. Русский (Russian)"
        echo -e "  2. English (Английский)"
        read -p "  ▷ Ваш выбор / Your choice [1/2]: " LANG_CHOICE
    fi

    # Установка языка по умолчанию (английский) / Default to English
    case ${LANG_CHOICE:-2} in
        1)
            # Русские тексты / Russian texts
            MSG_INSTALL_TITLE="Установка и настройка sing-box"
            MSG_UPDATE_PKGS="Обновление пакетов и установка зависимостей..."
            MSG_DEPS_SUCCESS="Зависимости успешно установлены"
            MSG_DEPS_ERROR="Ошибка установки зависимостей"
            MSG_INSTALL_SINGBOX="Установка последней версии sing-box..."
            MSG_INSTALL_SUCCESS="Sing-box успешно установлен"
            MSG_INSTALL_ERROR="Ошибка установки sing-box"
            MSG_SERVICE_CONFIG="Настройка системного сервиса..."
            MSG_SERVICE_APPLIED="Конфигурация сервиса применена"
            MSG_SERVICE_DISABLED="Сервис временно отключен"
            MSG_CONFIG_RESET="Конфигурационный файл сброшен"
            MSG_CONFIG_IMPORT="Импорт конфигурации sing-box"
            MSG_NETWORK_CONFIG="Создание сетевого интерфейса proxy..."
            MSG_FIREWALL_CONFIG="Конфигурация правил фаервола..."
            MSG_FIREWALL_APPLIED="Правила фаервола применены"
            MSG_RESTART_FIREWALL="Перезапуск firewall..."
            MSG_RESTART_NETWORK="Перезапуск network..."
            MSG_CLEANUP="Очистка файлов..."
            MSG_CLEANUP_DONE="Файлы удалены!"
            ;;
        *)
            # Английские тексты / English texts
            MSG_INSTALL_TITLE="Sing-box installation and configuration"
            MSG_UPDATE_PKGS="Updating packages and installing dependencies..."
            MSG_DEPS_SUCCESS="Dependencies installed successfully"
            MSG_DEPS_ERROR="Error installing dependencies"
            MSG_INSTALL_SINGBOX="Installing latest sing-box version..."
            MSG_INSTALL_SUCCESS="Sing-box installed successfully"
            MSG_INSTALL_ERROR="Error installing sing-box"
            MSG_SERVICE_CONFIG="Configuring system service..."
            MSG_SERVICE_APPLIED="Service configuration applied"
            MSG_SERVICE_DISABLED="Service temporarily disabled"
            MSG_CONFIG_RESET="Configuration file reset"
            MSG_CONFIG_IMPORT="Importing sing-box configuration"
            MSG_NETWORK_CONFIG="Creating proxy network interface..."
            MSG_FIREWALL_CONFIG="Configuring firewall rules..."
            MSG_FIREWALL_APPLIED="Firewall rules applied"
            MSG_RESTART_FIREWALL="Restarting firewall..."
            MSG_RESTART_NETWORK="Restarting network..."
            MSG_CLEANUP="Cleaning up files..."
            MSG_CLEANUP_DONE="Files removed!"
            ;;
    esac
}

waiting() {
    local interval="${1:-30}"
    show_progress "$(printf "$MSG_WAITING" "$interval")"
    sleep "$interval"
}

# Инициализация языка / Initialize language
init_language
header

# Обновление репозиториев и установка зависимостей
# Update repositories and install dependencies
show_progress "$MSG_UPDATE_PKGS"
opkg update && opkg install openssh-sftp-server nano curl jq
[ $? -eq 0 ] && show_success "$MSG_DEPS_SUCCESS" || show_error "$MSG_DEPS_ERROR"
separator

# Установка sing-box / Install sing-box
show_progress "$MSG_INSTALL_SINGBOX"
opkg install sing-box
if [ $? -eq 0 ]; then
    show_success "$MSG_INSTALL_SUCCESS"
else
    show_error "$MSG_INSTALL_ERROR"
    exit 1
fi

# Конфигурация сервиса / Service configuration
show_progress "$MSG_SERVICE_CONFIG"
uci set sing-box.main.enabled="1"
uci set sing-box.main.user="root"
uci commit sing-box
show_success "$MSG_SERVICE_APPLIED"

# Отключение сервиса / Disable service
service sing-box disable
show_warning "$MSG_SERVICE_DISABLED"

# Очистка конфигурации / Reset configuration
echo '{}' > /etc/sing-box/config.json
show_warning "$MSG_CONFIG_RESET"

# Автоматическая настройка конфигурации / Auto configuration
separator
AUTO_CONFIG_SUCCESS=0
show_progress "$MSG_CONFIG_IMPORT"

# Создание сетевого интерфейса / Create network interface
configure_proxy() {
    show_progress "$MSG_NETWORK_CONFIG"
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

# Настройка фаервола / Configure firewall
configure_firewall() {
    show_progress "$MSG_FIREWALL_CONFIG"
    
    # Добавляем зону только если её не существует
    # Add zone only if it doesn't exist
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
    # Add forwarding only if it doesn't exist
    if ! uci -q get firewall.@forwarding[-1].dest="proxy" >/dev/null; then
        uci add firewall forwarding >/dev/null
        uci set firewall.@forwarding[-1].dest="proxy"
        uci set firewall.@forwarding[-1].src="lan"
        uci set firewall.@forwarding[-1].family="ipv4"
    fi
    uci commit firewall >/dev/null 2>&1
    show_success "$MSG_FIREWALL_APPLIED"
}
configure_firewall

show_progress "$MSG_RESTART_FIREWALL"
service firewall reload >/dev/null 2>&1

show_progress "$MSG_RESTART_NETWORK"
service network restart

show_progress "$MSG_CLEANUP"
rm -- "$0"
show_success "$MSG_CLEANUP_DONE"
