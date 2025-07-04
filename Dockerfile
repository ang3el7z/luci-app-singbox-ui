ARG ARCH=x86_64
ARG VERSION=23.05.5
FROM openwrt/sdk:${ARCH}-v${VERSION}

WORKDIR /builder

# Обновляем feeds и устанавливаем luci-base
RUN ./scripts/feeds update -a && \
    ./scripts/feeds install luci-base

# Копируем ваш пакет
COPY ./luci-app-singbox-ui ./package/feeds/luci/luci-app-singbox-ui

# Собираем пакет
RUN make defconfig && \
    make package/luci-app-singbox-ui/compile V=s -j$(nproc)
