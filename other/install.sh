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

# Обновление репозиториев и установка зависимостей
show_progress "Обновление пакетов и установка зависимостей..."
opkg update && opkg install openssh-sftp-server nano curl jq
[ $? -eq 0 ] && show_success "Зависимости успешно установлены" || show_error "Ошибка установки зависимостей"
separator

# Установка sing-box
show_progress "Установка последней версии sing-box..."
opkg install sing-box
if [ $? -eq 0 ]; then
    show_success "Sing-box успешно установлен"
else
    show_error "Ошибка установки sing-box"
    exit 1
fi

# Конфигурация сервиса
show_progress "Настройка системного сервиса..."
uci set sing-box.main.enabled="1"
uci set sing-box.main.user="root"
uci commit sing-box
show_success "Конфигурация сервиса применена"

# Отключение сервиса
service sing-box disable
show_warning "Сервис временно отключен"

# Очистка конфигурации
echo '{}' > /etc/sing-box/config.json
show_warning "Конфигурационный файл сброшен"

# Автоматическая настройка конфигурации
separator
AUTO_CONFIG_SUCCESS=0
show_progress "Импорт конфигурации sing-box"

sleep 1
read -p "$(echo -e "  ${FG_ACCENT}▷ URL подписки на конфигурацию (Enter для ручного ввода): ${RESET}")" CONFIG_URL

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
show_progress "Установка веб-интерфейса singbox-ui..."
wget -O /root/install-singbox-ui.sh https://raw.githubusercontent.com/Vancltkin/luci-app-singbox-ui/main/other/install-singbox-ui.sh && chmod 0755 /root/install-singbox-ui.sh && sh /root/install-singbox-ui.sh
echo "$CONFIG_URL" > "/etc/sing-box/url_config.json"
show_success "Веб-интерфейс установлен"

# Создание сетевого интерфейса
configure_proxy() {
    show_progress "Создание сетевого интерфейса proxy..."
    uci set network.proxy=interface
    uci set network.proxy.proto="none"
    uci set network.proxy.device="singtun0"
    uci set network.proxy.defaultroute="0"
    uci set network.proxy.delegate="0"
    uci set network.proxy.peerdns="0"
    uci set network.proxy.auto="1"
    uci commit network
}
configure_proxy

# Настройка фаервола
configure_firewall() {
    show_progress "Конфигурация правил фаервола..."
    
    # Добавляем зону только если её не существует
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

    # Добавляем forwarding только если не существует
    if ! uci -q get firewall.@forwarding[-1].dest="proxy" >/dev/null; then
        uci add firewall forwarding >/dev/null
        uci set firewall.@forwarding[-1].dest="proxy"
        uci set firewall.@forwarding[-1].src="lan"
        uci set firewall.@forwarding[-1].family="ipv4"
    fi
    uci commit firewall >/dev/null 2>&1
    show_success "Правила фаервола применены"
}
configure_firewall

# Очистка системы
separator
show_progress "Оптимизация системы..."
find /tmp -name "luci-*cache*" -exec rm -f {} \; 2>/dev/null
rm -f /var/lib/uhttpd* 2>/dev/null
[ -x /etc/init.d/rpcd ] && /etc/init.d/rpcd restart
[ -x /etc/init.d/uhttpd ] && /etc/init.d/uhttpd restart
killall -HUP dnsmasq 2>/dev/null
chmod 755 /www/luci-static/singbox-ui 2>/dev/null
show_success "Система оптимизирована"

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
network_check

show_progress "Включение sing-box"
service sing-box enable
service sing-box restart
show_success "Сервис успешно запущен"
 
separator
echo -e "${BG_ACCENT}${FG_MAIN} Установка завершена! Доступ к панели: http://192.168.1.1 ${RESET}"
separator
