#!/bin/sh

# Цветовая палитра (приглушенные тона) / Color palette (muted tones)
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
    local script_name="install-singbox-ui.sh"
    
    if [ -z "$LANG" ]; then
        show_message "Выберите язык / Select language [1/2]:"
        show_message "1. Русский (Russian)"
        show_message "2. English (Английский)"
        read_input " Ваш выбор / Your choice [1/2]: " LANG
    fi

    case ${LANG:-2} in
        1)
            MSG_INSTALL_TITLE="Запуск! ($script_name)"
            MSG_UPDATE_PKGS="Обновление пакетов и установка зависимостей..."
            MSG_DEPS_SUCCESS="Зависимости успешно установлены"
            MSG_DEPS_ERROR="Ошибка установки зависимостей"
            MSG_INSTALL_UI="Начало установки singbox-ui..."
            MSG_CHOOSE_VERSION="Выберите версию singbox-ui для установки:"
            MSG_OPTION_1="1) Latest (~150 Кб)"
            MSG_OPTION_2="2) Lite версия (~6 Кб)"
            MSG_OPTION_3="3) Pre-release (бета, возможны баги)"
            MSG_OPTION_4="4) Runner сборка из Pull Request (тестовая)"
            MSG_INVALID_CHOICE="Некорректный выбор, выбрана версия Latest по умолчанию."
            MSG_INSTALL_COMPLETE="Установка завершена"
            MSG_CLEANUP="Очистка файлов..."
            MSG_CLEANUP_DONE="Файлы удалены!"
            MSG_SELECT_RUNNER="Выберите Runner сборку для установки:"
            MSG_NO_PRE_RELEASE="Не удалось получить pre-release, используем latest."
            MSG_RUNNER_INDEX_UNAVAILABLE="Не удалось загрузить список runner сборок (index.txt)."
            MSG_RUNNER_LIST_EMPTY="Список runner сборок пуст."
            MSG_INVALID_CHOICE="Неверный выбор. Установлена последняя доступная сборка."
            MSG_INSTALL_LATEST="Устанавливается последняя доступная сборка (latest)..."
            MSG_DOWNLOAD_ERROR="Ошибка загрузки файла. Установка прервана."
            MSG_WAITING="Ожидание %d сек"
            MSG_YOUR_CHOICE="Ваш выбор: "
            MSG_COMPLETE="Выполнено! ($script_name)"
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
            MSG_OPERATION="Выберите тип операции:"
            MSG_OPERATION_INSTALL="1. Установка"
            MSG_OPERATION_DELETE="2. Удаление"
            MSG_OPERATION_REINSTALL_UPDATE="3. Переустановка/Обновление"
            MSG_OPERATION_CHOICE=" Ваш выбор: "
            MSG_ALREADY_INSTALLED="Ошибка: Пакет уже установлен. Если устанавливали этим скриптом - выберите переустановку (3). Иначе выполните сброс роутера."
            MSG_UNINSTALLING="Удаление singbox-ui..."
            MSG_UNINSTALL_SUCCESS="Удаление завершено"
            MSG_NOT_INSTALLED="Ошибка: Пакет не установлен. Нечего удалять."
            MSG_INVALID_OPERATION="Ошибка: Некорректная операция"
            MSG_NETWORK_CHECK="Проверка доступности сети..."
            MSG_NETWORK_SUCCESS="Сеть доступна (через %s, за %s сек)"
            MSG_NETWORK_ERROR="Сеть не доступна после %s сек!"
            MSG_RELOAD_SERVICE="Обновить конфигурацию sing-box..."
            MSG_SERVICE_RELOADED="Конфигурация sing-box обновлена"
            ;;
        *)
            MSG_INSTALL_TITLE="Starting! ($script_name)"
            MSG_UPDATE_PKGS="Updating packages and installing dependencies..."
            MSG_DEPS_SUCCESS="Dependencies installed successfully"
            MSG_DEPS_ERROR="Error installing dependencies"
            MSG_INSTALL_UI="Starting singbox-ui installation..."
            MSG_CHOOSE_VERSION="Select singbox-ui version to install:"
            MSG_OPTION_1="1) Latest (~150 KB)"
            MSG_OPTION_2="2) Lite version (~6 KB)"
            MSG_OPTION_3="3) Pre-release (beta, may have bugs)"
            MSG_OPTION_4="4) Runner build from Pull Request (testing)"
            MSG_INSTALL_COMPLETE="Installation complete"
            MSG_CLEANUP="Cleaning up files..."
            MSG_CLEANUP_DONE="Files removed!"
            MSG_SELECT_RUNNER="Select Runner build to install:"
            MSG_NO_PRE_RELEASE="Failed to fetch pre-release, using latest."
            MSG_RUNNER_INDEX_UNAVAILABLE="Failed to load runner build list (index.txt)."
            MSG_RUNNER_LIST_EMPTY="Runner build list is empty."
            MSG_INVALID_CHOICE="Invalid choice. Installing latest available build."
            MSG_INSTALL_LATEST="Installing stable version latest"
            MSG_DOWNLOAD_ERROR="Download failed. Installation aborted."
            MSG_WAITING="Waiting %d sec"
            MSG_YOUR_CHOICE="Your choice: "
            MSG_COMPLETE="Completed! ($script_name)"
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
            MSG_OPERATION="Select install operation:"
            MSG_OPERATION_INSTALL="1. Install"
            MSG_OPERATION_DELETE="2. Delete"
            MSG_OPERATION_REINSTALL_UPDATE="3. Reinstall/Update"
            MSG_OPERATION_CHOICE="Your choice: "
            MSG_ALREADY_INSTALLED="Error: Package already installed. If installed via this script - choose reinstall (3). Otherwise reset the router."
            MSG_UNINSTALLING="Uninstalling singbox-ui..."
            MSG_UNINSTALL_SUCCESS="Uninstall completed"
            MSG_NOT_INSTALLED="Error: Package not installed. Nothing to remove."
            MSG_INVALID_OPERATION="Error: Invalid operation"
            MSG_NETWORK_CHECK="Checking network availability..."
            MSG_NETWORK_SUCCESS="Network available (via %s, in %s sec)"
            MSG_NETWORK_ERROR="Network not available after %s sec!"
            MSG_RELOAD_SERVICE="Reload configuration sing-box..."
            MSG_SERVICE_RELOADED="Configuration sing-box reloaded"
            ;;
    esac
}

waiting() {
    local interval="${1:-30}"
    show_progress "$(printf "$MSG_WAITING" "$interval")"
    sleep "$interval"
}

# Обновление репозиториев и установка зависимостей / Update repos and install dependencies
update_pkgs() {
    show_progress "$MSG_UPDATE_PKGS"
    if opkg update && opkg install curl jq && (opkg install nano || opkg install nano-full); then
        show_success "$MSG_DEPS_SUCCESS"
    else
        show_error "$MSG_DEPS_ERROR"
        exit 1
    fi
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

# Выбор версии для установки / Version selection
choose_install_version() {
    show_message "$MSG_CHOOSE_VERSION"
    show_message "$MSG_OPTION_1"
    show_message "$MSG_OPTION_2"
    show_message "$MSG_OPTION_3"
    show_message "$MSG_OPTION_4"
    read_input "$MSG_YOUR_CHOICE" VERSION_CHOICE

    # Ссылки на файлы для каждой версии / URLs for each version
    local url_latest="https://github.com/ang3el7z/luci-app-singbox-ui/releases/latest/download/luci-app-singbox-ui.ipk"
    local url_lite="https://github.com/ang3el7z/luci-app-singbox-ui/releases/download/v1.2.1/luci-app-singbox-ui.ipk"

    case "$VERSION_CHOICE" in
    1)
        DOWNLOAD_URL="$url_latest"
        ;;
    2)
        DOWNLOAD_URL="$url_lite"
        ;;
    3)
        # Получаем ссылку на последнюю pre-release сборку / Fetch latest pre-release build  
        DOWNLOAD_URL=$(curl -s https://api.github.com/repos/ang3el7z/luci-app-singbox-ui/releases | \
        grep -A 20 '"prerelease": true' | \
        grep "browser_download_url.*luci-app-singbox-ui.ipk" | \
        head -n 1 | \
        sed -E 's/.*"browser_download_url": *"([^"]+)".*/\1/')

        if [ -z "$DOWNLOAD_URL" ]; then
            show_error "$MSG_NO_PRE_RELEASE"
            DOWNLOAD_URL="$url_latest"
        fi
        ;;
    4)
        local runner_base_url="https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/main/artifacts"
        local index_url="$runner_base_url/index.txt"

        show_progress "$MSG_SELECT_RUNNER"

        # Получаем список runner сборок с проверкой / Get list of runner builds with validation
        local http_code=$(curl -s -o /tmp/index.txt -w "%{http_code}" "$index_url")
        if [ "$http_code" != "200" ]; then
            show_error "$MSG_RUNNER_INDEX_UNAVAILABLE"
            show_progress "$MSG_INSTALL_LATEST"
            DOWNLOAD_URL="$url_latest"
            return
        fi

        local runner_files=$(cat /tmp/index.txt)

        if [ -z "$runner_files" ]; then
            show_error "$MSG_RUNNER_LIST_EMPTY"
            show_progress "$MSG_INSTALL_LATEST"
            DOWNLOAD_URL="$url_latest"
            return
        fi

        local i=1
        for file in $runner_files; do
            show_message "  [$i] $file"
            eval RUNNER_$i="'$file'"
            i=$((i+1))
        done

        read_input "$MSG_YOUR_CHOICE" CHOICE

        eval selected_runner_file=\$RUNNER_"$CHOICE"

        if [ -z "$selected_runner_file" ]; then
            show_error "$MSG_INVALID_CHOICE"
            DOWNLOAD_URL="$url_latest"
        else
            DOWNLOAD_URL="$runner_base_url/$selected_runner_file"
        fi
        ;;
    *)
        show_error "$MSG_INVALID_CHOICE"
        DOWNLOAD_URL="$url_latest"
        ;;
    esac
}

# Установка singbox-ui / Install singbox-ui
install_singbox_ui() {
    show_progress "$MSG_INSTALL_UI"
    if ! wget -O /root/luci-app-singbox-ui.ipk "$DOWNLOAD_URL"; then
        show_error "$MSG_DOWNLOAD_ERROR"
        exit 1
    fi
    chmod 0755 /root/luci-app-singbox-ui.ipk
    opkg update
    opkg install /root/luci-app-singbox-ui.ipk
    /etc/init.d/uhttpd restart
    show_success "$MSG_INSTALL_COMPLETE"
}

# Получение конфигурации / Configuration download
get_config() {
    if [ -z "$CONFIG_URL" ]; then
        read_input "${MSG_CONFIG_PROMPT}" CONFIG_URL
    fi

    local is_auto_config=0
    # Проверяем, что URL не пустой / Check if URL is not empty
    if [ -n "$CONFIG_URL" ]; then
        local max_attempts=3
        local attempt=1
        local success=0

        # Загрузка конфигурации / Configuration download
        while [ $attempt -le $max_attempts ]; do
            show_progress "$(printf "$MSG_CONFIG_LOADING" "$CONFIG_URL" "$attempt" "$max_attempts")"
            
            # Проверка JSON / JSON validation
            if RAW_JSON=$(curl -fsS "$CONFIG_URL" 2>/dev/null) && [ -n "$RAW_JSON" ]; then
                if FORMATTED_JSON=$(echo "$RAW_JSON" | jq -e '.' 2>/dev/null); then
                    echo "$FORMATTED_JSON" > /etc/sing-box/config.json
                    echo "$CONFIG_URL" > "/etc/sing-box/url_config.json"
                    show_success "$MSG_CONFIG_SUCCESS"
                    is_auto_config=1
                    success=1
                    break
                else
                    show_error "$MSG_FORMAT_ERROR"
                fi
            else
                show_error "$(printf "$MSG_CONFIG_ERROR" "${RAW_JSON:-"Unknown error"}")"
            fi

            if [ $attempt -lt $max_attempts ]; then
                show_progress "$MSG_RETRY"
                network_check
            fi
        
            attempt=$((attempt + 1))
        done

        if [ $success -eq 0 ]; then
            show_error "$MSG_MANUAL_CONFIG"
            export TERM=xterm
            nano /etc/sing-box/config.json || {
                show_error "Failed to open editor. Please check your terminal settings."
                exit 1
            }
        fi
    else
        show_error "$MSG_MANUAL_CONFIG"
        export TERM=xterm
        nano /etc/sing-box/config.json || {
            show_error "Failed to open editor. Please check your terminal settings."
            exit 1
        }
    fi

    # Проверка ручной конфигурации / Manual configuration check
    if [ "$is_auto_config" -ne 1 ]; then
        while true; do
            read_input "${MSG_EDIT_COMPLETE}" edit_choice
            case "${edit_choice:-Y}" in
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
}

# Удаление существующих файлов / Remove existing files
uninstall_existing_files(){
    show_progress "$MSG_UNINSTALL_EXISTING_FILES"
    [ -f /etc/config/singbox-ui.old ] && rm -f /etc/config/singbox-ui.old
}

# Reload sing-box / Reload sing-box
reload_singbox() {
    show_progress "$MSG_RELOAD_SERVICE"
    service sing-box reload
    show_success "$MSG_SERVICE_RELOADED"
}

# Проверка установки / Check installation
check_installed() {
    opkg list-installed | grep -q "luci-app-singbox-ui"
    return $?
}

# Удаление singbox-ui / Uninstall singbox-ui
uninstall_singbox_ui() {
    show_progress "$MSG_UNINSTALLING"
    opkg remove luci-app-singbox-ui
    /etc/init.d/uhttpd restart
    show_success "$MSG_UNINSTALL_SUCCESS"
}

# Установка / Install
install() {
    choose_install_version
    install_singbox_ui
    get_config
    reload_singbox
}

# Удаление / Uninstall
uninstall() {
    uninstall_singbox_ui
    uninstall_existing_files
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
    rm -f /root/luci-app-singbox-ui.ipk
    rm -f -- "$0"
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
