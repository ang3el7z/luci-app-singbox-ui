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

# Предупреждение / Warning
show_warning() {
    echo -e "${INDENT}! ${FG_WARNING}$1${RESET}\n"
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
        MSG_INSTALL_TITLE="Установка и настройка singbox-ui"
        MSG_NETWORK_CHECK="Проверка доступности сети..."
        MSG_NETWORK_SUCCESS="Сеть доступна (через %s, за %s сек)"
        MSG_NETWORK_ERROR="Сеть не доступна после %s сек!"
        MSG_SINGBOX_INSTALL="Переход к установке singbox..."
        MSG_SINGBOX_RETURN="Вернулись к основному скрипту"
        MSG_SINGBOX_UI_INSTALL="Переход к установке singbox-ui..."
        MSG_CLEANUP="Очистка файлов..."
        MSG_CLEANUP_DONE="Файлы удалены!"
        MSG_COMPLETE="Выполнено! (install-singbox+singbox-ui.sh)"
        MSG_WAITING="Ожидание %d сек"
        MSG_UPDATE_PKGS="Обновление пакетов и установка зависимостей..."
        MSG_DEPS_SUCCESS="Зависимости успешно установлены"
        MSG_DEPS_ERROR="Ошибка установки зависимостей"
        MSG_INSTALL_ACTION="Выберите действие:"
        MSG_INSTALL_SINGBOX_UI="1. Установка singbox-ui"
        MSG_INSTALL_SINGBOX_UI_AND_SINGBOX="2. Установка singbox-ui и singbox"
        MSG_INSTALL_ACTION_CHOICE=" Ваш выбор: "
        MSG_INSTALL_OPERATION="Выберите тип операции:"
        MSG_INSTALL_OPERATION_INSTALL="1. Установка"
        MSG_INSTALL_OPERATION_DELETE="2. Удаление"
        MSG_INSTALL_OPERATION_REINSTALL_UPDATE="3. Переустановка/Обновление"
        MSG_INSTALL_OPERATION_CHOICE=" Ваш выбор: "
        ;;
    *)
        MSG_INSTALL_TITLE="Starting installation"
        MSG_NETWORK_CHECK="Checking network availability..."
        MSG_NETWORK_SUCCESS="Network is available (via %s, in %s sec)"
        MSG_NETWORK_ERROR="Network is not available after %s sec!"
        MSG_SINGBOX_INSTALL="Proceeding to singbox installation..."
        MSG_SINGBOX_RETURN="Returned to main script"
        MSG_SINGBOX_UI_INSTALL="Proceeding to singbox-ui installation..."
        MSG_CLEANUP="Cleaning up files..."
        MSG_CLEANUP_DONE="Files removed!"
        MSG_COMPLETE="Done! (install-singbox+singbox-ui.sh)"
        MSG_WAITING="Waiting %d sec"
        MSG_UPDATE_PKGS="Updating packages and installing dependencies..."
        MSG_DEPS_SUCCESS="Dependencies successfully installed"
        MSG_DEPS_ERROR="Error installing dependencies"
        MSG_INSTALL_ACTION="Select action:"
        MSG_INSTALL_SINGBOX_UI="1. Install singbox-ui"
        MSG_INSTALL_SINGBOX_UI_AND_SINGBOX="2. Install singbox-ui and singbox"
        MSG_INSTALL_ACTION_CHOICE="Your choice: "
        MSG_INSTALL_OPERATION="Select install operation:"
        MSG_INSTALL_OPERATION_INSTALL="1. Install"
        MSG_INSTALL_OPERATION_DELETE="2. Delete"
        MSG_INSTALL_OPERATION_REINSTALL_UPDATE="3. Reinstall/Update"
        MSG_INSTALL_OPERATION_CHOICE="Your choice: "
        ;;
esac
}

# Ожидание / Waiting
waiting() {
    local interval="${1:-30}"
    show_progress "$(printf "$MSG_WAITING" "$interval")"
    sleep "$interval"
}

# Обновление репозиториев и установка зависимостей / Update repos and install dependencies
update_pkgs() {
    show_progress "$MSG_UPDATE_PKGS"
    opkg update
    if [ $? -eq 0 ]; then
        show_success "$MSG_DEPS_SUCCESS"
    else
        show_error "$MSG_DEPS_ERROR"
        exit 1
    fi
}

# Выбор операции установки / Choose install operation
choose_install_operation() {
    if [ -z "$INSTALL_OPERATION" ]; then
        show_message "$MSG_INSTALL_OPERATION"
        show_message "$MSG_INSTALL_OPERATION_INSTALL"
        show_message "$MSG_INSTALL_OPERATION_DELETE"
        show_message "$MSG_INSTALL_OPERATION_REINSTALL_UPDATE"
        read_input "$MSG_INSTALL_OPERATION_CHOICE" INSTALL_OPERATION
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

# Установка singbox / Install singbox
install_singbox_script() {
    show_warning "$MSG_SINGBOX_INSTALL"

    wget -O /root/install-singbox.sh https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/main/other/install-singbox.sh && 
    chmod 0755 /root/install-singbox.sh && LANG_CHOICE=$LANG_CHOICE && INSTALL_OPERATION=$INSTALL_OPERATION sh /root/install-singbox.sh

    show_warning "$MSG_SINGBOX_RETURN"
}

# Установка singbox-ui / singbox-ui installation
install_singbox_ui_script() {
    show_warning "$MSG_SINGBOX_UI_INSTALL"

    wget -O /root/install-singbox-ui.sh https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/main/other/install-singbox-ui.sh && 
    chmod 0755 /root/install-singbox-ui.sh && LANG_CHOICE=$LANG_CHOICE && INSTALL_OPERATION=$INSTALL_OPERATION sh /root/install-singbox-ui.sh

    show_warning "$MSG_SINGBOX_RETURN"
}

# Выбор варианта установки / Choose installation variant
choose_action() {
    if [ -z "$ACTION_CHOICE" ]; then
        show_message "$MSG_INSTALL_ACTION"
        show_message "$MSG_INSTALL_SINGBOX_UI"
        show_message "$MSG_INSTALL_SINGBOX_UI_AND_SINGBOX"
        read_input "$MSG_INSTALL_ACTION_CHOICE" ACTION_CHOICE
    fi

    case ${ACTION_CHOICE:-2} in
    1)
        install_singbox_ui_script
        ;;
    2)
        install_singbox_script
        install_singbox_ui_script
        ;;
    *)
        show_error "Некорректный ввод"
        exit 1
        ;;
esac
}

# Очистка файлов / Cleanup
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

init_language
header "$MSG_INSTALL_TITLE"
update_pkgs
choose_install_operation
choose_action
complete_script