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
    # Если язык уже выбран (через переменную окружения), пропускаем запрос
    # If language already selected (via env var), skip prompt
    if [ -z "$LANG_CHOICE" ]; then
        echo -e "\n  ▷ Выберите язык / Select language [1/2]:"
        echo -e "  1. Русский (Russian)"
        echo -e "  2. English (Английский)"
        read -p "  ▷ Ваш выбор / Your choice [1/2]: " LANG_CHOICE
    fi

    # Установка языка по умолчанию (английский) / Default to English
    case ${LANG_CHOICE:-2} in
        1)
            # Русские тексты / Russian texts
            MSG_INSTALL_TITLE="Установка и настройка singbox-ui"
            MSG_UPDATE_PKGS="Обновление пакетов и установка зависимостей..."
            MSG_DEPS_SUCCESS="Зависимости успешно установлены"
            MSG_DEPS_ERROR="Ошибка установки зависимостей"
            MSG_INSTALL_UI="Начало установки singbox-ui..."
            MSG_INSTALL_COMPLETE="Установка завершена"
            MSG_CLEANUP="Очистка файлов..."
            MSG_CLEANUP_DONE="Файлы удалены!"
            ;;
        *)
            # Английские тексты / English texts
            MSG_INSTALL_TITLE="Singbox-ui installation and configuration"
            MSG_UPDATE_PKGS="Updating packages and installing dependencies..."
            MSG_DEPS_SUCCESS="Dependencies installed successfully"
            MSG_DEPS_ERROR="Error installing dependencies"
            MSG_INSTALL_UI="Starting singbox-ui installation..."
            MSG_INSTALL_COMPLETE="Installation complete"
            MSG_CLEANUP="Cleaning up files..."
            MSG_CLEANUP_DONE="Files removed!"
            ;;
    esac
}

# Инициализация языка / Initialize language
init_language
header

# Обновление репозиториев и установка зависимостей
# Update repositories and install dependencies
show_progress "$MSG_UPDATE_PKGS"
opkg update && opkg install openssh-sftp-server nano curl jq
[ $? -eq 0 ] && show_success "$MSG_DEPS_SUCCESS" || show_error "$MSG_DEPS_ERROR"
separator

# Установка singbox-ui / Install singbox-ui
show_progress "$MSG_INSTALL_UI"
wget -O /root/luci-app-singbox-ui.ipk https://github.com/ang3el7z/luci-app-singbox-ui/releases/latest/download/luci-app-singbox-ui.ipk
chmod 0755 /root/luci-app-singbox-ui.ipk
opkg update
opkg install /root/luci-app-singbox-ui.ipk
/etc/init.d/uhttpd restart
show_success "$MSG_INSTALL_COMPLETE"

# Очистка файлов / Cleanup files
show_progress "$MSG_CLEANUP"
rm "/root/luci-app-singbox-ui.ipk"
rm -- "$0"
show_success "$MSG_CLEANUP_DONE"