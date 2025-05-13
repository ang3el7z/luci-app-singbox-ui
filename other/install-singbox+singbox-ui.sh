#!/bin/sh

# Цветовая палитра (приглушенные тона)
BG_DARK='\033[48;5;236m'
BG_ACCENT='\033[48;5;24m'
FG_MAIN='\033[38;5;252m'
FG_ACCENT='\033[38;5;85m'
FG_WARNING='\033[38;5;214m'
FG_SUCCESS='\033[38;5;41m'
FG_ERROR='\033[38;5;203m'
RESET='\033[0m'

# Символы оформления
SEP_CHAR="◈"
ARROW="▸"
CHECK="✓"
CROSS="✗"
INDENT="  "

# Функция разделителя
separator() {
    echo -e "${WHITE}                -------------------------------------                ${RESET}"
}

header() {
    clear
    separator
    echo -e "${BG_ACCENT}${FG_MAIN}                Установка и настройка sing-box + singbox-ui                ${RESET}"
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

show_warning() {
    echo -e "${INDENT}! ${FG_WARNING}$1${RESET}\n"
}

header

network_check() {
# Параметры проверки
    timeout=60       # Общее время ожидания (сек)
    interval=5       # Интервал между попытками (сек)
    target="8.8.8.8" # Цель для проверки

    success=0
    attempts=$(($timeout / $interval))

    show_progress "Проверка доступности сети..."
    i=1
    while [ $i -le $attempts ]; do
        if ping -c 1 -W 2 "$target" >/dev/null 2>&1; then
            success=1
            break
        fi
        sleep $interval
        i=$((i + 1))
    done
    
    if [ $success -eq 1 ]; then
        show_success "Сеть доступна (проверка заняла $((i * interval)) сек)"
        show_success "network работает"
    else
        show_error "Сеть не доступна после $timeout сек!" >&2
        exit 1
    fi
  
}

# Установка singbox
separator
show_progress "Переход к установке singbox..."
wget -O /root/install-singbox.sh https://raw.githubusercontent.com/Vancltkin/luci-app-singbox-ui/main/other/install-singbox.sh && chmod 0755 /root/install-singbox.sh && sh /root/install-singbox.sh
show_success "Вернулись к основному скрипту"

network_check

# Проверяем, что URL не пустой
if [ -n "$CONFIG_URL" ]; then
    MAX_ATTEMPTS=2  # Максимальное количество попыток загрузки
    ATTEMPT=1  # Счетчик попыток
    SUCCESS=0  # Флаг успешной загрузки

    # Пытаемся загрузить конфигурацию
    while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
        show_progress "Загрузка конфигурации с ${CONFIG_URL} (Попытка $ATTEMPT из $MAX_ATTEMPTS)"
        RAW_JSON=$(curl -fsS "$CONFIG_URL" 2>&1)
        
        if [ $? -eq 0 ]; then
            FORMATTED_JSON=$(echo "$RAW_JSON" | jq '.' 2>/dev/null)
            
            if [ $? -eq 0 ]; then
                echo "$FORMATTED_JSON" > /etc/sing-box/config.json
                show_success "Конфигурация успешно загружена"
                AUTO_CONFIG_SUCCESS=1
                SUCCESS=1
                break  # Выход из цикла, если загрузка успешна
            else
                show_error "Ошибка формата конфигурации"
            fi
        else
            show_error "Ошибка загрузки: ${RAW_JSON}"
        fi

        # Если загрузка не удалась, увеличиваем счетчик попыток
        if [ $ATTEMPT -lt $MAX_ATTEMPTS ]; then
            show_warning "Попробую снова..."
        fi
        
        ATTEMPT=$((ATTEMPT + 1))  # Увеличиваем счетчик попыток
    done

    # Если все попытки не удались, переходим к ручной настройке
    if [ $SUCCESS -eq 0 ]; then
        show_warning "Переход к ручной настройке конфигурации"
        nano /etc/sing-box/config.json
    fi
else
    show_warning "Ручная настройка конфигурации"
    nano /etc/sing-box/config.json
fi

# Проверка ручной конфигурации
if [ "$AUTO_CONFIG_SUCCESS" -eq 0 ]; then
    while true; do
        separator
        read -p "$(echo -e "  ${FG_ACCENT}▷ Завершили редактирование config.json? [y/N]: ${RESET}")" yn
        case ${yn:-n} in
            [Yy]* )
                
                show_success "Успешно"
                break
                ;;
            [Nn]* )
                nano /etc/sing-box/config.json
                ;;
            * )
                show_error "Некорректный ввод"
                ;;
        esac
    done
fi

# Установка веб-интерфейса
separator
show_progress "Переход к установке singbox-ui..."
wget -O /root/install-singbox-ui.sh https://raw.githubusercontent.com/Vancltkin/luci-app-singbox-ui/main/other/install-singbox-ui.sh && chmod 0755 /root/install-singbox-ui.sh && sh /root/install-singbox-ui.sh
echo "$CONFIG_URL" > "/etc/sing-box/url_config.json"
show_success "Вернулись к основному скрипту"

# Отключение IPv6
separator
show_progress "Отключение IPv6..."
uci set 'network.lan.ipv6=0'
uci set 'network.wan.ipv6=0'
uci set 'dhcp.lan.dhcpv6=disabled'
/etc/init.d/odhcpd disable
uci commit
show_success "IPv6 отключен"

show_progress "Перезапуск firewall..."
service firewall reload >/dev/null 2>&1

show_progress "Перезапуск network..."
service network restart

network_check

show_progress "Включение sing-box"
service sing-box enable
service sing-box restart
show_success "Сервис успешно запущен"
 
separator
echo -e "${BG_ACCENT}${FG_MAIN} Установка завершена! Доступ к панели: http://192.168.1.1 ${RESET}"
separator
