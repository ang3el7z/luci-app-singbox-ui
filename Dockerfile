FROM openwrt/sdk:x86_64-v23.05.5

# Устанавливаем нужные утилиты (нужны feeds)
USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends git subversion wget && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /builder

# Обновляем и устанавливаем все feeds
RUN ./scripts/feeds update -a && \
    ./scripts/feeds install -a

# Копируем ваш пакет
COPY ./luci-app-singbox-ui /builder/package/feeds/luci/luci-app-singbox-ui

# Собираем
RUN make defconfig && \
    make package/luci-app-singbox-ui/compile V=s -j$(nproc)
