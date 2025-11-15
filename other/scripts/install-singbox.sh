#!/bin/sh

# Цветовая палитра / Color palette
FG_ACCENT='\033[38;5;85m'
FG_SUCCESS='\033[38;5;41m'
FG_ERROR='\033[38;5;203m'
RESET='\033[0m'
FG_USER_COLOR='\033[38;5;117m'

# Символы оформления / UI symbols
SEP_CHAR="-"
ARROW="▸"
ARROW_CLEAR=">"
CHECK="✓"
CROSS="✗"
INDENT="  "

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

# Разделитель / Separator
separator() {
    local text="$1"

    get_terminal_width() {
        local w
        w=$(tput cols 2>/dev/null)
        if [ -n "$w" ]; then
            echo "$w"
            return
        fi
        if [ -n "$COLUMNS" ]; then
            echo "$COLUMNS"
            return
        fi
        w=$(stty size 2>/dev/null | awk '{print $2}')
        if [ -n "$w" ]; then
            echo "$w"
            return
        fi
        echo 100
    }

    local width
    width=$(get_terminal_width)

    SEP_CHAR=${SEP_CHAR:-"o"}
    FG_ACCENT=${FG_ACCENT:-"\033[38;5;85m"}
    RESET=${RESET:-"\033[0m"}

    if [ -z "$text" ]; then
        local line=$(printf "%${width}s" " " | tr ' ' "${SEP_CHAR}")
        echo -e "${FG_ACCENT}${line}${RESET}"
        return
    fi

    local clean_text
    clean_text=$(echo -n "$text" | sed 's/\x1b\[[0-9;]*m//g')

    local text_area=$((width / 2))
    local side_width=$((width / 4))

    if [ ${#clean_text} -le "$text_area" ]; then
        local padding_needed=$((text_area - ${#clean_text}))
        local left_padding=$((padding_needed / 2))
        local right_padding=$((padding_needed - left_padding))

        local side_part=$(printf "%${side_width}s" " " | tr ' ' "${SEP_CHAR}")
        local left_text_pad=$(printf "%${left_padding}s" " ")
        local right_text_pad=$(printf "%${right_padding}s" " ")

        echo -e "${FG_ACCENT}${side_part}${RESET}${left_text_pad}${text}${right_text_pad}${FG_ACCENT}${side_part}${RESET}"
    else
        local remaining_text="$clean_text"
        local side_part=$(printf "%${side_width}s" " " | tr ' ' "${SEP_CHAR}")

        while [ ${#remaining_text} -gt 0 ]; do
            local line_text=""
            local line_length=0

            if [ ${#remaining_text} -le "$text_area" ]; then
                line_text="$remaining_text"
                line_length=${#remaining_text}
                remaining_text=""
            else
                local cut_pos="$text_area"
                local i=$((text_area - 1))
                while [ $i -gt $((text_area / 2)) ]; do
                    local char=$(echo "$remaining_text" | cut -c$i)
                    if [ "$char" = " " ]; then
                        cut_pos=$i
                        break
                    fi
                    i=$((i - 1))
                done

                line_text=$(echo "$remaining_text" | cut -c1-$cut_pos)
                line_length=${#line_text}
                remaining_text=$(echo "$remaining_text" | cut -c$((cut_pos + 1))-)
                remaining_text=$(echo "$remaining_text" | sed 's/^[[:space:]]*//')
            fi

            local padding_needed=$((text_area - line_length))
            local left_padding=$((padding_needed / 2))
            local right_padding=$((padding_needed - left_padding))

            local left_text_pad=$(printf "%${left_padding}s" " ")
            local right_text_pad=$(printf "%${right_padding}s" " ")

            echo -e "${FG_ACCENT}${side_part}${RESET}${left_text_pad}${line_text}${right_text_pad}${FG_ACCENT}${side_part}${RESET}"
        done
    fi
}

# Запуск шагов с разделителями / Run steps with separators
run_steps_with_separator() {
    for step in "$@"; do
        case "$step" in
            ::*)
                text="${step#::}"
                separator
                separator "$text"
                separator
                ;;
            *)
                $step
                separator
                printf "\n"
                ;;
        esac
    done
}

# Инициализация языка / Language initialization
init_language() {
    local script_name="install-singbox.sh"

    if [ -z "$LANG" ]; then
        show_message "Выберите язык / Select language [1/2]:"
        show_message "1. Русский (Russian)"
        show_message "2. English (Английский)"
        read_input " Ваш выбор / Your choice [1/2]: " LANG
    fi

    case ${LANG:-2} in
        1)
            MSG_INSTALL_TITLE="Запуск! ($script_name)"
            MSG_UPDATE_PKGS="Обновление репозиториев..."
            MSG_PKGS_SUCCESS="Репозитории успешно обновлены"
            MSG_PKGS_ERROR="Ошибка обновления репозиториев"
            MSG_INSTALL_SINGBOX="Установка последней версии sing-box..."
            MSG_INSTALL_SINGBOX_SUCCESS="Установка sing-box завершена"
            MSG_INSTALL_SINGBOX_ERROR="Ошибка установки sing-box"
            MSG_UNINSTALL_SINGBOX="Удаление sing-box..."
            MSG_UNINSTALL_SINGBOX_SUCCESS="Удаление sing-box завершено"
            MSG_UNINSTALL_SINGBOX_ERROR="Ошибка удаления sing-box"
            MSG_SERVICE_CONFIG="Настройка системного сервиса..."
            MSG_SERVICE_APPLIED="Конфигурация сервиса применена"
            MSG_SERVICE_DISABLED="Сервис временно отключен"
            MSG_CONFIG_RESET="Конфигурационный файл сброшен"
            MSG_NETWORK_CONFIG="Создание сетевого интерфейса proxy..."
            MSG_FIREWALL_CONFIG="Конфигурация правил фаервола..."
            MSG_FIREWALL_APPLIED="Правила фаервола применены"
            MSG_RESTART_FIREWALL="Перезапуск firewall..."
            MSG_RESTART_NETWORK="Перезапуск network..."
            MSG_CLEANUP="Очистка файлов..."
            MSG_CLEANUP_DONE="Файлы удалены!"
            MSG_WAITING="Ожидание %d сек"
            MSG_COMPLETE="Выполнено! ($script_name)"
            MSG_DISABLE_IPV6="Отключение IPv6..."
            MSG_IPV6_DISABLED="IPv6 отключен"
            MSG_START_SERVICE="Запуск сервиса sing-box"
            MSG_SERVICE_STARTED="Сервис успешно запущен"
            MSG_OPERATION="Выберите тип операции:"
            MSG_INSTALL="1. Установка"
            MSG_DELETE="2. Удаление"
            MSG_REINSTALL_UPDATE="3. Переустановка/Обновление"
            MSG_CHOICE=" Ваш выбор: "
            MSG_ALREADY_INSTALLED="Ошибка: Пакет уже установлен. Для переустановки выберите опцию 3"
            MSG_INSTALLING="Установка..."
            MSG_INSTALL_SUCCESS="Установка завершена"
            MSG_UNINSTALLING="Полное удаление..."
            MSG_UNINSTALL_SUCCESS="Удаление завершено"
            MSG_NOT_INSTALLED="Ошибка: Пакет не установлен. Нечего удалять."
            MSG_INVALID_OPERATION="Ошибка: Некорректная операция"
            MSG_RESTORING_IPV6="Восстановление настроек IPv6..."
            MSG_IPV6_RESTORED="Настройки IPv6 восстановлены"
            MSG_REMOVING_NETWORK_CONFIG="Удаление сетевого интерфейса proxy..."
            MSG_REMOVING_FIREWALL_RULES="Удаление правил фаервола..."
            MSG_REMOVING_CONFIGS="Удаление конфигурационных файлов..."
            MSG_NETWORK_CHECK="Проверка доступности сети..."
            MSG_NETWORK_SUCCESS="Сеть доступна (через %s, за %s сек)"
            MSG_NETWORK_ERROR="Сеть не доступна после %s сек!"
            MSG_MODE="Выберите режим установки:"
            MSG_TUN="1. TUN"
            MSG_TPROXY="2. TPROXY"
            MSG_MODE_CHOICE="Ваш выбор: "
            MSG_INSTALLING_TPROXY_MODE="Установка TPROXY режима..."
            MSG_UNINSTALLING_TPROXY_MODE="Удаление TPROXY режима..."
            MSG_INSTALLING_TUN_MODE="Установка TUN режима..."
            MSG_UNINSTALLING_TUN_MODE="Удаление TUN режима..."
            MSG_UNINSTALL_EXISTING_FILES="Удаление существующих файлов sing-box..."
            MSG_INVALID_MODE="Ошибка: Некорректный режим"
            MSG_INVALID_MODE_FOUND="Ошибка: Не найден режим для удаления."
            MSG_MODE_FOUND_TPROXY="Найден TPROXY режим"
            MSG_MODE_FOUND_TUN="Найден TUN режим"
            MSG_MODE_TPROXY_IN_DEVELOPMENT="Режим TPROXY в разработке (для тестирования), продолжить? (Y/n)"
            ;;
        *)
            MSG_INSTALL_TITLE="Starting! ($script_name)"
            MSG_UPDATE_PKGS="Updating packages and installing dependencies..."
            MSG_PKGS_SUCCESS="Packages updated successfully"
            MSG_PKGS_ERROR="Error updating packages"
            MSG_INSTALL_SINGBOX="Installing latest sing-box version..."
            MSG_INSTALL_SINGBOX_SUCCESS="Sing-box installed successfully"
            MSG_INSTALL_SINGBOX_ERROR="Error installing sing-box"
            MSG_UNINSTALL_SINGBOX="Uninstalling sing-box..."
            MSG_UNINSTALL_SINGBOX_SUCCESS="Sing-box uninstalled successfully"
            MSG_UNINSTALL_SINGBOX_ERROR="Error uninstalling sing-box"
            MSG_SERVICE_CONFIG="Configuring system service..."
            MSG_SERVICE_APPLIED="Service configuration applied"
            MSG_SERVICE_DISABLED="Service temporarily disabled"
            MSG_CONFIG_RESET="Configuration file reset"
            MSG_NETWORK_CONFIG="Creating proxy network interface..."
            MSG_FIREWALL_CONFIG="Configuring firewall rules..."
            MSG_FIREWALL_APPLIED="Firewall rules applied"
            MSG_RESTART_FIREWALL="Restarting firewall..."
            MSG_RESTART_NETWORK="Restarting network..."
            MSG_CLEANUP="Cleaning up files..."
            MSG_CLEANUP_DONE="Files removed!"
            MSG_WAITING="Waiting %d sec"
            MSG_COMPLETE="Done! ($script_name)"
            MSG_DISABLE_IPV6="Disabling IPv6..."
            MSG_IPV6_DISABLED="IPv6 disabled"
            MSG_START_SERVICE="Starting sing-box service"
            MSG_SERVICE_STARTED="Service started successfully"
            MSG_OPERATION="Select install operation:"
            MSG_INSTALL="1. Install"
            MSG_DELETE="2. Delete"
            MSG_REINSTALL_UPDATE="3. Reinstall/Update"
            MSG_CHOICE="Your choice: "
            MSG_ALREADY_INSTALLED="Error: Package already installed. For reinstall choose option 3"
            MSG_INSTALLING="Installing..."
            MSG_INSTALL_SUCCESS="Install completed"
            MSG_UNINSTALLING="Completely uninstalling..."
            MSG_UNINSTALL_SUCCESS="Uninstalled successfully"
            MSG_NOT_INSTALLED="Error: Package not installed. Nothing to remove."
            MSG_INVALID_OPERATION="Error: Invalid operation"
            MSG_RESTORING_IPV6="Restoring IPv6 settings..."
            MSG_IPV6_RESTORED="IPv6 settings restored"
            MSG_REMOVING_NETWORK_CONFIG="Removing proxy network interface..."
            MSG_REMOVING_FIREWALL_RULES="Removing firewall rules..."
            MSG_REMOVING_CONFIGS="Removing configuration files..."
            MSG_NETWORK_CHECK="Checking network availability..."
            MSG_NETWORK_SUCCESS="Network available (via %s, in %s sec)"
            MSG_NETWORK_ERROR="Network not available after %s sec!"
            MSG_MODE="Select mode:"
            MSG_TUN="1. TUN"
            MSG_TPROXY="2. TPROXY"
            MSG_MODE_CHOICE="Your choice: "
            MSG_INSTALLING_TPROXY_MODE="Installing TPROXY mode..."
            MSG_UNINSTALLING_TPROXY_MODE="Uninstalling TPROXY mode..."
            MSG_INSTALLING_TUN_MODE="Installing TUN mode..."
            MSG_UNINSTALLING_TUN_MODE="Uninstalling TUN mode..."
            MSG_UNINSTALL_EXISTING_FILES="Uninstalling existing sing-box files..."
            MSG_INVALID_MODE="Error: Invalid mode"
            MSG_INVALID_MODE_FOUND="Error: Mode not found for removal."
            MSG_MODE_FOUND_TPROXY="TPROXY mode found"
            MSG_MODE_FOUND_TUN="TUN mode found"
            MSG_MODE_TPROXY_IN_DEVELOPMENT="TPROXY mode in development (for testing), continue? (Y/n)"
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
    if opkg update && opkg install nftables; then
      show_success "$MSG_PKGS_SUCCESS"
    else
      show_error "$MSG_PKGS_ERROR"
      exit 1
    fi
}

# Выбор операции установки / Choose install operation
choose_install_operation() {
    if [ -z "$OPERATION" ]; then
        show_message "$MSG_OPERATION"
        show_message "$MSG_INSTALL"
        show_message "$MSG_DELETE"
        show_message "$MSG_REINSTALL_UPDATE"
        read_input "$MSG_CHOICE" OPERATION
    fi
}

# Проверка доступности сети / Network availability check
network_check() {
    local timeout=500
    local interval=5
    local targets="223.5.5.5 180.76.76.76 77.88.8.8 1.1.1.1 8.8.8.8 9.9.9.9 94.140.14.14"

    local attempts=$((timeout / interval))
    local success=0
    local i=2

    show_progress "$MSG_NETWORK_CHECK"
    sleep "$interval"

    while [ $i -lt $attempts ]; do
        local num_targets=$(echo "$targets" | wc -w)
        local index=$((i % num_targets))
        local target=$(echo "$targets" | cut -d' ' -f$((index + 1)))

        if ping -c 1 -W 2 "$target" >/dev/null 2>&1; then
            success=1
            break
        fi

        sleep "$interval"
        i=$((i + 1))
    done

    if [ $success -eq 1 ]; then
        local total_time=$((i * interval))
        show_success "$(printf "$MSG_NETWORK_SUCCESS" "$target" "$total_time")"
    else
        show_error "$(printf "$MSG_NETWORK_ERROR" "$timeout")" >&2
        exit 1
    fi
}

# Установка sing-box / Install sing-box
install_singbox() {
    show_progress "$MSG_INSTALL_SINGBOX"
    if opkg install sing-box; then
        show_success "$MSG_INSTALL_SINGBOX_SUCCESS"
    else
        show_error "$MSG_INSTALL_SINGBOX_ERROR"
        exit 1
    fi
}

# Удаление sing-box / Uninstall sing-box
uninstall_singbox() {
    show_progress "$MSG_UNINSTALL_SINGBOX"
    service sing-box stop 2>/dev/null
    service sing-box disable 2>/dev/null
    if opkg remove sing-box --force-depends; then
        show_success "$MSG_UNINSTALL_SINGBOX_SUCCESS"
    else
        show_error "$MSG_UNINSTALL_SINGBOX_ERROR"
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

# Восстановление IPv6 / Restore IPv6
restore_ipv6() {
    show_progress "$MSG_RESTORING_IPV6"
    uci set 'network.lan.ipv6=1'
    uci set 'network.wan.ipv6=1'
    uci set 'dhcp.lan.dhcpv6=server'
    /etc/init.d/odhcpd enable
    uci commit
    show_success "$MSG_IPV6_RESTORED"
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

# Удаление сетевого интерфейса / Remove network interface
remove_configure_proxy() {
    show_progress "$MSG_REMOVING_NETWORK_CONFIG"
    uci -q delete network.proxy
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


# Удаление правил фаервола / Remove firewall rules
remove_firewall_rules() {
    show_progress "$MSG_REMOVING_FIREWALL_RULES"
    
    # Удаление зоны proxy / Remove zone proxy
    local zone_id
    zone_id=$(uci -q show firewall | grep -E "firewall\.@zone\[.*\].name='proxy'" | cut -d'[' -f2 | cut -d']' -f1)
    [ -n "$zone_id" ] && uci -q delete firewall.@zone[$zone_id]
    
    # Удаление правил переадресации / Remove forwarding rules
    local fwd_id
    fwd_id=$(uci -q show firewall | grep -E "firewall\.@forwarding\[.*\].dest='proxy'" | cut -d'[' -f2 | cut -d']' -f1)
    [ -n "$fwd_id" ] && uci -q delete firewall.@forwarding[$fwd_id]
    
    uci commit firewall
}

# Перезагрузка firewall / Restart firewall
restart_firewall() {
    show_progress "$MSG_RESTART_FIREWALL"
    service firewall reload >/dev/null 2>&1
}

# Перезагрузка network / Restart network
restart_network() {
    show_progress "$MSG_RESTART_NETWORK"
    uci commit network           # применяем изменения конфигурации
    /etc/init.d/network reload   # перечитываем сеть без полного рестарта
    ifup proxy 2>/dev/null || true  # поднимаем только интерфейс proxy
}

# Включение sing-box / Enable sing-box
enable_singbox() {
    show_progress "$MSG_START_SERVICE"
    service sing-box enable
    service sing-box start
    show_success "$MSG_SERVICE_STARTED"
}

# Проверка установки / Check installation
check_installed() {
    opkg list-installed | grep -q "sing-box"
    return $?
}

# Удаление конфигураций / Remove configurations
remove_singbox_data() {
    show_progress "$MSG_REMOVING_CONFIGS"
    uci -q delete sing-box
    uci commit sing-box
    [ -f /etc/sing-box/config.json ] && rm -f /etc/sing-box/config.json
    [ -f /etc/config/sing-box ] && rm -f /etc/config/sing-box
}

# Удаление существующих файлов / Remove existing files
uninstall_existing_files(){
    show_progress "$MSG_UNINSTALL_EXISTING_FILES"
    [ -f /etc/config/sing-box.old ] && rm -f /etc/config/sing-box.old
}

# Установка правил nft / Install nft rules
install_nft_rule() {
    nft_rule_file="/etc/nftables.d/singbox.nft"

    cat << 'EOF' > "$nft_rule_file"
define RESERVED_IP = {
    10.0.0.0/8,
    100.64.0.0/10,
    127.0.0.0/8,
    169.254.0.0/16,
    172.16.0.0/12,
    192.0.0.0/24,
    224.0.0.0/4,
    240.0.0.0/4,
    255.255.255.255/32
}

table ip singbox {
    chain prerouting {
        type filter hook prerouting priority mangle; policy accept;
        ip daddr $RESERVED_IP return
        ip saddr $RESERVED_IP return
        ip protocol tcp tproxy to 127.0.0.1:2080 meta mark set 1
        ip protocol udp tproxy to 127.0.0.1:2080 meta mark set 1
    }
    chain output {
        type route hook output priority mangle; policy accept;
        ip daddr $RESERVED_IP return
        ip saddr $RESERVED_IP return
        meta mark 2 return
        ip protocol tcp meta mark set 1
        ip protocol udp meta mark set 1
    }
}
EOF

    chmod +x "$nft_rule_file"
    nft -f "$nft_rule_file"
}

# Удаление правил nft / Remove nft rules
uninstall_nft_rule() {
    nft delete table ip singbox 2>/dev/null
}

# Выбор режима / Choose mode
choose_mode() {
    if [ -z "$MODE" ]; then
        show_message "$MSG_MODE"
        show_message "$MSG_TUN"
        show_message "$MSG_TPROXY"
        read_input "$MSG_MODE_CHOICE" MODE
    fi
}

definition_mode() {
    if [ -f /etc/nftables.d/singbox.nft ]; then
        show_progress "$MSG_MODE_FOUND_TPROXY"
        MODE=2
    elif uci -q get network.proxy.device | grep -q "singtun0"; then
        show_progress "$MSG_MODE_FOUND_TUN"
        MODE=1
    else
        show_error "$MSG_INVALID_MODE_FOUND"
    fi
}

# Установка tun mode / Install tun mode
installed_tun_mode() {
    show_progress "$MSG_INSTALLING_TUN_MODE"
    configure_proxy
    configure_firewall
    restart_firewall
    restart_network
    network_check
    enable_singbox
}

# Удаление tun mode / Uninstall tun mode
uninstalled_tun_mode() {
    show_progress "$MSG_UNINSTALLING_TUN_MODE"
    remove_configure_proxy
    remove_firewall_rules
    restart_firewall
    restart_network
    network_check
}

# Установка tproxy mode / Install tproxy mode
installed_tproxy_mode() {
    show_progress "$MSG_INSTALLING_TPROXY_MODE"
    install_nft_rule
}

# Удаление tproxy mode / Uninstall tproxy mode
uninstalled_tproxy_mode() {
    show_progress "$MSG_UNINSTALLING_TPROXY_MODE"
    uninstall_nft_rule
}

# Выбор режима установки / Choose install mode
perform_install_mode() {
    case $MODE in
        1)
            installed_tun_mode
            ;;
        2)
            read_input "$MSG_MODE_TPROXY_IN_DEVELOPMENT" MODE_DEVELOPMENT
            case $MODE_DEVELOPMENTE in
                [Yy])
                    installed_tproxy_mode
                    ;;
                *)
                    unset MODE
                    choose_mode
                    perform_install_mode
                    ;;
            esac
            ;;
        *)
            show_error "$MSG_INVALID_MODE"
            exit 1
            ;;
    esac
}

# Выбор режима установки / Choose install mode
perform_uninstall_mode() {
    case $MODE in
        1)
            uninstalled_tun_mode
            ;;
        2)
            uninstalled_tproxy_mode
            ;;
        *)
            show_error "$MSG_INVALID_MODE"
            ;;
    esac
}

# Установка / Install
install() {
    show_progress "$MSG_INSTALLING"
    choose_mode
    install_singbox
    configure_singbox_service
    disable_singbox_service
    clean_singbox_config
    perform_install_mode
    disabled_ipv6
    network_check
    show_success "$MSG_INSTALL_SUCCESS"
}

# Удаление / Uninstall
uninstall() {
    show_progress "$MSG_UNINSTALLING"
    definition_mode
    uninstall_singbox
    perform_uninstall_mode
    unset MODE
    remove_singbox_data
    uninstall_existing_files
    restore_ipv6
    network_check
    show_success "$MSG_UNINSTALL_SUCCESS"
}

# Выполнение операций / Perform operations
perform_operation() {
    case $OPERATION in
        1)  
            if check_installed; then
                show_error "$MSG_ALREADY_INSTALLED"
                exit 1
            fi
            install
            ;;
        2)  
            if ! check_installed; then
                show_error "$MSG_NOT_INSTALLED"
                exit 1
            fi
            uninstall
            ;;
        3)  
            if check_installed; then
                uninstall
            fi
            update_pkgs
            install
            ;;
        *)
            show_error "$MSG_INVALID_OPERATION"
            exit 1
            ;;
    esac
}

# Очистка / Cleanup
cleanup() {
    show_progress "$MSG_CLEANUP"
    rm -- "$0"
    show_success "$MSG_CLEANUP_DONE"
}

# Завершение скрипта / Complete script
complete_script() {
    show_success "$MSG_COMPLETE"
    cleanup
}

# ======== Основной код / Main code ========

run_steps_with_separator \
    init_language

run_steps_with_separator \
    "::$MSG_INSTALL_TITLE" \
    update_pkgs \
    choose_install_operation \
    perform_operation \
    complete_script
