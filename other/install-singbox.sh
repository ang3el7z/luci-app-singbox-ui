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
FG_USER_COLOR='\033[38;5;117m'

# Символы оформления / UI symbols
SEP_CHAR="◈"
ARROW="▸"
ARROW_CLEAR=">"
CHECK="✓"
CROSS="✗"
INDENT="  "

# Заголовок / Header
header() {
    echo -e "${BG_ACCENT}${FG_MAIN}                $1                ${RESET}"
}

# Прогресс / Progress
show_progress() {
    echo -e "${INDENT}${ARROW} ${FG_ACCENT}$1${RESET}"
}

# Успех / Success
show_success() {
    echo -e "${INDENT}${CHECK} ${FG_SUCCESS}$1${RESET}\n"
}

# Ошибка / Error
show_error() {
    echo -e "${INDENT}${CROSS} ${FG_ERROR}$1${RESET}\n"
}

# Сообщение / Message
show_message() {
    echo -e "${FG_USER_COLOR}${INDENT}${ARROW} $1${RESET}"
}

# Ввод / Input
read_input() {
    echo -ne "${FG_USER_COLOR}${INDENT}${ARROW_CLEAR} $1${RESET} "
    if [ -n "$2" ]; then
        read -r "$2" 
    else
        read -r REPLY 
    fi
}

# Инициализация языка / Language initialization
init_language() {
    if [ -z "$LANG_CHOICE" ]; then
        show_message "Выберите язык / Select language [1/2]:"
        show_message "1. Русский (Russian)"
        show_message "2. English (Английский)"
        read_input " Ваш выбор / Your choice [1/2]: " LANG_CHOICE
    fi

    case ${LANG_CHOICE:-2} in
        1)
            MSG_INSTALL_TITLE="Установка и настройка sing-box"
            MSG_UPDATE_PKGS="Обновление репозиториев..."
            MSG_PKGS_SUCCESS="Репозитории успешно обновлены"
            MSG_PKGS_ERROR="Ошибка обновления репозиториев"
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
            MSG_WAITING="Ожидание %d сек"
            MSG_COMPLETE="Выполнено! (install-singbox.sh)"
            ;;
        *)
            MSG_INSTALL_TITLE="Sing-box installation and configuration"
            MSG_UPDATE_PKGS="Updating packages and installing dependencies..."
            MSG_PKGS_SUCCESS="Packages updated successfully"
            MSG_PKGS_ERROR="Error updating packages"
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
            MSG_WAITING="Waiting %d sec"
            MSG_COMPLETE="Done! (install-singbox.sh)"
            ;;
    esac
}

# Ожидание / Waiting
waiting() {
    local interval="${1:-30}"
    show_progress "$(printf "$MSG_WAITING" "$interval")"
    sleep "$interval"
}

# Обновление репозиториев / Update repos
update_pkgs() {
    show_progress "$MSG_UPDATE_PKGS"
    opkg update
    if [ $? -eq 0 ]; then
        show_success "$MSG_PKGS_SUCCESS"
    else
        show_error "$MSG_PKGS_ERROR"
        exit 1
    fi
}

# Проверка доступности сети / Network availability check
network_check() {
    timeout=200
    interval=5
    targets="223.5.5.5 180.76.76.76 77.88.8.8 1.1.1.1 8.8.8.8 9.9.9.9 94.140.14.14"

    attempts=$((timeout / interval))
    success=0
    i=1

    show_progress "$MSG_NETWORK_CHECK"

    sleep $interval

    while [ $i -lt $attempts ]; do
        num_targets=$(echo "$targets" | wc -w)
        index=$((i % num_targets))
        target=$(echo "$targets" | cut -d' ' -f$((index + 1)))

        if ping -c 1 -W 2 "$target" >/dev/null 2>&1; then
            success=1
            break
        fi
        
        i=$((i + 1))
    done

    if [ $success -eq 1 ]; then
        total_time=$((i * interval))
        show_success "$(printf "$MSG_NETWORK_SUCCESS" "$target" "$total_time")"
    else
        show_error "$(printf "$MSG_NETWORK_ERROR" "$timeout")" >&2
        exit 1
    fi
}

install_singbox() {
    show_progress "$MSG_INSTALL_SINGBOX"
    opkg install sing-box
    if [ $? -eq 0 ]; then
        show_success "$MSG_INSTALL_SUCCESS"
    else
        show_error "$MSG_INSTALL_ERROR"
        exit 1
    fi
}

# Конфигурация сервиса / Service configuration
configure_singbox_service() {
    show_progress "$MSG_SERVICE_CONFIG"
    uci set sing-box.main.enabled="1"
    uci set sing-box.main.user="root"
    uci commit sing-box
    show_success "$MSG_SERVICE_APPLIED"
}

# Отключение сервиса / Disable service
disable_singbox_service() {
    show_progress "$MSG_SERVICE_DISABLED"
    service sing-box disable
    show_success "$MSG_SERVICE_DISABLED"
}

# Очистка конфигурации / Reset configuration
clean_singbox_config() {
    show_progress "$MSG_CONFIG_RESET"
    echo '{}' > /etc/sing-box/config.json
    show_success "$MSG_CONFIG_RESET"
}

# Отключение IPv6 / Disable IPv6
disabled_ipv6() {
    show_progress "$MSG_DISABLE_IPV6"
    uci set 'network.lan.ipv6=0'
    uci set 'network.wan.ipv6=0'
    uci set 'dhcp.lan.dhcpv6=disabled'
    /etc/init.d/odhcpd disable
    uci commit
    show_success "$MSG_IPV6_DISABLED"
}

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

# Настройка фаервола / Configure firewall
configure_firewall() {
    show_progress "$MSG_FIREWALL_CONFIG"
    
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

    if ! uci -q get firewall.@forwarding[-1].dest="proxy" >/dev/null; then
        uci add firewall forwarding >/dev/null
        uci set firewall.@forwarding[-1].dest="proxy"
        uci set firewall.@forwarding[-1].src="lan"
        uci set firewall.@forwarding[-1].family="ipv4"
    fi
    uci commit firewall >/dev/null 2>&1
    show_success "$MSG_FIREWALL_APPLIED"
}

# Перезагрузка firewall / Restart firewall
restart_firewall() {
    show_progress "$MSG_RESTART_FIREWALL"
    service firewall reload >/dev/null 2>&1
}

# Перезагрузка network / Restart network
restart_network() {
    show_progress "$MSG_RESTART_NETWORK"
    service network restart
}

# Включение sing-box / Enable sing-box
enable_singbox() {
    show_progress "$MSG_START_SERVICE"
    service sing-box enable
    service sing-box start
    show_success "$MSG_SERVICE_STARTED"
}

cleanup() {
    show_progress "$MSG_CLEANUP"
    rm -- "$0"
    show_success "$MSG_CLEANUP_DONE"
}

complete_script() {
    show_success "$MSG_COMPLETE"
    cleanup
}

# ======== Основной код / Main code ========

init_language
header "$MSG_INSTALL_TITLE"
update_pkgs
install_singbox
configure_singbox_service
disable_singbox_service
clean_singbox_config
disabled_ipv6
configure_proxy
configure_firewall
restart_firewall
restart_network
network_check
enable_singbox
complete_script
