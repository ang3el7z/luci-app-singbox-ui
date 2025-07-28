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

# Ввод скрытый / Input hidden
read_input_secret() {
    echo -ne "${FG_USER_COLOR}${INDENT}${ARROW_CLEAR} $1${RESET} "
    if [ -n "$2" ]; then
        read -s "$2" 
    else
        read -s REPLY 
    fi
    echo
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
        if [[ "$step" == "::"* ]]; then
            local text="${step:2}"
            separator
            separator "$text"
            separator
        else
            $step
            separator
            echo
        fi
    done
}

# Инициализация языка / Language initialization
init_language() {
    local script_name="install-one-click.sh"

    if [ -z "$LANG_CHOICE" ]; then
        show_message "Выберите язык / Select language [1/2]:"
        show_message "1. Русский (Russian)"
        show_message "2. English (Английский)"
        read_input " Ваш выбор / Your choice [1/2]: " LANG_CHOICE
    fi
    
    case ${LANG_CHOICE:-1} in
        1)
            MSG_INSTALL_TITLE="Запуск! ($script_name)"
            MSG_ROUTER_IP="Введите адрес роутера (по умолчанию 192.168.1.1, нажмите Enter): "
            MSG_ROUTER_PASS="Введите пароль для root (если нет пароля - нажмите Enter): "
            MSG_RESET_ROUTER="Сбросить настройки роутера перед установкой? [y/N]: "
            MSG_RESETTING="Сбрасываем настройки роутера..."
            MSG_REMOVE_KEY="Удаляем старый ключ хоста для"
            MSG_CONNECTING="Подключаемся к роутеру и выполняем установку..."
            MSG_COMPLETE="Выполнено! ($script_name)"
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
            ;;
        *)
            MSG_INSTALL_TITLE="Starting! ($script_name)"
            MSG_ROUTER_IP="Enter router address (default 192.168.1.1, press Enter): "
            MSG_ROUTER_PASS="Enter root password (if no password - press Enter): "
            MSG_RESET_ROUTER="Reset router settings before installation? [y/N]: "
            MSG_RESETTING="Resetting router settings..."
            MSG_REMOVE_KEY="Removing old host key for"
            MSG_CONNECTING="Connecting to router and installing..."
            MSG_COMPLETE="Done! ($script_name)"
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
            MSG_BRANCH="Enter branch (default main, press Enter): "
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
    opkg update && opkg install openssh-sftp-server
    if [ $? -eq 0 ]; then
        show_success "$MSG_DEPS_SUCCESS"
    else
        show_error "$MSG_DEPS_ERROR"
        exit 1
    fi
}

# Ожидание связи с роутером / Waiting for router connection
wait_for_router() {
    local timeout=300
    local interval=5
    local attempts=$((timeout/interval))
    
    show_progress "$MSG_WAITING_ROUTER"
    
    for ((i=1; i<=attempts; i++)); do
        if ping -c 1 -W 2 "$router_ip" >/dev/null 2>&1; then
            show_success "$(printf "$MSG_ROUTER_AVAILABLE" "$router_ip" "$((i*interval))")"
            return 0
        fi
        sleep $interval
    done
    
    show_error "$(printf "$MSG_ROUTER_NOT_AVAILABLE" "$router_ip" "$timeout")"
    return 1
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

    while [ $i -le $attempts ]; do
        num_targets=$(echo "$targets" | wc -w)
        index=$((i % num_targets))
        if [ $index -eq 0 ]; then
            index=$num_targets
        fi
        target=$(echo "$targets" | cut -d' ' -f$index)

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


# Сброс роутера / Reset router
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

# Запрос данных / Input data
input_data() {
    read_input "${MSG_ROUTER_IP}" router_ip
    router_ip="${router_ip:-192.168.1.1}"
    read_input_secret "${MSG_ROUTER_PASS}" password
    read_input "${MSG_BRANCH}" branch
}

# Запрос на сброс роутера / Ask for router reset
clear_router() {
    read_input "$MSG_RESET_ROUTER" reset_choice
    if [[ "$reset_choice" =~ ^[Yy]$ ]]; then
        if reset_router; then
            waiting && wait_for_router && network_check
        else
            exit 1
        fi
    fi
}

# Удаление старого ключа / Remove old key
remove_old_key() {
    show_progress "${MSG_REMOVE_KEY} ${router_ip}"
    ssh-keygen -R "$router_ip" 2>/dev/null
}

# Подключение и установка / Connect and install
connect_and_install() {
    show_progress "$MSG_CONNECTING"

    local install_script_name="install.sh"

    if [ -z "$password" ]; then
        ssh -t -o "StrictHostKeyChecking no" "root@$router_ip" \
             export LANG_CHOICE=$LANG_CHOICE; \
             wget -O /root/$install_script_name https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/main/$install_script_name && \
             chmod 0755 /root/$install_script_name && \
             sh /root/$install_script_name" || {
            show_error "$MSG_SSH_ERROR"
            exit 1
        }
    else
        sshpass -p "$password" ssh -t -o "StrictHostKeyChecking no" "root@$router_ip" \
             export LANG_CHOICE=$LANG_CHOICE; \
             wget -O /root/$install_script_name https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/main/$install_script_name && \
             chmod 0755 /root/$install_script_name && \
             sh /root/$install_script_name" || {
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