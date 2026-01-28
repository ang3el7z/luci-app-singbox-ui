#!/bin/sh

# Shared UI helpers for installers

# Цветовая палитра / Color palette
FG_ACCENT='\033[38;5;85m'
FG_WARNING='\033[38;5;214m'
FG_SUCCESS='\033[38;5;41m'
FG_ERROR='\033[38;5;203m'
RESET='\033[0m'
FG_USER_COLOR='\033[38;5;117m'

# Символы оформления / UI symbols
SEP_CHAR="─"
ARROW="▸"
ARROW_CLEAR="❯"
BULLET="•"
CHECK="✓"
CROSS="✗"
INDENT="   "

# Поддержка терминала / Terminal support
USE_COLOR=1
if [ -n "$NO_COLOR" ] || [ "$TERM" = "dumb" ]; then
    USE_COLOR=0
fi

USE_UNICODE=1
case "${LC_ALL:-}${LC_CTYPE:-}${LANG:-}" in
    *UTF-8*|*utf8*)
        USE_UNICODE=1
        ;;
    *)
        USE_UNICODE=0
        ;;
esac

if [ "$USE_UNICODE" -eq 0 ]; then
    SEP_CHAR="-"
    ARROW=">"
    ARROW_CLEAR=">"
    BULLET="*"
    CHECK="+"
    CROSS="x"
fi

if [ "$USE_COLOR" -eq 0 ]; then
    FG_ACCENT=""
    FG_WARNING=""
    FG_SUCCESS=""
    FG_ERROR=""
    FG_USER_COLOR=""
    RESET=""
fi

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
    local msg="$1"
    local num=""
    local rest=""

    case "$msg" in
        [0-9]*") "*)
            num="${msg%%)*}"
            rest="${msg#*) }"
            ;;
        [0-9]*". "*)
            num="${msg%%.*}"
            rest="${msg#*. }"
            ;;
    esac

    if [ -n "$num" ]; then
        printf "%b\n" "${FG_USER_COLOR}${INDENT}${BULLET} [${num}] ${rest}${RESET}"
    else
        printf "%b\n" "${FG_USER_COLOR}${INDENT}${BULLET} ${msg}${RESET}"
    fi
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

# Разделитель / Separator
separator() {
    local text="$1"

    SEP_CHAR=${SEP_CHAR:-"-"}
    FG_ACCENT=${FG_ACCENT:-"\033[38;5;85m"}
    RESET=${RESET:-"\033[0m"}

    if [ -z "$text" ]; then
        local line_len="${SEPARATOR_LINE_LEN:-48}"
        local line
        line=$(printf "%${line_len}s" " " | tr ' ' "=")
        echo -e "${FG_ACCENT}${line}${RESET}"
        return
    fi

    local clean_text
    clean_text=$(echo -n "$text" | sed 's/\x1b\[[0-9;]*m//g')

    local prefix="=== ${clean_text} "
    local fixed_len="${SEPARATOR_FIXED_LEN:-36}"
    local tail
    tail=$(printf "%${fixed_len}s" " " | tr ' ' "=")
    echo -e "${FG_ACCENT}${prefix}${tail}${RESET}"
}

# Запуск шагов с разделителями / Run steps with separators
run_steps_with_separator() {
    for step in "$@"; do
        case "$step" in
            ::*)
                text="${step#::}"
                printf "\n"
                separator "$text"
                ;;
            *)
                $step
                separator
                printf "\n"
                ;;
        esac
    done
}
