# --- ✅Прошлый вариант, рабочий✅ ---
# FROM openwrt/sdk:x86_64-v23.05.5

# # 1) ставим необходимые инструменты для feeds
# USER root
# RUN apt-get update && \
#     apt-get install -y --no-install-recommends git wget subversion mercurial && \
#     rm -rf /var/lib/apt/lists/*
    
# WORKDIR /builder
    
# # 2) обновляем и устанавливаем все feeds (или только luci, если нужно)
# RUN ./scripts/feeds update -a && \
#     ./scripts/feeds install -a
    
# # 3) создаём папки (обратите внимание: utilities, а не utilites)
# RUN mkdir -p /builder/package/feeds/utilities \
#                  /builder/package/feeds/luci
    
# # 4) копируем ваш пакет
# COPY ./luci-app-singbox-ui /builder/package/feeds/luci/luci-app-singbox-ui
    
# # 5) генерим дефолтную конфигурацию и собираем ваш пакет
# RUN make defconfig && \
#     make package/luci-app-singbox-ui/compile V=s -j$(nproc)

# --- ❌Новый вариант рабочий, но с ошибками❌ ---
# FROM itdoginfo/openwrt-sdk:24.10.1

# COPY ./luci-app-singbox-ui /builder/package/feeds/luci/luci-app-singbox-ui

# RUN make defconfig && make package/luci-app-singbox-ui/compile  V=s -j4

# --- ⏳Новый ещё один⏳---
FROM openwrt/sdk:x86_64-v23.05.5

# 1. Устанавливаем зависимости для feeds
USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends git wget subversion mercurial && \
    rm -rf /var/lib/apt/lists/*
    
# 2. Устанавливаем рабочую директорию
WORKDIR /builder
    
# 3. Обновляем и устанавливаем feeds
RUN ./scripts/feeds update -a && \
    ./scripts/feeds install -a
    
# 4. Создаём директории
RUN mkdir -p /builder/package/feeds/utilities \
                 /builder/package/feeds/luci
    
# 5. Копируем ваш пакет
COPY ./luci-app-singbox-ui /builder/package/feeds/luci/luci-app-singbox-ui
    
# 6. Создаём .config вручную (важно: пути и пакеты должны быть корректны!)
RUN cat <<EOF > /builder/.config
    CONFIG_MODULES=y
    CONFIG_HAVE_DOT_CONFIG=y
    
    CONFIG_TARGET_x86=y
    CONFIG_TARGET_x86_generic=y
    CONFIG_TARGET_x86_generic_DEVICE_generic=y
    
    CONFIG_PACKAGE_luci=y
    CONFIG_PACKAGE_luci-base=y
    CONFIG_PACKAGE_luci-app-singbox-ui=y
    
    CONFIG_PACKAGE_sing-box=y
    CONFIG_PACKAGE_curl=y
    CONFIG_PACKAGE_jq=y
    
    CONFIG_DEVEL=n
    CONFIG_TOOLCHAINOPTS=n
    EOF
    
# 7. Генерируем итоговую конфигурацию и собираем пакет
RUN make defconfig && \
    make package/luci-app-singbox-ui/compile V=s -j$(nproc)
    
