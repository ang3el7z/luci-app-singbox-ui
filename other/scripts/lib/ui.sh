#!/bin/sh

# Shared UI helpers for install scripts.
# Scripts may override palette/symbols before sourcing this file.

: "${FG_ACCENT:=\033[38;5;85m}"
: "${FG_WARNING:=\033[38;5;214m}"
: "${FG_SUCCESS:=\033[38;5;41m}"
: "${FG_ERROR:=\033[38;5;203m}"
: "${RESET:=\033[0m}"
: "${FG_USER_COLOR:=\033[38;5;117m}"

: "${SEP_CHAR:=-}"
: "${ARROW:=▸}"
: "${ARROW_CLEAR:=>}"
: "${CHECK:=✓}"
: "${CROSS:=✗}"
: "${INDENT:=  }"

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
        local line
        line=$(printf "%${width}s" " " | tr ' ' "${SEP_CHAR}")
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

        local side_part
        side_part=$(printf "%${side_width}s" " " | tr ' ' "${SEP_CHAR}")
        local left_text_pad
        left_text_pad=$(printf "%${left_padding}s" " ")
        local right_text_pad
        right_text_pad=$(printf "%${right_padding}s" " ")

        echo -e "${FG_ACCENT}${side_part}${RESET}${left_text_pad}${text}${right_text_pad}${FG_ACCENT}${side_part}${RESET}"
    else
        local remaining_text="$clean_text"
        local side_part
        side_part=$(printf "%${side_width}s" " " | tr ' ' "${SEP_CHAR}")

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
                    local char
                    char=$(echo "$remaining_text" | cut -c$i)
                    if [ "$char" = " " ]; then
                        cut_pos=$i
                        break
                    fi
                    i=$((i - 1))
                done

                line_text=$(echo "$remaining_text" | cut -c1-"$cut_pos")
                line_length=${#line_text}
                remaining_text=$(echo "$remaining_text" | cut -c$((cut_pos + 1))-)
                remaining_text=$(echo "$remaining_text" | sed 's/^[[:space:]]*//')
            fi

            local padding_needed=$((text_area - line_length))
            local left_padding=$((padding_needed / 2))
            local right_padding=$((padding_needed - left_padding))

            local left_text_pad
            left_text_pad=$(printf "%${left_padding}s" " ")
            local right_text_pad
            right_text_pad=$(printf "%${right_padding}s" " ")

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
