#!/bin/sh
BRANCH="${BRANCH:-main}"

# Цветовая палитра / Color palette
FG_ACCENT='\033[38;5;85m'
FG_WARNING='\033[38;5;214m'
FG_SUCCESS='\033[38;5;41m'
FG_ERROR='\033[38;5;203m'
RESET='\033[0m'
FG_USER_COLOR='\033[38;5;117m'

# Символы оформления / Decorations
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

# Предупреждение / Warning
show_warning() {
    echo -e "${INDENT}! ${FG_WARNING}$1${RESET}\n"
}

# Сообщение / Message
show_message() {
    echo -e "${FG_USER_COLOR}${INDENT}${ARROW} $1${RESET}"
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
    local script_name="install.sh"

    if [ -z "$LANG" ]; then
        show_message "Выберите язык / Select language [1/2]:"
        show_message "1. Русский (Russian)"
        show_message "2. English (Английский)"
        read_input " Ваш выбор / Your choice [1/2]: " LANG
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
        MSG_FINISHED="Все инструкции выполнены!"
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
        MSG_INVALID_INPUT="Некорректный ввод"
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
        MSG_FINISHED="All instructions completed!"
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
        MSG_INVALID_INPUT="Invalid input"
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
        read_input "$MSG_INSTALL_SFTP_SERVER" SFTP_SERVER
        if [ -z "$SFTP_SERVER" ]; then
            SFTP_SERVER="n"
        fi
    fi

    case $SFTP_SERVER in
    y)
        if opkg update && opkg install openssh-sftp-server; then
            show_success "$MSG_DEPS_SUCCESS"
        else
            show_error "$MSG_DEPS_ERROR"
            exit 1
        fi
        ;;
    n)
        if opkg update; then
            show_success "$MSG_DEPS_SUCCESS"
        else
            show_error "$MSG_DEPS_ERROR"
            exit 1
        fi
        ;;
    *)
        show_error "$MSG_DEPS_ERROR"
        exit 1
        ;;
    esac
}


# Выбор операции установки / Choose install operation
choose_install_operation() {
    if [ -z "$OPERATION" ]; then
        show_message "$MSG_OPERATION"
        show_message "$MSG_OPERATION_INSTALL"
        show_message "$MSG_OPERATION_DELETE"
        show_message "$MSG_OPERATION_REINSTALL_UPDATE"
        read_input "$MSG_OPERATION_CHOICE" OPERATION
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

    wget -O /root/install-singbox.sh https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/$BRANCH/other/install-singbox.sh &&
    chmod 0755 /root/install-singbox.sh &&
    LANG="$LANG" OPERATION="$OPERATION" sh /root/install-singbox.sh

    show_warning "$MSG_SINGBOX_RETURN"
}

# Установка singbox-ui / singbox-ui installation
install_singbox_ui_script() {
    show_warning "$MSG_SINGBOX_UI_INSTALL"

    wget -O /root/install-singbox-ui.sh https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/$BRANCH/other/install-singbox-ui.sh &&
    chmod 0755 /root/install-singbox-ui.sh &&
    LANG="$LANG" OPERATION="$OPERATION" sh /root/install-singbox-ui.sh

    show_warning "$MSG_SINGBOX_RETURN"
}

# Выбор варианта установки / Choose installation variant
choose_action() {
    if [ -z "$ACTION_CHOICE" ]; then
        show_message "$MSG_INSTALL_ACTION"
        show_message "$MSG_INSTALL_SINGBOX_UI"
        show_message "$MSG_INSTALL_SINGBOX"
        show_message "$MSG_INSTALL_SINGBOX_UI_AND_SINGBOX"
        read_input "$MSG_INSTALL_ACTION_CHOICE" ACTION_CHOICE
    fi

    case "${ACTION_CHOICE:-2}" in
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
        *)
            show_error "$MSG_INVALID_INPUT"
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
    separator "$MSG_FINISHED"
    cleanup
}

# ======== Основной код / Main code ========

run_steps_with_separator \
    "::${BRANCH}" \
    init_language

run_steps_with_separator \
    "::$MSG_INSTALL_TITLE" \
    update_pkgs \
    choose_install_operation \
    choose_action \
    complete_script
