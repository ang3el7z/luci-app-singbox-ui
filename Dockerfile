# --- Прошлый вариант рабочий ---
FROM openwrt/sdk:x86_64-v23.05.5

# 1) ставим необходимые инструменты для feeds
USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends git wget subversion mercurial && \
    rm -rf /var/lib/apt/lists/*
    
WORKDIR /builder
    
# 2) обновляем и устанавливаем все feeds (или только luci, если нужно)
RUN ./scripts/feeds update -a && \
    ./scripts/feeds install -a
    
# 3) создаём папки (обратите внимание: utilities, а не utilites)
RUN mkdir -p /builder/package/feeds/utilities \
                 /builder/package/feeds/luci
    
# 4) копируем ваш пакет
COPY ./luci-app-singbox-ui /builder/package/feeds/luci/luci-app-singbox-ui
    
# 5) генерим дефолтную конфигурацию и собираем ваш пакет
RUN make defconfig && \
    make package/luci-app-singbox-ui/compile V=s -j$(nproc)

# --- Новый вариант рабочий ---
# FROM itdoginfo/openwrt-sdk:24.10.1

# COPY ./luci-app-singbox-ui /builder/package/feeds/luci/luci-app-singbox-ui

# RUN make defconfig && make package/luci-app-singbox-ui/compile  V=s -j4