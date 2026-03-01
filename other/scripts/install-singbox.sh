#!/bin/sh
BRANCH="${BRANCH:-main}"

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
UI_PATH="$SCRIPT_DIR/lib/ui.sh"
PKG_PATH="$SCRIPT_DIR/lib/pkg.sh"
MS_TMP="/tmp/singbox-ui-mode-switch"
UI_DOWNLOADED=0
PKG_DOWNLOADED=0
MS_DOWNLOADED=0
cleanup_lib() {
    if [ "${UI_DOWNLOADED:-0}" -eq 1 ] || [ "${PKG_DOWNLOADED:-0}" -eq 1 ]; then
        local cleanup_msg="${MSG_CLEANUP_UI:-Cleaning UI library...}"
        if command -v show_progress >/dev/null 2>&1; then
            show_progress "$cleanup_msg"
        else
            echo "$cleanup_msg"
        fi
        rm -f -- "$UI_PATH" "$PKG_PATH"
        rmdir -- "$SCRIPT_DIR/lib" 2>/dev/null || true
    fi
    [ "${MS_DOWNLOADED:-0}" -eq 1 ] && rm -f -- "$MS_TMP"
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
ensure_pkg_library() {
    if [ -f "$PKG_PATH" ]; then
        . "$PKG_PATH"
        detect_pkg_manager || return 1
        return 0
    fi

    mkdir -p "$SCRIPT_DIR/lib" 2>/dev/null
    pkg_url="https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/$BRANCH/other/scripts/lib/pkg.sh"
    if command -v wget >/dev/null 2>&1; then
        wget -O "$PKG_PATH" "$pkg_url" || return 1
    elif command -v curl >/dev/null 2>&1; then
        curl -fsSL -o "$PKG_PATH" "$pkg_url" || return 1
    else
        echo "Missing pkg library and downloader (wget/curl)" >&2
        return 1
    fi

    PKG_DOWNLOADED=1
    . "$PKG_PATH"
    detect_pkg_manager || return 1
}

ensure_mode_switch() {
    if [ -x "/usr/bin/singbox-ui/singbox-ui-mode-switch" ]; then
        MODE_SWITCH="/usr/bin/singbox-ui/singbox-ui-mode-switch"
        return 0
    fi
    local ms_url="https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/$BRANCH/luci-app-singbox-ui/root/usr/bin/singbox-ui/singbox-ui-mode-switch"
    if command -v wget >/dev/null 2>&1; then
        wget -O "$MS_TMP" "$ms_url" || return 1
    elif command -v curl >/dev/null 2>&1; then
        curl -fsSL -o "$MS_TMP" "$ms_url" || return 1
    else
        echo "Missing mode-switch and downloader (wget/curl)" >&2
        return 1
    fi
    chmod +x "$MS_TMP"
    MODE_SWITCH="$MS_TMP"
    MS_DOWNLOADED=1
}

ensure_ui_library || {
    echo "Missing UI library: $UI_PATH" >&2
    exit 1
}
ensure_pkg_library || {
    echo "Missing pkg library: $PKG_PATH" >&2
    exit 1
}
ensure_mode_switch || {
    echo "Missing mode-switch: /usr/bin/singbox-ui/singbox-ui-mode-switch" >&2
    exit 1
}
trap cleanup_lib EXIT HUP INT TERM

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
            MSG_TPROXY="2. TPROXY"
            MSG_MODE_CHOICE="Ваш выбор: "
            MSG_INSTALLING_TPROXY_MODE="Установка TPROXY режима..."
            MSG_UNINSTALLING_TPROXY_MODE="Удаление TPROXY режима..."
            MSG_TPROXY_ROUTE_SETUP="Настройка policy routing для TPROXY..."
            MSG_TPROXY_ROUTE_CLEANUP="Удаление policy routing для TPROXY..."
            MSG_TPROXY_NFT_INSTALL="Установка nftables (nft) для TPROXY..."
            MSG_TPROXY_NFT_INSTALLED="nftables успешно установлен"
            MSG_TPROXY_NFT_ERROR="Не удалось установить nftables"
            MSG_TPROXY_FW4_REQUIRED="Для TPROXY требуется firewall4 (fw4). Обновите OpenWrt и установите firewall4."
            MSG_PKG_INSTALLING="Установка пакета: %s..."
            MSG_PKG_INSTALLED="Пакет установлен: %s"
            MSG_PKG_INSTALL_ERROR="Не удалось установить пакет: %s"
            MSG_TPROXY_RULE_APPLY_ERROR="Не удалось применить nft правила для TPROXY"
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
            MSG_SINGBOX_FILE_NOT_FOUND="Файлы sing-box*.${PKG_EXT} не найдены в /tmp!"
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
            MSG_SINGBOX_DOWNLOAD_MENU_OPTION1="1) Скачать sing-box из списка репозитория в /tmp"
            MSG_SINGBOX_DOWNLOAD_MENU_OPTION2="2) $MSG_SINGBOX_USE_STORE"
            MSG_SINGBOX_DOWNLOAD_MENU_OPTION3="3) Повторить поиск файла (ручная загрузка)"
            MSG_SINGBOX_DOWNLOAD_PROMPT="Выберите действие [1-3]: "
            MSG_SINGBOX_LIST_UNAVAILABLE="Список пакетов недоступен (ветка или сеть). Проверьте BRANCH и интернет."
            MSG_SINGBOX_SELECT_PKG="Доступные пакеты sing-box (ветка: $BRANCH):"
            MSG_SINGBOX_LIST_EMPTY="Нет подходящих пакетов sing-box в репозитории."
            MSG_SINGBOX_DOWNLOADING="Загрузка '%s' в /tmp..."
            MSG_SINGBOX_DOWNLOAD_SUCCESS_FILE="Файл '%s' успешно загружен в /tmp."
            MSG_SINGBOX_DOWNLOAD_ERROR_FILE="Не удалось скачать '%s'. Проверьте подключение к интернету."
            MSG_INVALID_INPUT="Ошибка: Некорректный ввод"
            MSG_REPEAT_INPUT="Повторите ввод"
            MSG_INSTALL_SINGBOX_FILE="Установка выбранного файла sing-box..."
            MSG_IPV6_DISABLE_PROMPT="Отключить IPv6? [1-Да, 2-Нет] (по умолчанию: 1 - Отключить): "
            MSG_IPV6_SKIP="IPv6 оставлен без изменений"
            MSG_IPV6_RESTORE_CHECK="Проверка необходимости восстановления IPv6..."
            MSG_IPV6_RESTORE_SKIP="IPv6 не был отключён, восстановление не требуется"
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
            MSG_TPROXY="2. TPROXY"
            MSG_MODE_CHOICE="Your choice: "
            MSG_INSTALLING_TPROXY_MODE="Installing TPROXY mode..."
            MSG_UNINSTALLING_TPROXY_MODE="Uninstalling TPROXY mode..."
            MSG_TPROXY_ROUTE_SETUP="Configuring TPROXY policy routing..."
            MSG_TPROXY_ROUTE_CLEANUP="Removing TPROXY policy routing..."
            MSG_TPROXY_NFT_INSTALL="Installing nftables (nft) for TPROXY..."
            MSG_TPROXY_NFT_INSTALLED="nftables installed successfully"
            MSG_TPROXY_NFT_ERROR="Failed to install nftables"
            MSG_TPROXY_FW4_REQUIRED="TPROXY requires firewall4 (fw4). Please upgrade OpenWrt and install firewall4."
            MSG_PKG_INSTALLING="Installing package: %s..."
            MSG_PKG_INSTALLED="Package installed: %s"
            MSG_PKG_INSTALL_ERROR="Failed to install package: %s"
            MSG_TPROXY_RULE_APPLY_ERROR="Failed to apply nft rules for TPROXY"
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
            MSG_SINGBOX_FILE_NOT_FOUND="No sing-box*.${PKG_EXT} files found in /tmp!"
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
            MSG_SINGBOX_DOWNLOAD_MENU_OPTION1="1) Download sing-box from repository list to /tmp"
            MSG_SINGBOX_DOWNLOAD_MENU_OPTION2="2) $MSG_SINGBOX_USE_STORE"
            MSG_SINGBOX_DOWNLOAD_MENU_OPTION3="3) Retry file search (manual upload)"
            MSG_SINGBOX_DOWNLOAD_PROMPT="Choose action [1-3]: "
            MSG_SINGBOX_LIST_UNAVAILABLE="Package list unavailable (branch or network). Check BRANCH and internet."
            MSG_SINGBOX_SELECT_PKG="Available sing-box packages (branch: $BRANCH):"
            MSG_SINGBOX_LIST_EMPTY="No suitable sing-box packages in repository."
            MSG_SINGBOX_DOWNLOADING="Downloading '%s' to /tmp..."
            MSG_SINGBOX_DOWNLOAD_SUCCESS_FILE="File '%s' downloaded to /tmp successfully."
            MSG_SINGBOX_DOWNLOAD_ERROR_FILE="Failed to download '%s'. Please check your internet connection."
            MSG_INVALID_INPUT="Error: Invalid input"
            MSG_REPEAT_INPUT="Repeat input"
            MSG_INSTALL_SINGBOX_FILE="Installing selected sing-box file..."
            MSG_IPV6_DISABLE_PROMPT="Disable IPv6? [1-Yes, 2-No] (default: 1 - Disable): "
            MSG_IPV6_SKIP="IPv6 left unchanged"
            MSG_IPV6_RESTORE_CHECK="Checking if IPv6 restore is needed..."
            MSG_IPV6_RESTORE_SKIP="IPv6 was not disabled, restore not needed"
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
    if pkg_list_update; then
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
    if pkg_install nftables; then
        show_success "$MSG_TPROXY_NFT_INSTALLED"
        return 0
    fi
    show_error "$MSG_TPROXY_NFT_ERROR"
    exit 1
}

ensure_fw4_available() {
    if command -v fw4 >/dev/null 2>&1 || [ -x /sbin/fw4 ]; then
        return 0
    fi
    show_error "$MSG_TPROXY_FW4_REQUIRED"
    exit 1
}

ensure_pkg() {
    local pkg="$1"
    if pkg_is_installed "$pkg"; then
        return 0
    fi
    show_progress "$(printf "$MSG_PKG_INSTALLING" "$pkg")"
    if pkg_install "$pkg"; then
        show_success "$(printf "$MSG_PKG_INSTALLED" "$pkg")"
        return 0
    fi
    show_error "$(printf "$MSG_PKG_INSTALL_ERROR" "$pkg")"
    exit 1
}

ensure_tproxy_deps() {
    ensure_fw4_available
    ensure_nft_available
    ensure_pkg ip-full
    ensure_pkg kmod-nft-tproxy
    ensure_pkg kmod-nft-socket
    ensure_pkg kmod-inet-diag
}

install_mode_deps() {
    case $MODE in
        1)
            show_progress "$MSG_TUN_DEPS_INSTALL"
            if pkg_is_installed "kmod-tun"; then
                show_success "$MSG_TUN_DEPS_ALREADY"
                return 0
            fi
            if pkg_install kmod-tun; then
                show_success "$MSG_TUN_DEPS_INSTALLED"
            else
                show_error "$MSG_TUN_DEPS_ERROR"
                exit 1
            fi
            ;;
        2)
            ensure_tproxy_deps
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
        
        if pkg_install sing-box; then
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
    # Параметры дефолтной версии для авто-скачивания (ipk/apk по платформе)
    local singbox_pkg_base="https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/${BRANCH}/other/pkg/${PKG_EXT}"

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
            ipk_files=$(find /tmp -maxdepth 1 \( -name "sing-box*.ipk" -o -name "sing-box*.apk" \) -type f 2>/dev/null | sort)
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
                        # Список sing-box пакетов из репо (ветка $BRANCH) / List from repo branch
                        local api_url="https://api.github.com/repos/ang3el7z/luci-app-singbox-ui/contents/other/pkg/${PKG_EXT}?ref=${BRANCH}"
                        local list_json=""
                        list_json=$(curl -sL "$api_url" 2>/dev/null) || true
                        local pkg_names=""
                        if [ -n "$list_json" ]; then
                            pkg_names=$(echo "$list_json" | grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*\.'"${PKG_EXT}"'"' | sed -n 's/.*:[[:space:]]*"\([^"]*\)".*/\1/p')
                            # только sing-box*.ext / only sing-box*.ext
                            pkg_names=$(echo "$pkg_names" | grep -E '^sing-box.*\.'"${PKG_EXT}"'$' || true)
                        fi
                        if [ -z "$pkg_names" ]; then
                            show_error "$MSG_SINGBOX_LIST_UNAVAILABLE"
                            break
                        fi
                        show_message "$MSG_SINGBOX_SELECT_PKG"
                        local idx=1
                        local num_to_name=""
                        local total_pkg=0
                        while IFS= read -r name; do
                            [ -z "$name" ] && continue
                            show_message "  [$idx] $name"
                            eval SINGBOX_PKG_${idx}="\$name"
                            idx=$((idx + 1))
                            total_pkg=$((total_pkg + 1))
                        done <<EOF
$pkg_names
EOF
                        if [ "$total_pkg" -eq 0 ]; then
                            show_error "$MSG_SINGBOX_LIST_EMPTY"
                            break
                        fi
                        local choice_pkg=""
                        while true; do
                            read_input "$MSG_SINGBOX_SELECT_FILE" choice_pkg
                            if [ "$choice_pkg" -ge 1 ] 2>/dev/null && [ "$choice_pkg" -le "$total_pkg" ] 2>/dev/null; then
                                break
                            fi
                            show_error "$MSG_INVALID_INPUT. $MSG_REPEAT_INPUT"
                        done
                        eval "local selected_pkg_name=\"\$SINGBOX_PKG_${choice_pkg}\""
                        local download_url="${singbox_pkg_base}/${selected_pkg_name}"
                        local dst_file="/tmp/${selected_pkg_name}"
                        show_progress "$(printf "$MSG_SINGBOX_DOWNLOADING" "$selected_pkg_name")"
                        if wget -O "$dst_file" "$download_url"; then
                            show_success "$(printf "$MSG_SINGBOX_DOWNLOAD_SUCCESS_FILE" "$selected_pkg_name")"
                            show_progress "$MSG_INSTALL_SINGBOX_FILE"
                            if pkg_install_file "$dst_file"; then
                                show_success "$MSG_INSTALL_SINGBOX_SUCCESS"
                                rm -f "$dst_file"
                                return 0
                            else
                                show_error "$MSG_INSTALL_SINGBOX_ERROR"
                                [ -f "$dst_file" ] && rm -f "$dst_file"
                                show_message ""
                                show_message "$MSG_SINGBOX_ERROR_OPTIONS"
                                show_message "1) $MSG_SINGBOX_TRY_ANOTHER_FILE"
                                show_message "2) $MSG_SINGBOX_USE_STORE"
                                show_message "3) $MSG_SINGBOX_EXIT"
                                while true; do
                                    read_input "$MSG_SINGBOX_ERROR_CHOICE" INST_ERR_CHOICE
                                    case $INST_ERR_CHOICE in
                                        1) RETRY_CHOICE="3"; break ;;
                                        2) SINGBOX_INSTALL_MODE="1"; install_singbox; return ;;
                                        3) exit 1 ;;
                                        *) show_error "$MSG_INVALID_INPUT. $MSG_REPEAT_INPUT" ;;
                                    esac
                                done
                            fi
                        else
                            show_error "$(printf "$MSG_SINGBOX_DOWNLOAD_ERROR_FILE" "$selected_pkg_name")"
                            [ -f "$dst_file" ] && rm -f "$dst_file"
                        fi
                        break
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
            show_progress "$MSG_INSTALL_SINGBOX_FILE"
            
            if pkg_install_file "$selected_file"; then
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
    if pkg_remove sing-box; then
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

# Спросить пользователя про отключение IPv6 (дефолт — отключить) / Ask user about IPv6 disable (default — disable)
maybe_disable_ipv6() {
    while true; do
        read_input "$MSG_IPV6_DISABLE_PROMPT" IPV6_CHOICE
        if [ -z "$IPV6_CHOICE" ]; then
            IPV6_CHOICE="1"
        fi
        case "$IPV6_CHOICE" in
            1)
                disabled_ipv6
                break
                ;;
            2)
                show_progress "$MSG_IPV6_SKIP"
                break
                ;;
            *)
                show_error "$MSG_INVALID_INPUT. $MSG_REPEAT_INPUT"
                ;;
        esac
    done
}

# Восстановить IPv6 только если он был отключён / Restore IPv6 only if it was disabled
maybe_restore_ipv6() {
    show_progress "$MSG_IPV6_RESTORE_CHECK"
    local ipv6_val
    ipv6_val=$(uci -q get network.lan.ipv6 2>/dev/null)
    if [ "$ipv6_val" = "0" ]; then
        restore_ipv6
    else
        show_progress "$MSG_IPV6_RESTORE_SKIP"
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
    pkg_is_installed "sing-box"
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
    "$MODE_SWITCH" enable-tun
    network_check
    enable_singbox
}

# Удаление tun mode / Uninstall tun mode
uninstalled_tun_mode() {
    show_progress "$MSG_UNINSTALLING_TUN_MODE"
    "$MODE_SWITCH" disable-tun
    network_check
}

# Установка tproxy mode / Install tproxy mode
installed_tproxy_mode() {
    show_progress "$MSG_INSTALLING_TPROXY_MODE"
    enable_singbox
    "$MODE_SWITCH" enable-tproxy
    network_check
}

# Удаление tproxy mode / Uninstall tproxy mode
uninstalled_tproxy_mode() {
    show_progress "$MSG_UNINSTALLING_TPROXY_MODE"
    "$MODE_SWITCH" disable-tproxy
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
    maybe_disable_ipv6
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
    maybe_restore_ipv6
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
