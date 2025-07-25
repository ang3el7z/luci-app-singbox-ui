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

# Символы оформления / Decorations
SEP_CHAR="◈"
ARROW="▸"
ARROW_CLEAR="▷"
CHECK="✓"
CROSS="✗"
INDENT="  "

# Функция разделителя / Separator function
separator() {
    echo -e "${FG_MAIN}                -------------------------------------                ${RESET}"
}

header() {
    clear
    separator
    echo -e "${BG_ACCENT}${FG_MAIN}                $MSG_START_INSTALL               ${RESET}"
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

show_message() {
    echo -e "${FG_USER_COLOR}${INDENT}${ARROW} $1${RESET}"
}

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

    # Установка языка по умолчанию (английский) / Default to English
    case ${LANG_CHOICE:-2} in
    1)
        # Русские тексты / Russian texts
        MSG_START_INSTALL="Начало установки"
        MSG_NETWORK_CHECK="Проверка доступности сети..."
        MSG_NETWORK_SUCCESS="Сеть доступна (через %s, за %s сек)"
        MSG_NETWORK_ERROR="Сеть не доступна после %s сек!"
        MSG_SINGBOX_INSTALL="Переход к установке singbox..."
        MSG_SINGBOX_RETURN="Вернулись к основному скрипту"
        MSG_CONFIG_PROMPT="Введите URL конфигурации (Enter для ручного ввода): "
        MSG_CONFIG_LOADING="Загрузка конфигурации с %s (Попытка %s из %s)"
        MSG_CONFIG_SUCCESS="Конфигурация успешно загружена"
        MSG_CONFIG_ERROR="Ошибка загрузки: %s"
        MSG_FORMAT_ERROR="Ошибка формата конфигурации"
        MSG_RETRY="Попробую снова..."
        MSG_MANUAL_CONFIG="Ручная настройка конфигурации"
        MSG_EDIT_COMPLETE="Завершили редактирование config.json? [y/N]: "
        MSG_EDIT_SUCCESS="Успешно"
        MSG_INVALID_INPUT="Некорректный ввод"
        MSG_UI_INSTALL="Переход к установке singbox-ui..."
        MSG_DISABLE_IPV6="Отключение IPv6..."
        MSG_IPV6_DISABLED="IPv6 отключен"
        MSG_RESTART_FIREWALL="Перезапуск firewall..."
        MSG_RESTART_NETWORK="Перезапуск network..."
        MSG_START_SERVICE="Включение sing-box"
        MSG_SERVICE_STARTED="Сервис успешно запущен"
        MSG_CLEANUP="Очистка файлов..."
        MSG_CLEANUP_DONE="Файлы удалены!"
        MSG_INSTALL_COMPLETE="Установка завершена!"
        MSG_WAITING="Ожидание %d сек"
        ;;
    *)
        # Английские тексты / English texts
        MSG_START_INSTALL="Starting installation"
        MSG_NETWORK_CHECK="Checking network availability..."
        MSG_NETWORK_SUCCESS="Network is available (via %s, in %s sec)"
        MSG_NETWORK_ERROR="Network is not available after %s sec!"
        MSG_SINGBOX_INSTALL="Proceeding to singbox installation..."
        MSG_SINGBOX_RETURN="Returned to main script"
        MSG_CONFIG_PROMPT="Enter Configuration subscription URL (Enter for manual input): "
        MSG_CONFIG_LOADING="Loading configuration from %s (Attempt %s of %s)"
        MSG_CONFIG_SUCCESS="Configuration loaded successfully"
        MSG_CONFIG_ERROR="Loading error: %s"
        MSG_FORMAT_ERROR="Configuration format error"
        MSG_RETRY="Retrying..."
        MSG_MANUAL_CONFIG="Manual configuration"
        MSG_EDIT_COMPLETE="Finished editing config.json? [y/N]: "
        MSG_EDIT_SUCCESS="Success"
        MSG_INVALID_INPUT="Invalid input"
        MSG_UI_INSTALL="Proceeding to singbox-ui installation..."
        MSG_DISABLE_IPV6="Disabling IPv6..."
        MSG_IPV6_DISABLED="IPv6 disabled"
        MSG_RESTART_FIREWALL="Restarting firewall..."
        MSG_RESTART_NETWORK="Restarting network..."
        MSG_START_SERVICE="Starting sing-box service"
        MSG_SERVICE_STARTED="Service started successfully"
        MSG_CLEANUP="Cleaning up files..."
        MSG_CLEANUP_DONE="Files removed!"
        MSG_INSTALL_COMPLETE="Installation complete!"
        MSG_WAITING="Waiting %d sec"
        ;;
esac
}

waiting() {
    local interval="${1:-30}"
    show_progress "$(printf "$MSG_WAITING" "$interval")"
    sleep "$interval"
}

network_check() {
    timeout=200
    interval=5
    targets="223.5.5.5 180.76.76.76 77.88.8.8 1.1.1.1 8.8.8.8 9.9.9.9 94.140.14.14"

    attempts=$((timeout / interval))
    success=0
    i=0

    show_progress "$MSG_NETWORK_CHECK"

    while [ $i -lt $attempts ]; do
        # Получаем текущий индекс для выбора адреса / Get current index for target selection
        num_targets=$(echo "$targets" | wc -w)
        index=$((i % num_targets))
        target=$(echo "$targets" | cut -d' ' -f$((index + 1)))

        if ping -c 1 -W 2 "$target" >/dev/null 2>&1; then
            success=1
            break
        fi

        waiting $interval
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

init_language
header

# Установка singbox / Install singbox
separator
show_warning "$MSG_SINGBOX_INSTALL"
wget -O /root/install-singbox.sh https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/main/other/install-singbox.sh && chmod 0755 /root/install-singbox.sh && LANG_CHOICE=$LANG_CHOICE sh /root/install-singbox.sh
show_warning "$MSG_SINGBOX_RETURN"

waiting 30
network_check

if [ -z "$CONFIG_URL" ]; then
read_input "${MSG_CONFIG_PROMPT}" CONFIG_URL
fi

# Добавьте в начало скрипта (перед проверкой CONFIG_URL)
AUTO_CONFIG_SUCCESS=0  # Инициализация переменной

# Проверяем, что URL не пустой / Check if URL is not empty
if [ -n "$CONFIG_URL" ]; then
    MAX_ATTEMPTS=3
    ATTEMPT=1
    SUCCESS=0

    # Пытаемся загрузить конфигурацию / Try to load configuration
    while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
        show_progress "$(printf "$MSG_CONFIG_LOADING" "$CONFIG_URL" "$ATTEMPT" "$MAX_ATTEMPTS")"
        
        # Улучшенная загрузка и проверка JSON / Improved JSON loading and validation
        if RAW_JSON=$(curl -fsS "$CONFIG_URL" 2>/dev/null) && [ -n "$RAW_JSON" ]; then
            if FORMATTED_JSON=$(echo "$RAW_JSON" | jq -e '.' 2>/dev/null); then
                echo "$FORMATTED_JSON" > /etc/sing-box/config.json
                show_success "$MSG_CONFIG_SUCCESS"
                AUTO_CONFIG_SUCCESS=1
                SUCCESS=1
                break
            else
                show_error "$MSG_FORMAT_ERROR"
            fi
        else
            show_error "$(printf "$MSG_CONFIG_ERROR" "${RAW_JSON:-"Unknown error"}")"
        fi

        if [ $ATTEMPT -lt $MAX_ATTEMPTS ]; then
            show_warning "$MSG_RETRY"
            network_check
        fi
        
        ATTEMPT=$((ATTEMPT + 1))
    done

    if [ $SUCCESS -eq 0 ]; then
        show_warning "$MSG_MANUAL_CONFIG"
        export TERM=xterm
        nano /etc/sing-box/config.json || {
            show_error "Failed to open editor. Please check your terminal settings."
            exit 1
        }
    fi
else
    show_warning "$MSG_MANUAL_CONFIG"
    export TERM=xterm
    nano /etc/sing-box/config.json || {
        show_error "Failed to open editor. Please check your terminal settings."
        exit 1
    }
fi

# Проверка ручной конфигурации / Manual configuration check
if [ "$AUTO_CONFIG_SUCCESS" -ne 1 ]; then
    while true; do
        separator
        read_input "${MSG_EDIT_COMPLETE}" edit_choice
        case "${edit_choice:-Y}" in  # По умолчанию Y если ввод пустой / Default to Y if input is empty
            [Yy]* )
                show_success "$MSG_EDIT_SUCCESS"
                break
                ;;
            [Nn]* )
                export TERM=xterm
                nano /etc/sing-box/config.json || {
                    show_error "Failed to open editor. Please check your terminal settings."
                    continue
                }
                ;;
            * )
                show_error "$MSG_INVALID_INPUT"
                ;;
        esac
    done
fi

# Установка веб-интерфейса / Web UI installation
separator
show_warning "$MSG_UI_INSTALL"
wget -O /root/install-singbox-ui.sh https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/main/other/install-singbox-ui.sh && chmod 0755 /root/install-singbox-ui.sh && LANG_CHOICE=$LANG_CHOICE sh /root/install-singbox-ui.sh
echo "$CONFIG_URL" > "/etc/sing-box/url_config.json"
show_warning "$MSG_SINGBOX_RETURN"

# Отключение IPv6 / Disable IPv6
separator
show_progress "$MSG_DISABLE_IPV6"
uci set 'network.lan.ipv6=0'
uci set 'network.wan.ipv6=0'
uci set 'dhcp.lan.dhcpv6=disabled'
/etc/init.d/odhcpd disable
uci commit
show_success "$MSG_IPV6_DISABLED"

show_progress "$MSG_RESTART_FIREWALL"
service firewall reload >/dev/null 2>&1

show_progress "$MSG_RESTART_NETWORK"
service network restart

network_check

show_progress "$MSG_START_SERVICE"
waiting 15
service sing-box enable
service sing-box start
show_success "$MSG_SERVICE_STARTED"
 
separator
show_success "$MSG_INSTALL_COMPLETE"
separator

show_progress "$MSG_CLEANUP"
rm -- "$0"
show_success "$MSG_CLEANUP_DONE"
