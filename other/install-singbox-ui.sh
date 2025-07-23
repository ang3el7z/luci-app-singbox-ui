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

# Символы оформления / UI symbols
SEP_CHAR="◈"
ARROW="▸"
CHECK="✓"
CROSS="✗"
INDENT="  "

# Функция разделителя / Separator function
separator() {
    echo -e "${WHITE}                -------------------------------------                ${RESET}"
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
    if [ -z "$LANG_CHOICE" ]; then
        echo -e "\n  ▷ Выберите язык / Select language [1/2]:"
        echo -e "  1. Русский (Russian)"
        echo -e "  2. English (Английский)"
        read -p "  ▷ Ваш выбор / Your choice [1/2]: " LANG_CHOICE
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
            MSG_INVALID_CHOICE="Некорректный выбор, выбрана версия Latest по умолчанию."
            MSG_INSTALL_COMPLETE="Установка завершена"
            MSG_CLEANUP="Очистка файлов..."
            MSG_CLEANUP_DONE="Файлы удалены!"
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
            MSG_INVALID_CHOICE="Invalid choice, defaulting to Latest version."
            MSG_INSTALL_COMPLETE="Installation complete"
            MSG_CLEANUP="Cleaning up files..."
            MSG_CLEANUP_DONE="Files removed!"
            ;;
    esac
}

# Запрашиваем язык
init_language
header

# Обновление репозиториев и установка зависимостей
show_progress "$MSG_UPDATE_PKGS"
opkg update && opkg install openssh-sftp-server nano curl jq
if [ $? -eq 0 ]; then
    show_success "$MSG_DEPS_SUCCESS"
else
    show_error "$MSG_DEPS_ERROR"
    exit 1
fi
separator

# Выбор версии для установки
echo
echo "$MSG_CHOOSE_VERSION"
echo "$MSG_OPTION_1"
echo "$MSG_OPTION_2"
echo "$MSG_OPTION_3"
read -p "▷ " VERSION_CHOICE

# Ссылки на файлы для каждой версии
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
        echo "Получаем ссылку на последнюю pre-release сборку..."
        DOWNLOAD_URL=$(curl -s https://api.github.com/repos/ang3el7z/luci-app-singbox-ui/releases | \
        grep -A 20 '"prerelease": true' | \
        grep "browser_download_url.*luci-app-singbox-ui.ipk" | \
        head -n 1 | \
        sed -E 's/.*"browser_download_url": *"([^"]+)".*/\1/')

        if [ -z "$DOWNLOAD_URL" ]; then
            echo "Не удалось получить pre-release, используем latest."
            DOWNLOAD_URL="$URL_LATEST"
        fi
        ;;
    *)
        echo "$MSG_INVALID_CHOICE"
        DOWNLOAD_URL="$URL_LATEST"
        ;;
esac

# Установка singbox-ui
show_progress "$MSG_INSTALL_UI"
wget -O /root/luci-app-singbox-ui.ipk "$DOWNLOAD_URL"
if [ $? -ne 0 ]; then
    show_error "Ошибка загрузки файла. Установка прервана."
    exit 1
fi
chmod 0755 /root/luci-app-singbox-ui.ipk
opkg update
opkg install /root/luci-app-singbox-ui.ipk
/etc/init.d/uhttpd restart
show_success "$MSG_INSTALL_COMPLETE"

# Очистка файлов
show_progress "$MSG_CLEANUP"
rm -f /root/luci-app-singbox-ui.ipk
rm -f -- "$0"
show_success "$MSG_CLEANUP_DONE"
