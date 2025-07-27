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

# Функция разделителя / Separator function
separator() {
    echo -e "${FG_MAIN}                -------------------------------------                ${RESET}"
}

# Заголовок / Header
header() {
    separator
    echo -e "${BG_ACCENT}${FG_MAIN}                $1                ${RESET}"
    separator
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
            MSG_ACTION_TITLE="Управление sing-box"
            MSG_INSTALL_TITLE="Установка и настройка sing-box"
            MSG_UNINSTALL_TITLE="Удаление sing-box"
            MSG_REINSTALL_TITLE="Переустановка sing-box"
            MSG_ACTION_PROMPT="Выберите действие:"
            MSG_ACTION_INSTALL="1. Установить (Install)"
            MSG_ACTION_UNINSTALL="2. Удалить (Uninstall)"
            MSG_ACTION_REINSTALL="3. Переустановить (Reinstall)"
            MSG_ACTION_CHOICE="Ваш выбор [1/2/3]: "
            MSG_INVALID_CHOICE="Неверный выбор"
            MSG_UPDATE_PKGS="Обновление репозиториев..."
            MSG_PKGS_SUCCESS="Репозитории успешно обновлены"
            MSG_PKGS_ERROR="Ошибка обновления репозиториев"
            MSG_INSTALL_SINGBOX="Установка последней версии sing-box..."
            MSG_INSTALL_SUCCESS="Sing-box успешно установлен"
            MSG_INSTALL_ERROR="Ошибка установки sing-box"
            MSG_ALREADY_INSTALLED="Sing-box уже установлен!"
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
            MSG_UNINSTALL_CONFIRM="Вы уверены, что хотите удалить sing-box? [y/N] "
            MSG_UNINSTALL_CANCELLED="Удаление отменено."
            MSG_NOT_INSTALLED="Sing-box не установлен!"
            MSG_UNINSTALL_SUCCESS="Sing-box успешно удален"
            MSG_REINSTALL_START="Начало переустановки..."
            MSG_NETWORK_EXISTS="Сетевой интерфейс proxy уже существует"
            MSG_FIREWALL_ZONE_EXISTS="Зона фаервола proxy уже существует"
            MSG_FIREWALL_RULE_EXISTS="Правило перенаправления уже существует"
            MSG_COMPLETE="Выполнено! (install-singbox.sh)"
            ;;
        *)
            MSG_ACTION_TITLE="Sing-box Management"
            MSG_INSTALL_TITLE="Sing-box installation and configuration"
            MSG_UNINSTALL_TITLE="Uninstall sing-box"
            MSG_REINSTALL_TITLE="Reinstall sing-box"
            MSG_ACTION_PROMPT="Select action:"
            MSG_ACTION_INSTALL="1. Install"
            MSG_ACTION_UNINSTALL="2. Uninstall"
            MSG_ACTION_REINSTALL="3. Reinstall"
            MSG_ACTION_CHOICE="Your choice [1/2/3]: "
            MSG_INVALID_CHOICE="Invalid choice"
            MSG_UPDATE_PKGS="Updating packages and installing dependencies..."
            MSG_PKGS_SUCCESS="Packages updated successfully"
            MSG_PKGS_ERROR="Error updating packages"
            MSG_INSTALL_SINGBOX="Installing latest sing-box version..."
            MSG_INSTALL_SUCCESS="Sing-box installed successfully"
            MSG_INSTALL_ERROR="Error installing sing-box"
            MSG_ALREADY_INSTALLED="Sing-box is already installed!"
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
            MSG_UNINSTALL_CONFIRM="Are you sure you want to uninstall sing-box? [y/N] "
            MSG_UNINSTALL_CANCELLED="Uninstall cancelled."
            MSG_NOT_INSTALLED="Sing-box is not installed!"
            MSG_UNINSTALL_SUCCESS="Sing-box successfully removed"
            MSG_REINSTALL_START="Starting reinstallation..."
            MSG_NETWORK_EXISTS="Network interface proxy already exists"
            MSG_FIREWALL_ZONE_EXISTS="Firewall zone proxy already exists"
            MSG_FIREWALL_RULE_EXISTS="Forwarding rule already exists"
            MSG_SCRIPT_COMPLETE="Done! (install-singbox.sh)"
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
        separator
    else
        show_error "$MSG_PKGS_ERROR"
        separator
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

# Удаление настроек фаервола / Remove firewall settings
remove_firewall_settings() {
    # Удаление зон / Remove zones
    local zone_ids=$(uci show firewall | grep -E "firewall\.@zone\[[0-9]+\]\.name='?proxy'?" | cut -d'=' -f1 | awk -F. '{print $2}')
    for zone_id in $zone_ids; do
        uci delete firewall.$zone_id
    done

    # Удаление правил / Remove forwarding rules
    local forward_ids=$(uci show firewall | grep -E "firewall\.@forwarding\[[0-9]+\]\.dest='?proxy'?" | cut -d'=' -f1 | awk -F. '{print $2}')
    for forward_id in $forward_ids; do
        uci delete firewall.$forward_id
    done

    uci commit firewall >/dev/null 2>&1
}

# Настройка сети / Network configuration
configure_proxy() {
    if ! uci -q get network.proxy >/dev/null; then
        show_progress "$MSG_NETWORK_CONFIG"
        uci set network.proxy=interface
        uci set network.proxy.proto="none"
        uci set network.proxy.device="singtun0"
        uci set network.proxy.defaultroute="0"
        uci set network.proxy.delegate="0"
        uci set network.proxy.peerdns="0"
        uci set network.proxy.auto="1"
        uci commit network
    else
        show_error "$MSG_NETWORK_EXISTS"
    fi
}

# Настройка фаервола / Firewall configuration
configure_firewall() {
    # Проверка зоны / Check zone
    if ! uci show firewall | grep -qE "firewall\.@zone\[[0-9]+\]\.name='?proxy'?"; then
        show_progress "$MSG_FIREWALL_CONFIG"
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
    else
        show_error "$MSG_FIREWALL_ZONE_EXISTS"
    fi

    # Проверка правил / Check forwarding rules
    if ! uci show firewall | grep -qE "firewall\.@forwarding\[[0-9]+\]\.dest='?proxy'?"; then
        uci add firewall forwarding >/dev/null
        uci set firewall.@forwarding[-1].dest="proxy"
        uci set firewall.@forwarding[-1].src="lan"
        uci set firewall.@forwarding[-1].family="ipv4"
    else
        show_error "$MSG_FIREWALL_RULE_EXISTS"
    fi
    
    uci commit firewall >/dev/null 2>&1
    show_success "$MSG_FIREWALL_APPLIED"
}

# Функция установки / Install function
do_install() {
    header "$MSG_INSTALL_TITLE"
    
    # Проверка установки / Check installation
    if opkg list-installed | grep -q "sing-box"; then
        show_success "$MSG_ALREADY_INSTALLED"
        return 1
    fi

    update_pkgs

    # Установка / Installation
    show_progress "$MSG_INSTALL_SINGBOX"
    opkg install sing-box
    if [ $? -ne 0 ]; then
        show_error "$MSG_INSTALL_ERROR"
        return 1
    fi
    show_success "$MSG_INSTALL_SUCCESS"

    # Конфигурация сервиса / Service configuration
    show_progress "$MSG_SERVICE_CONFIG"
    uci set sing-box.main.enabled="1"
    uci set sing-box.main.user="root"
    uci commit sing-box
    show_success "$MSG_SERVICE_APPLIED"

    # Временное отключение / Temporary disable
    service sing-box disable
    show_success "$MSG_SERVICE_DISABLED"

    # Сброс конфигурации / Reset config
    echo '{}' > /etc/sing-box/config.json
    show_success "$MSG_CONFIG_RESET"

    # Настройка сети и фаервола / Network and firewall setup
    configure_proxy
    configure_firewall

    # Перезапуск служб / Restart services
    show_progress "$MSG_RESTART_FIREWALL"
    service firewall reload >/dev/null 2>&1

    show_progress "$MSG_RESTART_NETWORK"
    service network restart
}

# Функция удаления / Uninstall function
do_uninstall() {
    header "$MSG_UNINSTALL_TITLE"
    
    # Подтверждение / Confirmation
    read_input "$MSG_UNINSTALL_CONFIRM" confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        show_message "$MSG_UNINSTALL_CANCELLED"
        return 1
    fi

    # Проверка установки / Check installation
    if ! opkg list-installed | grep -q "sing-box"; then
        show_error "$MSG_NOT_INSTALLED"
        return 1
    fi

    # Остановка и отключение сервиса / Stop and disable service
    [ -f "/etc/init.d/sing-box" ] && {
        /etc/init.d/sing-box stop
        /etc/init.d/sing-box disable
    }

    # Удаление пакета / Remove package
    opkg remove sing-box
    show_success "$MSG_UNINSTALL_SUCCESS"

    # Удаление конфигов / Remove configs
    uci -q delete sing-box.main
    uci commit sing-box
    rm -f /etc/sing-box/config.json

    # Удаление сетевых настроек / Remove network settings
    uci -q delete network.proxy
    uci commit network

    # Удаление фаервола / Remove firewall settings
    remove_firewall_settings

    # Перезапуск служб / Restart services
    show_progress "$MSG_RESTART_FIREWALL"
    service firewall reload >/dev/null 2>&1

    show_progress "$MSG_RESTART_NETWORK"
    service network restart
}

# Функция переустановки / Reinstall function
do_reinstall() {
    header "$MSG_REINSTALL_TITLE"
    show_progress "$MSG_REINSTALL_START"
    do_uninstall && do_install
}

# Выбор действия / Action selection
action_choice_install() {
    if [ -z "$ACTION_CHOICE" ]; then
        show_message "$MSG_ACTION_PROMPT"
        show_message "$MSG_ACTION_INSTALL"
        show_message "$MSG_ACTION_UNINSTALL"
        show_message "$MSG_ACTION_REINSTALL"
        read_input "$MSG_ACTION_CHOICE" ACTION_CHOICE
    fi
    
    case $ACTION_CHOICE in
        1) do_install ;;
        2) do_uninstall ;;
        3) do_reinstall ;;
        *) 
            show_error "$MSG_INVALID_CHOICE"
            exit 1
            ;;
esac
}

# Очистка / Cleanup
cleanup() {
    show_progress "$MSG_CLEANUP"
    rm -- "$0"
    show_success "$MSG_CLEANUP_DONE"
    exit 1
}

# Завершение скрипта / Complete script
complete_script() {
    show_success "$MSG_COMPLETE"
    cleanup
}

# ======== Основной код / Main code ========

init_language
header "$MSG_ACTION_TITLE"
action_choice_install
network_check
complete_script
