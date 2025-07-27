#!/bin/sh

# Цветовая палитра (приглушенные тона) / Color palette (muted tones)
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
SEP_CHAR="◈"
ARROW="▸"
ARROW_CLEAR=">"
CHECK="✓"
CROSS="✗"
INDENT="  "

# Функция разделителя / Separator function
separator() {
    echo -e "${FG_MAIN}                -------------------------------------                ${RESET}"
}

header() {
    separator
    echo -e "${BG_ACCENT}${FG_MAIN}                $1                ${RESET}"
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

    case ${LANG_CHOICE:-2} in
        1)
            MSG_INSTALL_TITLE="Установка и настройка singbox-ui"
            MSG_UPDATE_PKGS="Обновление пакетов и установка зависимостей..."
            MSG_DEPS_SUCCESS="Зависимости успешно установлены"
            MSG_DEPS_ERROR="Ошибка установки зависимостей"
            MSG_INSTALL_UI="Начало установки singbox-ui..."
            MSG_CHOOSE_VERSION="Выберите версию singbox-ui для установки:"
            MSG_OPTION_1="1) Latest (около 150 Кб)"
            MSG_OPTION_2="2) Lite версия (около 6 Кб)"
            MSG_OPTION_3="3) Pre-release (бета, возможны баги)"
            MSG_OPTION_4="4) Runner сборка из Pull Request (тестовая)"
            MSG_INVALID_CHOICE="Некорректный выбор, выбрана версия Latest по умолчанию."
            MSG_INSTALL_COMPLETE="Установка завершена"
            MSG_CLEANUP="Очистка файлов..."
            MSG_CLEANUP_DONE="Файлы удалены!"
            MSG_NO_RUNNER_FILES="Файлы Runner сборок не найдены."
            MSG_SELECT_RUNNER="Выберите Runner сборку для установки:"
            MSG_NO_PRE_RELEASE="Не удалось получить pre-release, используем latest."
            MSG_RUNNER_INDEX_UNAVAILABLE="Не удалось загрузить список runner сборок (index.txt)."
            MSG_RUNNER_LIST_EMPTY="Список runner сборок пуст."
            MSG_INVALID_CHOICE="Неверный выбор. Установлена последняя доступная сборка."
            MSG_INSTALL_LATEST="Устанавливается последняя доступная сборка (latest)..."
            MSG_DOWNLOAD_ERROR="Ошибка загрузки файла. Установка прервана."
            MSG_WAITING="Ожидание %d сек"
            MSG_YOUR_CHOICE="Ваш выбор: "
            MSG_COMPLETE="Выполнено! (install-singbox-ui.sh)"
            ;;
        *)
            MSG_INSTALL_TITLE="Singbox-ui installation and configuration"
            MSG_UPDATE_PKGS="Updating packages and installing dependencies..."
            MSG_DEPS_SUCCESS="Dependencies installed successfully"
            MSG_DEPS_ERROR="Error installing dependencies"
            MSG_INSTALL_UI="Starting singbox-ui installation..."
            MSG_CHOOSE_VERSION="Select singbox-ui version to install:"
            MSG_OPTION_1="1) Latest (about 150 KB)"
            MSG_OPTION_2="2) Lite version (about 6 KB)"
            MSG_OPTION_3="3) Pre-release (beta, may have bugs)"
            MSG_OPTION_4="4) Runner build from Pull Request (testing)"
            MSG_INSTALL_COMPLETE="Installation complete"
            MSG_CLEANUP="Cleaning up files..."
            MSG_CLEANUP_DONE="Files removed!"
            MSG_NO_RUNNER_FILES="Runner build files not found."
            MSG_SELECT_RUNNER="Select Runner build to install:"
            MSG_NO_PRE_RELEASE="Failed to fetch pre-release, using latest."
            MSG_RUNNER_INDEX_UNAVAILABLE="Failed to load runner build list (index.txt)."
            MSG_RUNNER_LIST_EMPTY="Runner build list is empty."
            MSG_INVALID_CHOICE="Invalid choice. Installing latest available build."
            MSG_INSTALL_LATEST="Installing stable version latest"
            MSG_DOWNLOAD_ERROR="Download failed. Installation aborted."
            MSG_WAITING="Waiting %d sec"
            MSG_YOUR_CHOICE="Your choice: "
            MSG_COMPLETE="Completed! (install-singbox-ui.sh)"
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
    opkg update && opkg install curl jq
    if [ $? -eq 0 ]; then
        show_success "$MSG_DEPS_SUCCESS"
        separator
    else
        show_error "$MSG_DEPS_ERROR"
        separator
        exit 1
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

# Выбор версии для установки / Version selection
choose_install_version() {
    show_message "$MSG_CHOOSE_VERSION"
    show_message "$MSG_OPTION_1"
    show_message "$MSG_OPTION_2"
    show_message "$MSG_OPTION_3"
    show_message "$MSG_OPTION_4"
    read_input "$MSG_YOUR_CHOICE" VERSION_CHOICE

    # Ссылки на файлы для каждой версии / URLs for each version
    URL_LATEST="https://github.com/ang3el7z/luci-app-singbox-ui/releases/latest/download/luci-app-singbox-ui.ipk"
    URL_LITE="https://github.com/ang3el7z/luci-app-singbox-ui/releases/download/v1.2.1/luci-app-singbox-ui.ipk"

    case "$VERSION_CHOICE" in
    1)
        DOWNLOAD_URL="$URL_LATEST"
        ;;
    2)
        DOWNLOAD_URL="$URL_LITE"
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
            DOWNLOAD_URL="$URL_LATEST"
        fi
        ;;
    4)
        RUNNER_BASE_URL="https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/main/artifacts"
        INDEX_URL="$RUNNER_BASE_URL/index.txt"

        show_progress "$MSG_SELECT_RUNNER"

        # Получаем список runner сборок с проверкой / Get list of runner builds with validation
        http_code=$(curl -s -o /tmp/index.txt -w "%{http_code}" "$INDEX_URL")
        if [ "$http_code" != "200" ]; then
            show_error "$MSG_RUNNER_INDEX_UNAVAILABLE"
            show_progress "$MSG_INSTALL_LATEST"
            DOWNLOAD_URL="$URL_LATEST"
            break
        fi

        RUNNER_FILES=$(cat /tmp/index.txt)

        if [ -z "$RUNNER_FILES" ]; then
            show_error "$MSG_RUNNER_LIST_EMPTY"
            show_progress "$MSG_INSTALL_LATEST"
            DOWNLOAD_URL="$URL_LATEST"
            break
        fi

        i=1
        for file in $RUNNER_FILES; do
            show_message "  [$i] $file"
            eval RUNNER_$i="'$file'"
            i=$((i+1))
        done

        read_input "$MSG_YOUR_CHOICE" choice

        eval SELECTED_RUNNER_FILE=\$RUNNER_$choice

        if [ -z "$SELECTED_RUNNER_FILE" ]; then
            show_error "$MSG_INVALID_CHOICE"
            DOWNLOAD_URL="$URL_LATEST"
        else
            DOWNLOAD_URL="$RUNNER_BASE_URL/$SELECTED_RUNNER_FILE"
        fi
        ;;
    *)
        show_error "$MSG_INVALID_CHOICE"
        DOWNLOAD_URL="$URL_LATEST"
        ;;
    esac
}

# Установка singbox-ui / Install singbox-ui
install_singbox_ui() {
    show_progress "$MSG_INSTALL_UI"
    wget -O /root/luci-app-singbox-ui.ipk "$DOWNLOAD_URL"
    if [ $? -ne 0 ]; then
        show_error "$MSG_DOWNLOAD_ERROR"
        exit 1
    fi
    chmod 0755 /root/luci-app-singbox-ui.ipk
    opkg update
    opkg install /root/luci-app-singbox-ui.ipk
    /etc/init.d/uhttpd restart
    show_success "$MSG_INSTALL_COMPLETE"
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

init_language
header "$MSG_INSTALL_TITLE"
update_pkgs
choose_install_version
install_singbox_ui
complete_script
