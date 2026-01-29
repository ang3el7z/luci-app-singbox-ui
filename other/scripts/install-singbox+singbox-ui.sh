#!/bin/sh
BRANCH="${BRANCH:-main}"

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
UI_PATH="$SCRIPT_DIR/lib/ui.sh"
UI_DOWNLOADED=0
cleanup_ui_library() {
    if [ "${UI_DOWNLOADED:-0}" -eq 1 ]; then
        if command -v show_progress >/dev/null 2>&1; then
            show_progress "Cleaning UI library..."
        else
            echo "Cleaning UI library..."
        fi
        rm -f -- "$UI_PATH"
        rmdir -- "$SCRIPT_DIR/lib" 2>/dev/null || true
    fi
}
ensure_ui_library() {
    if [ -f "$UI_PATH" ]; then
        . "$UI_PATH"
        return 0
    fi

    mkdir -p "$SCRIPT_DIR/lib" 2>/dev/null
    ui_url="https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/$BRANCH/other/scripts/lib/ui.sh"
    if command -v wget >/dev/null 2>&1; then
        wget -O "$UI_PATH" "$ui_url" || return 1
    elif command -v curl >/dev/null 2>&1; then
        curl -fsSL -o "$UI_PATH" "$ui_url" || return 1
    else
        echo "Missing UI library and downloader (wget/curl)" >&2
        return 1
    fi

    UI_DOWNLOADED=1
    . "$UI_PATH"
}

ensure_ui_library || {
    echo "Missing UI library: $UI_PATH" >&2
    exit 1
}
trap cleanup_ui_library EXIT HUP INT TERM

# Инициализация языка / Language initialization
init_language() {
    local script_name="install-singbox+singbox-ui.sh"

    if [ -z "$LANG" ]; then
        while true; do
            show_message "Выберите язык / Select language [1/2]:"
            show_message "1. Русский (Russian)"
            show_message "2. English (Английский)"
            read_input " Ваш выбор / Your choice [1/2]: " LANG
            case "$LANG" in
                1|2)
                    break
                    ;;
                *)
                    show_error "Invalid choice. Please enter 1 or 2."
                    ;;
            esac
        done
    fi

    case ${LANG:-2} in
    1)
        MSG_INSTALL_TITLE="Запуск! ($script_name)"
        MSG_NETWORK_CHECK="Проверка доступности сети..."
        MSG_NETWORK_SUCCESS="Сеть доступна (через %s, за %s сек)"
        MSG_NETWORK_ERROR="Сеть не доступна после %s сек!"
        MSG_SINGBOX_INSTALL="Переход к скрипту install-singbox.sh..."
        MSG_SINGBOX_RETURN="Вернулись к основному скрипту"
        MSG_SINGBOX_UI_INSTALL="Переход к скрипту install-singbox-ui.sh..."
        MSG_CLEANUP="Очистка файлов..."
        MSG_CLEANUP_DONE="Файлы удалены!"
        MSG_COMPLETE="Выполнено! ($script_name)"
        MSG_WAITING="Ожидание %d сек"
        MSG_UPDATE_PKGS="Обновление пакетов и установка зависимостей..."
        MSG_DEPS_SUCCESS="Зависимости успешно установлены"
        MSG_DEPS_ERROR="Ошибка установки зависимостей"
        MSG_INSTALL_ACTION="Выберите действие:"
        MSG_INSTALL_SINGBOX_UI="1. Singbox-ui"
        MSG_INSTALL_SINGBOX="2. Singbox"
        MSG_INSTALL_SINGBOX_UI_AND_SINGBOX="3. Singbox and singbox-ui"
        MSG_INSTALL_ACTION_CHOICE=" Ваш выбор: "
        MSG_OPERATION="Выберите тип операции:"
        MSG_OPERATION_INSTALL="1. Установка"
        MSG_OPERATION_DELETE="2. Удаление"
        MSG_OPERATION_REINSTALL_UPDATE="3. Переустановка/Обновление"
        MSG_OPERATION_CHOICE="Ваш выбор: "
        MSG_INSTALL_SFTP_SERVER="Установить openssh-sftp-server? y/n (n - по умолчанию): "
        MSG_SFTP_ALREADY_INSTALLED="openssh-sftp-server уже установлен"
        MSG_INVALID_INPUT="Некорректный ввод"
        MSG_REPEAT_INPUT="Повторите ввод"
        ;;
    *)
        MSG_INSTALL_TITLE="Starting! ($script_name)"
        MSG_NETWORK_CHECK="Checking network availability..."
        MSG_NETWORK_SUCCESS="Network is available (via %s, in %s sec)"
        MSG_NETWORK_ERROR="Network is not available after %s sec!"
        MSG_SINGBOX_INSTALL="Proceeding to script install-singbox.sh..."
        MSG_SINGBOX_RETURN="Returned to main script"
        MSG_SINGBOX_UI_INSTALL="Proceeding to script install-singbox-ui.sh..."
        MSG_CLEANUP="Cleaning up files..."
        MSG_CLEANUP_DONE="Files removed!"
        MSG_COMPLETE="Done! ($script_name)"
        MSG_WAITING="Waiting %d sec"
        MSG_UPDATE_PKGS="Updating packages and installing dependencies..."
        MSG_DEPS_SUCCESS="Dependencies successfully installed"
        MSG_DEPS_ERROR="Error installing dependencies"
        MSG_INSTALL_ACTION="Select action:"
        MSG_INSTALL_SINGBOX_UI="1. Singbox-ui"
        MSG_INSTALL_SINGBOX="2. Singbox"
        MSG_INSTALL_SINGBOX_UI_AND_SINGBOX="3. Singbox and singbox-ui"
        MSG_INSTALL_ACTION_CHOICE="Your choice: "
        MSG_OPERATION="Select install operation:"
        MSG_OPERATION_INSTALL="1. Install"
        MSG_OPERATION_DELETE="2. Delete"
        MSG_OPERATION_REINSTALL_UPDATE="3. Reinstall/Update"
        MSG_OPERATION_CHOICE="Your choice: "
        MSG_INSTALL_SFTP_SERVER="Install openssh-sftp-server? y/n (n - by default): "
        MSG_SFTP_ALREADY_INSTALLED="openssh-sftp-server already installed"
        MSG_INVALID_INPUT="Invalid input"
        MSG_REPEAT_INPUT="Repeat input"
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

    if opkg list-installed | grep -q "^openssh-sftp-server "; then
        echo "$MSG_SFTP_ALREADY_INSTALLED"
        SFTP_SERVER="n"
    else
        while true; do
            read_input "$MSG_INSTALL_SFTP_SERVER" SFTP_SERVER
            if [ -z "$SFTP_SERVER" ]; then
                SFTP_SERVER="n"
            fi
            case "$SFTP_SERVER" in
                [Yy]|[Nn])
                    break
                    ;;
                *)
                    show_error "$MSG_INVALID_INPUT. $MSG_REPEAT_INPUT"
                    ;;
            esac
        done
    fi

    case $SFTP_SERVER in
    [Yy])
        if opkg update && opkg install openssh-sftp-server; then
            show_success "$MSG_DEPS_SUCCESS"
        else
            show_error "$MSG_DEPS_ERROR"
            exit 1
        fi
        ;;
    [Nn]|"")
        if opkg update; then
            show_success "$MSG_DEPS_SUCCESS"
        else
            show_error "$MSG_DEPS_ERROR"
            exit 1
        fi
        ;;
    esac
}


# Выбор операции установки / Choose install operation
choose_install_operation() {
    if [ -z "$OPERATION" ]; then
        while true; do
            show_message "$MSG_OPERATION"
            show_message "$MSG_OPERATION_INSTALL"
            show_message "$MSG_OPERATION_DELETE"
            show_message "$MSG_OPERATION_REINSTALL_UPDATE"
            read_input "$MSG_OPERATION_CHOICE" OPERATION
            case "$OPERATION" in
                1|2|3)
                    break
                    ;;
                *)
                    show_error "$MSG_INVALID_INPUT. $MSG_REPEAT_INPUT"
                    ;;
            esac
        done
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

# Установка singbox / Install singbox
install_singbox_script() {
    show_warning "$MSG_SINGBOX_INSTALL"

    wget -O /root/install-singbox.sh https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/$BRANCH/other/scripts/install-singbox.sh &&
    chmod 0755 /root/install-singbox.sh &&
    LANG="$LANG" OPERATION="$OPERATION" sh /root/install-singbox.sh

    show_warning "$MSG_SINGBOX_RETURN"
}

# Установка singbox-ui / singbox-ui installation
install_singbox_ui_script() {
    show_warning "$MSG_SINGBOX_UI_INSTALL"

    wget -O /root/install-singbox-ui.sh https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/$BRANCH/other/scripts/install-singbox-ui.sh &&
    chmod 0755 /root/install-singbox-ui.sh &&
    LANG="$LANG" OPERATION="$OPERATION" sh /root/install-singbox-ui.sh

    show_warning "$MSG_SINGBOX_RETURN"
}

# Выбор варианта установки / Choose installation variant
choose_action() {
    if [ -z "$ACTION_CHOICE" ]; then
        while true; do
            show_message "$MSG_INSTALL_ACTION"
            show_message "$MSG_INSTALL_SINGBOX_UI"
            show_message "$MSG_INSTALL_SINGBOX"
            show_message "$MSG_INSTALL_SINGBOX_UI_AND_SINGBOX"
            read_input "$MSG_INSTALL_ACTION_CHOICE" ACTION_CHOICE
            case "$ACTION_CHOICE" in
                1|2|3)
                    break
                    ;;
                *)
                    show_error "$MSG_INVALID_INPUT. $MSG_REPEAT_INPUT"
                    ;;
            esac
        done
    fi

    case "$ACTION_CHOICE" in
        1)
            install_singbox_ui_script
            ;;
        2)
            install_singbox_script
            ;;
        3)
            install_singbox_script
            install_singbox_ui_script
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

run_steps_with_separator \
    init_language

run_steps_with_separator \
    "::$MSG_INSTALL_TITLE" \
    update_pkgs \
    choose_install_operation \
    choose_action \
    complete_script
