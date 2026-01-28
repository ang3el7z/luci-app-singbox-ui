#!/bin/sh
BRANCH="${BRANCH:-main}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
UI_LIB="$SCRIPT_DIR/other/scripts/lib/ui.sh"

if [ ! -f "$UI_LIB" ]; then
    UI_LIB="$SCRIPT_DIR/lib/ui.sh"
    mkdir -p "$SCRIPT_DIR/lib"
    if command -v wget >/dev/null 2>&1; then
        wget -O "$UI_LIB" "https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/$BRANCH/other/scripts/lib/ui.sh" >/dev/null 2>&1
    elif command -v curl >/dev/null 2>&1; then
        curl -fsSL "https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/$BRANCH/other/scripts/lib/ui.sh" -o "$UI_LIB" >/dev/null 2>&1
    fi
fi

if [ ! -f "$UI_LIB" ]; then
    echo "Failed to load UI helpers. Please check network or script path."
    exit 1
fi

. "$UI_LIB"

# Инициализация языка / Language initialization
init_language() {
    local script_name="install.sh"

    if [ -z "$LANG" ]; then
        show_message "Выберите язык / Select language [1/2]:"
        show_message "1. Русский (Russian)"
        show_message "2. English (Английский)"
        read_input "Ваш выбор / Your choice [1/2]:" LANG
    fi

    case ${LANG:-2} in
    1)
        MSG_INSTALL_TITLE="Запуск! ($script_name)"
        MSG_COMPLETE="Выполнено! ($script_name)"
        MSG_FINISHED="Все инструкции выполнены!"
        MSG_INSTALL="Переход к установочному скрипту..."
        MSG_CLEANUP="Очистка файлов..."
        MSG_CLEANUP_DONE="Файлы удалены!"
        MSG_WAITING="Ожидание %d сек"
        ;;
    *)
        MSG_INSTALL_TITLE="Starting! ($script_name)"
        MSG_COMPLETE="Done! ($script_name)"
        MSG_FINISHED="All instructions completed!"
        MSG_INSTALL="Transition to the installation script..."
        MSG_CLEANUP="Cleaning files..."
        MSG_CLEANUP_DONE="Files deleted!"
        MSG_WAITING="Waiting %d seconds"
        ;;
esac
}

# Ожидание / Waiting
waiting() {
    local interval="${1:-30}"
    show_progress "$(printf "$MSG_WAITING" "$interval")"
    sleep "$interval"
}

# Установка / Install
install() {
    show_warning "$MSG_INSTALL"
    wget -O /root/install-singbox+singbox-ui.sh https://raw.githubusercontent.com/ang3el7z/luci-app-singbox-ui/$BRANCH/other/scripts/install-singbox+singbox-ui.sh &&
    chmod 0755 /root/install-singbox+singbox-ui.sh &&
    LANG="$LANG" BRANCH="$BRANCH" sh /root/install-singbox+singbox-ui.sh
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
    "::${BRANCH}" \
    init_language

run_steps_with_separator \
    "::$MSG_INSTALL_TITLE" \
    install \
    complete_script \
    "::$MSG_FINISHED"
