#!/bin/bash

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

# Инициализация языка / Language initialization
init_language() {
    echo -e "\n  ▷ Выберите язык / Select language [1/2]:"
    echo -e "  1. Русский (Russian)"
    echo -e "  2. English (Английский)"
    read -p "  ▷ Ваш выбор / Your choice [1/2]: " LANG_CHOICE

    case ${LANG_CHOICE:-1} in
        1)
            MSG_INSTALL_TITLE="Установка в один клик -> singbox+singbox-ui"
            MSG_ROUTER_IP="Введите адрес роутера (по умолчанию 192.168.1.1, нажмите Enter): "
            MSG_ROUTER_PASS="Введите пароль для root (если нет пароля - нажмите Enter): "
            MSG_RESET_ROUTER="Сбросить настройки роутера перед установкой? [y/N]: "
            MSG_RESETTING="Сбрасываем настройки роутера..."
            MSG_REMOVE_KEY="Удаляем старый ключ хоста для"
            MSG_CONNECTING="Подключаемся к роутеру и выполняем установку..."
            MSG_COMPLETE="Установка завершена!"
            MSG_CLEANUP="Очистка и удаление скрипта..."
            MSG_CLEANUP_DONE="Готово! Скрипт удален."
            MSG_SSH_ERROR="Ошибка подключения к роутеру"
            MSG_RESET_COMPLETE="Сброс роутера выполнен"
            MSG_NETWORK_CHECK="Проверка подключения к интернету..."
            MSG_NETWORK_SUCCESS="Подключение восстановлено через %s (%d сек)"
            MSG_NETWORK_ERROR="Не удалось восстановить подключение после %d сек"
            MSG_WAITING_ROUTER="Ожидание восстановления связи с роутером..."
            MSG_ROUTER_AVAILABLE="Роутер доступен через %s (%d сек)"
            MSG_ROUTER_NOT_AVAILABLE="Роутер не доступен после %d сек"
            ;;
        *)
            MSG_INSTALL_TITLE="Install one click -> singbox+singbox-ui"
            MSG_ROUTER_IP="Enter router address (default 192.168.1.1, press Enter): "
            MSG_ROUTER_PASS="Enter root password (if no password - press Enter): "
            MSG_RESET_ROUTER="Reset router settings before installation? [y/N]: "
            MSG_RESETTING="Resetting router settings..."
            MSG_REMOVE_KEY="Removing old host key for"
            MSG_CONNECTING="Connecting to router and installing..."
            MSG_COMPLETE="Installation complete!"
            MSG_CLEANUP="Cleaning up and removing script..."
            MSG_CLEANUP_DONE="Done! Script removed."
            MSG_SSH_ERROR="Failed to connect to router"
            MSG_RESET_COMPLETE="Router reset complete"
            MSG_NETWORK_CHECK="Checking internet connection..."
            MSG_NETWORK_SUCCESS="Connection restored via %s (%d sec)"
            MSG_NETWORK_ERROR="Failed to restore connection after %d sec"
            MSG_WAITING_ROUTER="Waiting for router to come back online..."
            MSG_ROUTER_NOT_AVAILABLE="Router not available after %d sec"
            ;;
    esac
}

wait_for_router() {
    local timeout=300
    local interval=5
    local attempts=$((timeout/interval))
    
    show_progress "$MSG_WAITING_ROUTER"
    
    for ((i=1; i<=attempts; i++)); do
        if ping -c 1 -W 2 "$router_ip" >/dev/null 2>&1; then
            show_success "$MSG_ROUTER_AVAILABLE" "$router_ip" "$((i*interval))"
            return 0
        fi
        sleep $interval
    done
    
    show_error "$MSG_ROUTER_NOT_AVAILABLE" "$router_ip" "$timeout"
    return 1
}

network_check() {
    local timeout=100
    local interval=5
    local attempts=$((timeout/interval))
    local success=0
    
    show_progress "$MSG_NETWORK_CHECK"
    
    for ((i=1; i<=attempts; i++)); do
        if ping -c 1 -W 2 "8.8.8.8" >/dev/null 2>&1; then
            success=1
            break
        fi
        sleep $interval
    done
    
    if [ $success -eq 1 ]; then
        show_success "$(printf "$MSG_NETWORK_SUCCESS" "8.8.8.8" "$((i*interval))")"
        return 0
    else
        show_error "$(printf "$MSG_NETWORK_ERROR" "$timeout")"
        return 1
    fi
}

reset_router() {
    show_progress "$MSG_RESETTING"
    if [ -z "$password" ]; then
        if ! ssh -o "StrictHostKeyChecking no" "root@$router_ip" "firstboot -y && reboot now"; then
            show_error "$MSG_SSH_ERROR"
            return 1
        fi
    else
        if ! sshpass -p "$password" ssh -o "StrictHostKeyChecking no" "root@$router_ip" "firstboot -y && reboot now"; then
            show_error "$MSG_SSH_ERROR"
            return 1
        fi
    fi
    show_success "$MSG_RESET_COMPLETE"
    return 0
}

# Инициализация / Initialize
init_language
header

# Запрос данных / Input data
read -p "${MSG_ROUTER_IP}" router_ip
router_ip=${router_ip:-"192.168.1.1"}

read -s -p "${MSG_ROUTER_PASS}" password
echo ""

# Запрос на сброс роутера / Ask for router reset
read -p "${MSG_RESET_ROUTER}" reset_choice
if [[ "$reset_choice" =~ ^[Yy]$ ]]; then
    if reset_router; then
        wait_for_router && network_check
    else
        exit 1
    fi
fi

# Удаление старого ключа / Remove old key
show_progress "${MSG_REMOVE_KEY} ${router_ip}"
ssh-keygen -R "$router_ip" 2>/dev/null

# Подключение и установка / Connect and install
show_progress "$MSG_CONNECTING"
sleep 2

if [ -z "$password" ]; then
    ssh -o "StrictHostKeyChecking no" "root@$router_ip" \
        "export LANG_CHOICE=$LANG_CHOICE; \
        wget -O /root/install-singbox+singbox-ui.sh https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/main/other/install-singbox+singbox-ui.sh && \
        chmod 0755 /root/install-singbox+singbox-ui.sh && \
        sh /root/install-singbox+singbox-ui.sh" || {
        show_error "$MSG_SSH_ERROR"
        exit 1
    }
else
    sshpass -p "$password" ssh -o "StrictHostKeyChecking no" "root@$router_ip" \
        "export LANG_CHOICE=$LANG_CHOICE; \
        wget -O /root/install-singbox+singbox-ui.sh https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/main/other/install-singbox+singbox-ui.sh && \
        chmod 0755 /root/install-singbox+singbox-ui.sh && \
        sh /root/install-singbox+singbox-ui.sh" || {
        show_error "$MSG_SSH_ERROR"
        exit 1
    }
fi

# Завершение / Completion
show_success "$MSG_COMPLETE"

# Очистка / Cleanup
show_progress "$MSG_CLEANUP"
rm -f -- "$0"
show_success "$MSG_CLEANUP_DONE"