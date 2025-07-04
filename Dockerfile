# Используем официальный образ Ubuntu как базу
FROM ubuntu:22.04

ARG TARGET
ARG SUBTARGET
ARG SDK_VERSION

# Установим нужные зависимости
RUN apt update && \
    apt install -y build-essential clang flex bison g++ gawk gcc-multilib \
    gettext git libncurses-dev libssl-dev python3-distutils python3-setuptools \
    rsync unzip zlib1g-dev file wget python3 tar xz-utils

# Скачиваем и распаковываем SDK
RUN set -ex && \
    if [ "$SDK_VERSION" = "snapshot" ]; then \
      SDK_BASE="https://downloads.openwrt.org/snapshots/targets/${TARGET}/${SUBTARGET}"; \
      SDK_FILE=$(wget -qO- $SDK_BASE | grep -o "openwrt-sdk-${TARGET}-${SUBTARGET}_gcc-.*\.tar\.xz" | head -n1); \
    else \
      SDK_BASE="https://downloads.openwrt.org/releases/${SDK_VERSION}/targets/${TARGET}/${SUBTARGET}"; \
      SDK_FILE="openwrt-sdk-${SDK_VERSION}-${TARGET}-${SUBTARGET}_gcc-13.2.0_musl.Linux-x86_64.tar.xz"; \
    fi && \
    echo "Downloading $SDK_FILE from $SDK_BASE" && \
    wget "$SDK_BASE/$SDK_FILE" -O sdk.tar.xz && \
    tar -xf sdk.tar.xz && \
    mv openwrt-sdk-* /sdk

WORKDIR /sdk

# Копируем исходники в SDK
COPY ./luci-app-singbox-ui ./package/feeds/luci/luci-app-singbox-ui

# Обновляем feeds и компилируем
RUN ./scripts/feeds update -a && \
    ./scripts/feeds install -a && \
    make defconfig && \
    make package/luci-app-singbox-ui/compile V=s -j$(nproc)
