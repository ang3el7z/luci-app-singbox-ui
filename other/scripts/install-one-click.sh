#!/bin/bash
BRANCH="${BRANCH:-main}"

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
UI_PATH="$SCRIPT_DIR/lib/ui.sh"
UI_DOWNLOADED=0
cleanup_ui_library() {
    if [ "${UI_DOWNLOADED:-0}" -eq 1 ]; then
        local cleanup_msg="${MSG_CLEANUP_UI:-Cleaning UI library...}"
        if command -v show_progress >/dev/null 2>&1; then
            show_progress "$cleanup_msg"
        else
            echo "$cleanup_msg"
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
    local script_name="install-one-click.sh"

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
                    show_error "Неверный выбор / Invalid choice"
                    ;;
            esac
        done
    fi
    
    case ${LANG:-1} in
        1)
            MSG_INSTALL_TITLE="Запуск! ($script_name)"
            MSG_UPDATE_PKGS="Обновление пакетов и установка зависимостей..."
            MSG_DEPS_SUCCESS="Зависимости успешно установлены"
            MSG_DEPS_ERROR="Ошибка установки зависимостей"
            MSG_ROUTER_IP="Введите адрес роутера (по умолчанию 192.168.1.1, нажмите Enter): "
            MSG_ROUTER_PASS="Введите пароль для root (если нет пароля - нажмите Enter): "
            MSG_RESET_ROUTER="Сбросить настройки роутера перед установкой? [y/N]: "
            MSG_RESETTING="Сбрасываем настройки роутера..."
            MSG_REMOVE_KEY="Удаляем старый ключ хоста для"
            MSG_CONNECTING="Подключаемся к роутеру и выполняем установку..."
            MSG_COMPLETE="Выполнено! ($script_name)"
            MSG_CLEANUP_UI="Очистка UI библиотеки..."
            MSG_CLEANUP="Очистка и удаление скрипта..."
            MSG_CLEANUP_DONE="Готово! Скрипт удален."
            MSG_SSH_ERROR="Ошибка подключения к роутеру"
            MSG_RESET_COMPLETE="Сброс роутера выполнен"
            MSG_NETWORK_CHECK="Проверка подключения к интернету..."
            MSG_NETWORK_SUCCESS="Подключение восстановлено через %s (%d сек)"
            MSG_NETWORK_ERROR="Не удалось восстановить подключение после %d сек"
            MSG_WAITING_ROUTER="Ожидание восстановления связи с роутером..."
            MSG_ROUTER_AVAILABLE="Роутер доступен через %s (%d сек)"
            MSG_WAITING="Ожидание %d сек"
            MSG_ROUTER_NOT_AVAILABLE="Роутер %s не доступен после %d сек"
            MSG_BRANCH="Введите ветку (по умолчанию main, нажмите Enter): "
            MSG_INVALID_INPUT="Некорректный ввод"
            MSG_REPEAT_INPUT="Повторите ввод"
            ;;
        *)
            MSG_INSTALL_TITLE="Starting! ($script_name)"
            MSG_UPDATE_PKGS="Updating packages and installing dependencies..."
            MSG_DEPS_SUCCESS="Dependencies installed successfully"
            MSG_DEPS_ERROR="Error installing dependencies"
            MSG_ROUTER_IP="Enter router address (default 192.168.1.1, press Enter): "
            MSG_ROUTER_PASS="Enter root PASSWORD (if no PASSWORD - press Enter): "
            MSG_RESET_ROUTER="Reset router settings before installation? [y/N]: "
            MSG_RESETTING="Resetting router settings..."
            MSG_REMOVE_KEY="Removing old host key for"
            MSG_CONNECTING="Connecting to router and installing..."
            MSG_COMPLETE="Done! ($script_name)"
            MSG_CLEANUP_UI="Cleaning UI library..."
            MSG_CLEANUP="Cleaning up and removing script..."
            MSG_CLEANUP_DONE="Done! Script removed."
            MSG_SSH_ERROR="Failed to connect to router"
            MSG_RESET_COMPLETE="Router reset complete"
            MSG_NETWORK_CHECK="Checking internet connection..."
            MSG_NETWORK_SUCCESS="Connection restored via %s (%d sec)"
            MSG_NETWORK_ERROR="Failed to restore connection after %d sec"
            MSG_WAITING_ROUTER="Waiting for router to come back online..."
            MSG_ROUTER_AVAILABLE="Router available via %s (%d sec)"
            MSG_WAITING="Waiting %d sec"
            MSG_ROUTER_NOT_AVAILABLE="Router %s not available after %d sec"
            MSG_BRANCH="Enter BRANCH (default main, press Enter): "
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
    if opkg update && opkg install openssh-sftp-server; then
        show_success "$MSG_DEPS_SUCCESS"
    else
        show_error "$MSG_DEPS_ERROR"
        exit 1
    fi
}

# Ожидание связи с роутером / Waiting for router connection
wait_for_router() {
    local timeout=1000
    local interval=5
    local attempts=$((timeout/interval))
    
    show_progress "$MSG_WAITING_ROUTER"
    
    for ((i=1; i<=attempts; i++)); do
        if ping -c 1 -W 2 "$ROUTER_IP" >/dev/null 2>&1; then
            show_success "$(printf "$MSG_ROUTER_AVAILABLE" "$ROUTER_IP" "$((i*interval))")"
            return 0
        fi
        sleep $interval
    done
    
    show_error "$(printf "$MSG_ROUTER_NOT_AVAILABLE" "$ROUTER_IP" "$timeout")"
    return 1
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


# Сброс роутера / Reset router
reset_router() {
    show_progress "$MSG_RESETTING"
    if [ -z "$PASSWORD" ]; then
        if ! ssh -o "StrictHostKeyChecking no" "root@$ROUTER_IP" "firstboot -y && reboot now"; then
            show_error "$MSG_SSH_ERROR"
            return 1
        fi
    else
        if ! sshpass -p "$PASSWORD" ssh -o "StrictHostKeyChecking no" "root@$ROUTER_IP" "firstboot -y && reboot now"; then
            show_error "$MSG_SSH_ERROR"
            return 1
        fi
    fi
    show_success "$MSG_RESET_COMPLETE"
    return 0
}

# Запрос данных / Input data
input_data() {
    read_input "${MSG_ROUTER_IP}" ROUTER_IP
    ROUTER_IP="${ROUTER_IP:-192.168.1.1}"
    read_input_secret "${MSG_ROUTER_PASS}" PASSWORD
    read_input "${MSG_BRANCH}" BRANCH
}

# Запрос на сброс роутера / Ask for router reset
clear_router() {
    while true; do
        read_input "$MSG_RESET_ROUTER" RESET_CHOICE
        case "$RESET_CHOICE" in
          [Yy]|[Nn]|"")
            case "$RESET_CHOICE" in
              [Yy])
                if reset_router; then
                    waiting 60 && wait_for_router && network_check
                else
                    exit 1
                fi
                ;;
            esac
            break
            ;;
          *)
            show_error "$MSG_INVALID_INPUT. $MSG_REPEAT_INPUT"
            ;;
        esac
    done
}

# Удаление старого ключа / Remove old key
remove_old_key() {
    show_progress "${MSG_REMOVE_KEY} ${ROUTER_IP}"
    ssh-keygen -R "$ROUTER_IP" 2>/dev/null
}

# Подключение и установка / Connect and install
connect_and_install() {
    show_progress "$MSG_CONNECTING"

    local install_script_name="install.sh"
    local remote_cmd="
        export LANG=$LANG
        export BRANCH=$BRANCH
        wget -O /root/$install_script_name https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/$BRANCH/$install_script_name
        chmod 0755 /root/$install_script_name
        sh /root/$install_script_name
    "

    if [ -z "$PASSWORD" ]; then
        ssh -t -o "StrictHostKeyChecking no" "root@$ROUTER_IP" "$remote_cmd" || {
            show_error "$MSG_SSH_ERROR"
            exit 1
        }
    else
        sshpass -p "$PASSWORD" ssh -t -o "StrictHostKeyChecking no" "root@$ROUTER_IP" "$remote_cmd" || {
            show_error "$MSG_SSH_ERROR"
            exit 1
        }
    fi
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

run_steps_with_separator \
    init_language

run_steps_with_separator \
    "::$MSG_INSTALL_TITLE" \
    update_pkgs \
    input_data \
    clear_router \
    remove_old_key \
    connect_and_install \
    complete_script