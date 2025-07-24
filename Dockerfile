# Dockerfile
FROM openwrt/sdk:x86_64-v24.10.1

# Обновление фидов и подготовка директорий
RUN ./scripts/feeds update -a && \
    ./scripts/feeds install luci-base && \
    mkdir -p /builder/package/feeds/luci/

# Копируем сам пакет внутрь сборки
COPY ./luci-app-singbox-ui /builder/package/feeds/luci/luci-app-singbox-ui

# Включаем пакет явно и запускаем сборку
RUN echo "CONFIG_PACKAGE_luci-app-singbox-ui=y" >> .config && \
    make defconfig && \
    make package/luci-app-singbox-ui/compile V=s -j4
