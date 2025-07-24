FROM openwrt/sdk:x86_64-v24.10.1

# Обновляем feeds и устанавливаем зависимости
RUN ./scripts/feeds update -a && \
    ./scripts/feeds install luci-base

# Создаем правильную структуру каталогов
RUN mkdir -p package/feeds/luci

# Копируем пакет в правильное место
COPY ./luci-app-singbox-ui package/feeds/luci/luci-app-singbox-ui

# Обновляем индекс после копирования
RUN ./scripts/feeds update -a

# Собираем с правильным путем к пакету
RUN make defconfig && \
    make package/feeds/luci/luci-app-singbox-ui/compile V=s -j4
