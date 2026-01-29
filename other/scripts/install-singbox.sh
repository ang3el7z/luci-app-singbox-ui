#!/bin/sh
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
    local script_name="install-singbox.sh"

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
            MSG_CLEANUP_UI="Очистка UI библиотеки..."
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
            MSG_TPROXY="2. TPROXY (в разработке)"
            MSG_MODE_CHOICE="Ваш выбор: "
            MSG_INSTALLING_TPROXY_MODE="Установка TPROXY режима..."
            MSG_UNINSTALLING_TPROXY_MODE="Удаление TPROXY режима..."
            MSG_TPROXY_ROUTE_SETUP="Настройка policy routing для TPROXY..."
            MSG_TPROXY_ROUTE_CLEANUP="Удаление policy routing для TPROXY..."
            MSG_TPROXY_NFT_INSTALL="Установка nftables (nft) для TPROXY..."
            MSG_TPROXY_NFT_INSTALLED="nftables успешно установлен"
            MSG_TPROXY_NFT_ERROR="Не удалось установить nftables"
            MSG_INSTALLING_TUN_MODE="Установка TUN режима..."
            MSG_UNINSTALLING_TUN_MODE="Удаление TUN режима..."
            MSG_TUN_DEPS_INSTALL="Установка зависимостей для TUN режима..."
            MSG_TUN_DEPS_INSTALLED="Зависимости для TUN режима установлены"
            MSG_TUN_DEPS_ALREADY="Зависимости для TUN режима уже установлены"
            MSG_TUN_DEPS_ERROR="Ошибка установки зависимостей для TUN режима"
            MSG_UNINSTALL_EXISTING_FILES="Удаление существующих файлов sing-box..."
            MSG_INVALID_MODE="Ошибка: Некорректный режим"
            MSG_INVALID_MODE_FOUND="Ошибка: Не найден режим для удаления."
            MSG_MODE_FOUND_TPROXY="Найден TPROXY режим"
            MSG_MODE_FOUND_TUN="Найден TUN режим"
            MSG_NET_CHOOSE="Выберите способ перезапуска сети:"
            MSG_NET_OPTION1="1) Безопасный reload (рекомендуется при работе через Wi-Fi или CMD/командной строке)"
            MSG_NET_OPTION2="2) Полный restart сервиса (подходит для современных SSH-клиентов)"
            MSG_NET_PROMPT="Ваш выбор [1/2] (2 дефолт): "
            MSG_SINGBOX_CHOOSE="Выберите способ установки sing-box:"
            MSG_SINGBOX_OPTION1="1) Установить последнюю версию из магазина"
            MSG_SINGBOX_OPTION2="2) Ручная установка"
            MSG_SINGBOX_PROMPT="Введите ваш выбор [1-2]:"
            MSG_SINGBOX_MANUAL_INSTRUCTIONS="Инструкция по ручной установке:"
            MSG_SINGBOX_MANUAL_STEP_1="1. Загрузите sing-box.ipk из вашего репозитория"
            MSG_SINGBOX_MANUAL_STEP_2="2. Загрузите файл в папку /tmp на устройство OpenWrt"
            MSG_SINGBOX_MANUAL_STEP_3="3. Нажмите 1 для продолжения установки"
            MSG_SINGBOX_FILE_NOT_FOUND="Файлы sing-box*.ipk не найдены в /tmp!"
            MSG_SINGBOX_UPLOAD_INSTRUCTIONS="Пожалуйста, загрузите файл сначала!"
            MSG_SINGBOX_FILE_FOUND="Найден файл:"
            MSG_SINGBOX_MULTIPLE_FILES_FOUND="Найдено несколько файлов. Выберите один:"
            MSG_SINGBOX_SELECT_FILE="Выберите файл [1-N]:"
            MSG_SINGBOX_CONFIRM_PROMPT="Установить выбранный файл? [1-Да, 2-Использовать магазин]:"
            MSG_INVALID_INPUT="Ошибка: Некорректный ввод"
            MSG_SINGBOX_ERROR_OPTIONS="Выберите действие после ошибки:"
            MSG_SINGBOX_TRY_ANOTHER_FILE="Попробовать другой файл"
            MSG_SINGBOX_USE_STORE="Использовать магазин"
            MSG_SINGBOX_EXIT="Выйти"
            MSG_SINGBOX_ERROR_CHOICE="Ваш выбор [1-3]: "
            MSG_SINGBOX_DOWNLOAD_MENU_OPTION1="1) Скачать sing-box_1.11.15 автоматически в /tmp"
            MSG_SINGBOX_DOWNLOAD_MENU_OPTION2="2) $MSG_SINGBOX_USE_STORE"
            MSG_SINGBOX_DOWNLOAD_MENU_OPTION3="3) Повторить поиск файла (ручная загрузка)"
            MSG_SINGBOX_DOWNLOAD_PROMPT="Выберите действие [1-3]: "
            MSG_SINGBOX_DOWNLOAD_START="Загрузка sing-box_1.11.15 в /tmp..."
            MSG_SINGBOX_DOWNLOAD_SUCCESS="Файл sing-box_1.11.15 успешно загружен в /tmp."
            MSG_SINGBOX_DOWNLOAD_ERROR="Не удалось скачать файл sing-box_1.11.15. Проверьте подключение к интернету."
            MSG_INVALID_INPUT="Ошибка: Некорректный ввод"
            MSG_REPEAT_INPUT="Повторите ввод"
            ;;
        *)
            MSG_INSTALL_TITLE="Starting! ($script_name)"
            MSG_UPDATE_PKGS="Updating repositories..."
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
            MSG_CLEANUP_UI="Cleaning UI library..."
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
            MSG_TPROXY="2. TPROXY (in development)"
            MSG_MODE_CHOICE="Your choice: "
            MSG_INSTALLING_TPROXY_MODE="Installing TPROXY mode..."
            MSG_UNINSTALLING_TPROXY_MODE="Uninstalling TPROXY mode..."
            MSG_TPROXY_ROUTE_SETUP="Configuring TPROXY policy routing..."
            MSG_TPROXY_ROUTE_CLEANUP="Removing TPROXY policy routing..."
            MSG_TPROXY_NFT_INSTALL="Installing nftables (nft) for TPROXY..."
            MSG_TPROXY_NFT_INSTALLED="nftables installed successfully"
            MSG_TPROXY_NFT_ERROR="Failed to install nftables"
            MSG_INSTALLING_TUN_MODE="Installing TUN mode..."
            MSG_UNINSTALLING_TUN_MODE="Uninstalling TUN mode..."
            MSG_TUN_DEPS_INSTALL="Installing TUN mode dependencies..."
            MSG_TUN_DEPS_INSTALLED="TUN mode dependencies installed"
            MSG_TUN_DEPS_ALREADY="TUN mode dependencies already installed"
            MSG_TUN_DEPS_ERROR="Failed to install TUN mode dependencies"
            MSG_UNINSTALL_EXISTING_FILES="Uninstalling existing sing-box files..."
            MSG_INVALID_MODE="Error: Invalid mode"
            MSG_INVALID_MODE_FOUND="Error: Mode not found for removal."
            MSG_MODE_FOUND_TPROXY="TPROXY mode found"
            MSG_MODE_FOUND_TUN="TUN mode found"
            MSG_NET_CHOOSE="Choose the network restart method:"
            MSG_NET_OPTION1="1) Safe reload (recommended when connected via Wi-Fi or CMD/Command Prompt)"
            MSG_NET_OPTION2="2) Full network service restart (suitable for modern SSH clients)"
            MSG_NET_PROMPT="Your choice [1/2] (2 default): "
            MSG_SINGBOX_CHOOSE="Choose sing-box installation method:"
            MSG_SINGBOX_OPTION1="1) Install latest version from store"
            MSG_SINGBOX_OPTION2="2) Manual install"
            MSG_SINGBOX_PROMPT="Enter your choice [1-2]:"
            MSG_SINGBOX_MANUAL_INSTRUCTIONS="Manual Installation Instructions:"
            MSG_SINGBOX_MANUAL_STEP_1="1. Download the sing-box.ipk from your repository"
            MSG_SINGBOX_MANUAL_STEP_2="2. Upload the file to the /tmp folder on your OpenWrt device"
            MSG_SINGBOX_MANUAL_STEP_3="3. Press 1 to continue the installation"
            MSG_SINGBOX_FILE_NOT_FOUND="No sing-box*.ipk files found in /tmp!"
            MSG_SINGBOX_UPLOAD_INSTRUCTIONS="Please upload the file first!"
            MSG_SINGBOX_FILE_FOUND="File found:"
            MSG_SINGBOX_MULTIPLE_FILES_FOUND="Multiple files found. Please select one:"
            MSG_SINGBOX_SELECT_FILE="Select file [1-N]:"
            MSG_SINGBOX_CONFIRM_PROMPT="Install the selected file? [1-Yes, 2-Use store]:"
            MSG_INVALID_INPUT="Error: Invalid input"
            MSG_SINGBOX_ERROR_OPTIONS="Choose action after error:"
            MSG_SINGBOX_TRY_ANOTHER_FILE="Try another file"
            MSG_SINGBOX_USE_STORE="Use store"
            MSG_SINGBOX_EXIT="Exit"
            MSG_SINGBOX_ERROR_CHOICE="Your choice [1-3]: "
            MSG_SINGBOX_DOWNLOAD_MENU_OPTION1="1) Download sing-box_1.11.15 automatically to /tmp"
            MSG_SINGBOX_DOWNLOAD_MENU_OPTION2="2) $MSG_SINGBOX_USE_STORE"
            MSG_SINGBOX_DOWNLOAD_MENU_OPTION3="3) Retry file search (manual upload)"
            MSG_SINGBOX_DOWNLOAD_PROMPT="Choose action [1-3]: "
            MSG_SINGBOX_DOWNLOAD_START="Downloading sing-box_1.11.15 to /tmp..."
            MSG_SINGBOX_DOWNLOAD_SUCCESS="sing-box_1.11.15 downloaded to /tmp successfully."
            MSG_SINGBOX_DOWNLOAD_ERROR="Failed to download sing-box_1.11.15. Please check your internet connection."
            MSG_INVALID_INPUT="Error: Invalid input"
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

# Обновление репозиториев / Update repos
update_pkgs() {
    show_progress "$MSG_UPDATE_PKGS"
    if opkg update; then
      show_success "$MSG_PKGS_SUCCESS"
    else
      show_error "$MSG_PKGS_ERROR"
      exit 1
    fi
}

ensure_nft_available() {
    if command -v nft >/dev/null 2>&1; then
        return 0
    fi
    if [ -x /usr/sbin/nft ] || [ -x /sbin/nft ]; then
        return 0
    fi
    show_progress "$MSG_TPROXY_NFT_INSTALL"
    if opkg install nftables; then
        show_success "$MSG_TPROXY_NFT_INSTALLED"
        return 0
    fi
    show_error "$MSG_TPROXY_NFT_ERROR"
    exit 1
}

install_mode_deps() {
    case $MODE in
        1)
            show_progress "$MSG_TUN_DEPS_INSTALL"
            if opkg list-installed | grep -q "^kmod-tun "; then
                show_success "$MSG_TUN_DEPS_ALREADY"
                return 0
            fi
            if opkg install kmod-tun; then
                show_success "$MSG_TUN_DEPS_INSTALLED"
            else
                show_error "$MSG_TUN_DEPS_ERROR"
                exit 1
            fi
            ;;
        2)
            ensure_nft_available
            ;;
    esac
}

# Выбор операции установки / Choose install operation
choose_install_operation() {
    if [ -z "$OPERATION" ]; then
        while true; do
            show_message "$MSG_OPERATION"
            show_message "$MSG_INSTALL"
            show_message "$MSG_DELETE"
            show_message "$MSG_REINSTALL_UPDATE"
            read_input "$MSG_CHOICE" OPERATION
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

# Установка sing-box / Install sing-box
install_singbox() {
    show_progress "$MSG_INSTALL_SINGBOX"
    
    # Спросить только при первом использовании
    if [ -z "$SINGBOX_INSTALL_MODE" ]; then
        while true; do
            show_message ""
            show_message "$MSG_SINGBOX_CHOOSE"
            show_message "$MSG_SINGBOX_OPTION1"
            show_message "$MSG_SINGBOX_OPTION2"
            show_message ""
            read_input "$MSG_SINGBOX_PROMPT" SINGBOX_INSTALL_MODE
            case "$SINGBOX_INSTALL_MODE" in
                1|2)
                    break
                    ;;
                *)
                    show_error "$MSG_INVALID_INPUT. $MSG_REPEAT_INPUT"
                    ;;
            esac
        done
    fi

    if [ "$SINGBOX_INSTALL_MODE" = "1" ]; then
        # Установка из магазина
        show_progress "$MSG_INSTALL_SINGBOX"
        
        if opkg install sing-box; then
            show_success "$MSG_INSTALL_SINGBOX_SUCCESS"
        else
            show_error "$MSG_INSTALL_SINGBOX_ERROR"
            exit 1
        fi
    elif [ "$SINGBOX_INSTALL_MODE" = "2" ]; then
        # Ручная установка из /tmp
        manual_singbox_install
    fi
}

# Ручная установка sing-box / Manual sing-box installation
manual_singbox_install() {
    # Параметры дефолтной версии для авто-скачивания
    local SINGBOX_DEFAULT_IPK_NAME="sing-box_1.11.15_openwrt_aarch64_cortex-a53.ipk"
    local SINGBOX_DEFAULT_IPK_URL="https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/main/other/ipk/${SINGBOX_DEFAULT_IPK_NAME}"
    local SINGBOX_DEFAULT_IPK_DST="/tmp/${SINGBOX_DEFAULT_IPK_NAME}"

    while true; do
        show_message ""
        show_message "$MSG_SINGBOX_MANUAL_INSTRUCTIONS"
        show_message ""
        show_message "$MSG_SINGBOX_MANUAL_STEP_1"
        show_message "$MSG_SINGBOX_MANUAL_STEP_2"
        show_message "$MSG_SINGBOX_MANUAL_STEP_3"
        show_message ""
        
        # Найти все IPK файлы в /tmp
        local ipk_files=""
        local ipk_count=0
        
        if [ -d "/tmp" ]; then
            ipk_files=$(find /tmp -maxdepth 1 -name "sing-box*.ipk" -type f 2>/dev/null | sort)
            ipk_count=$(echo "$ipk_files" | grep -c . || true)
        fi
        
        # Если файлы не найдены
        if [ $ipk_count -eq 0 ] || [ -z "$ipk_files" ]; then
            show_error "$MSG_SINGBOX_FILE_NOT_FOUND"
            show_message "$MSG_SINGBOX_UPLOAD_INSTRUCTIONS"
            show_message ""
            show_message "$MSG_SINGBOX_DOWNLOAD_MENU_OPTION1"
            show_message "$MSG_SINGBOX_DOWNLOAD_MENU_OPTION2"
            show_message "$MSG_SINGBOX_DOWNLOAD_MENU_OPTION3"
            while true; do
                read_input "$MSG_SINGBOX_DOWNLOAD_PROMPT" RETRY_CHOICE
                case $RETRY_CHOICE in
                    1)
                        show_progress "$MSG_SINGBOX_DOWNLOAD_START"

                        # удалить старый, если был
                        [ -f "$SINGBOX_DEFAULT_IPK_DST" ] && rm -f "$SINGBOX_DEFAULT_IPK_DST"

                        if wget -O "$SINGBOX_DEFAULT_IPK_DST" "$SINGBOX_DEFAULT_IPK_URL"; then
                            show_success "$MSG_SINGBOX_DOWNLOAD_SUCCESS"
                            # после загрузки вернуться в начало цикла — теперь файл найдётся
                            break
                        else
                            show_error "$MSG_SINGBOX_DOWNLOAD_ERROR"
                            # вернуться к ручной загрузке/поиску
                            break
                        fi
                        ;;
                    2)
                        SINGBOX_INSTALL_MODE="1"
                        install_singbox
                        return
                        ;;
                    3)
                        # просто заново показать инструкции по ручной загрузке и повторить поиск
                        break
                        ;;
                    *)
                        show_error "$MSG_INVALID_INPUT. $MSG_REPEAT_INPUT"
                        ;;
                esac
            done
            [ "$RETRY_CHOICE" = "1" ] || [ "$RETRY_CHOICE" = "3" ] && continue
        fi

        local selected_file=""
        
        # Если найден только один файл
        if [ $ipk_count -eq 1 ]; then
            selected_file="$ipk_files"
            show_message "$MSG_SINGBOX_FILE_FOUND ${selected_file##*/}"
        else
            # Если найдено несколько файлов - показать выбор
            show_message "$MSG_SINGBOX_MULTIPLE_FILES_FOUND"
            show_message ""
            
            local i=1
            while IFS= read -r file; do
                if [ -n "$file" ]; then
                    show_message "$i) ${file##*/}"
                    i=$((i + 1))
                fi
            done <<EOF
$ipk_files
EOF
            
            show_message ""
            while true; do
                read_input "$MSG_SINGBOX_SELECT_FILE" SINGBOX_FILE_CHOICE
                # Проверка выбора
                if [ "$SINGBOX_FILE_CHOICE" -ge 1 ] && [ "$SINGBOX_FILE_CHOICE" -le $ipk_count ] 2>/dev/null; then
                    break
                else
                    show_error "$MSG_INVALID_INPUT. $MSG_REPEAT_INPUT"
                fi
            done
            
            selected_file=$(echo "$ipk_files" | sed -n "${SINGBOX_FILE_CHOICE}p")
        fi
        
        # Подтверждение установки
        while true; do
            read_input "$MSG_SINGBOX_CONFIRM_PROMPT" SINGBOX_MANUAL_CONFIRM
            case "$SINGBOX_MANUAL_CONFIRM" in
                1|2)
                    break
                    ;;
                *)
                    show_error "$MSG_INVALID_INPUT. $MSG_REPEAT_INPUT"
                    ;;
            esac
        done
        
        if [ "$SINGBOX_MANUAL_CONFIRM" = "1" ]; then
            show_progress "$MSG_INSTALL_SINGBOX"
            
            if opkg install "$selected_file"; then
                show_success "$MSG_INSTALL_SINGBOX_SUCCESS"
                rm -f "$selected_file"
                break
            else
                show_error "$MSG_INSTALL_SINGBOX_ERROR"
                
                show_message ""
                show_message "$MSG_SINGBOX_ERROR_OPTIONS"
                show_message "1) $MSG_SINGBOX_TRY_ANOTHER_FILE"
                show_message "2) $MSG_SINGBOX_USE_STORE"
                show_message "3) $MSG_SINGBOX_EXIT"
                while true; do
                    read_input "$MSG_SINGBOX_ERROR_CHOICE" ERROR_CHOICE
                    case $ERROR_CHOICE in
                        1)
                            rm -f "$selected_file"
                            break
                            ;;
                        2)
                            SINGBOX_INSTALL_MODE="1"
                            install_singbox
                            return
                            ;;
                        3)
                            exit 1
                            ;;
                    *)
                        show_error "$MSG_INVALID_INPUT. $MSG_REPEAT_INPUT"
                        ;;
                    esac
                done
                [ "$ERROR_CHOICE" = "1" ] && continue
            fi
        elif [ "$SINGBOX_MANUAL_CONFIRM" = "2" ]; then
            SINGBOX_INSTALL_MODE="1"
            install_singbox
            return
        else
            show_error "$MSG_INVALID_INPUT"
            continue
        fi
    done
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
    # Спросить только при первом использовании
    if [ -z "$RESTART_MODE" ]; then
        while true; do
            show_message ""
            show_message "$MSG_NET_CHOOSE"
            show_message "$MSG_NET_OPTION1"
            show_message "$MSG_NET_OPTION2"

            read_input "$MSG_NET_PROMPT" RESTART_MODE
            # Если пусто, используем значение по умолчанию (2)
            if [ -z "$RESTART_MODE" ]; then
                RESTART_MODE="2"
                break
            fi
            case "$RESTART_MODE" in
                1|2)
                    break
                    ;;
                *)
                    show_error "$MSG_INVALID_INPUT. $MSG_REPEAT_INPUT"
                    ;;
            esac
        done
    fi

    show_progress "$MSG_RESTART_NETWORK"

    if [ "$RESTART_MODE" = "1" ]; then
        # Безопасный reload: не рвёт Wi-Fi и слабые SSH-клиенты
        uci commit network
        /etc/init.d/network reload
        ifup proxy 2>/dev/null || true
    else
        # Полный restart: современные SSH-клиенты переподключатся
        service network restart
    fi
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

    mkdir -p /etc/nftables.d

    cat << 'EOF' > "$nft_rule_file"
define RESERVED_IP = {
    10.0.0.0/8,
    100.64.0.0/10,
    127.0.0.0/8,
    169.254.0.0/16,
    172.16.0.0/12,
    192.168.0.0/16,
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
    rm -f /etc/nftables.d/singbox.nft
}

# Настройка policy routing для TPROXY / Configure policy routing for TPROXY
setup_tproxy_routing() {
    show_progress "$MSG_TPROXY_ROUTE_SETUP"
    ip rule add fwmark 1 table 100 2>/dev/null || true
    ip route add local 0.0.0.0/0 dev lo table 100 2>/dev/null || true
}

# Удаление policy routing для TPROXY / Remove policy routing for TPROXY
cleanup_tproxy_routing() {
    show_progress "$MSG_TPROXY_ROUTE_CLEANUP"
    ip rule del fwmark 1 table 100 2>/dev/null || true
    ip route flush table 100 2>/dev/null || true
}

# Выбор режима / Choose mode
choose_mode() {
    if [ -z "$MODE" ]; then
        while true; do
            show_message "$MSG_MODE"
            show_message "$MSG_TUN"
            show_message "$MSG_TPROXY"
            read_input "$MSG_MODE_CHOICE" MODE
            case "$MODE" in
                1|2)
                    break
                    ;;
                *)
                    show_error "$MSG_INVALID_MODE. $MSG_REPEAT_INPUT"
                    ;;
            esac
        done
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
    enable_singbox
    setup_tproxy_routing
    install_nft_rule
    network_check
}

# Удаление tproxy mode / Uninstall tproxy mode
uninstalled_tproxy_mode() {
    show_progress "$MSG_UNINSTALLING_TPROXY_MODE"
    uninstall_nft_rule
    cleanup_tproxy_routing
}

# Выбор режима установки / Choose install mode
perform_install_mode() {
    case $MODE in
        1)
            installed_tun_mode
            ;;
        2)
            installed_tproxy_mode
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
    install_mode_deps
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
