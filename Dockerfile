ARG SDK_VERSION=v23.05.5
ARG ARCH=x86_64

FROM openwrt/sdk:${ARCH}-${SDK_VERSION}

RUN ./scripts/feeds update -a && ./scripts/feeds install luci-base && \
    mkdir -p /builder/package/feeds/utilites/ && mkdir -p /builder/package/feeds/luci/

COPY ./luci-app-singbox-ui /builder/package/feeds/luci/luci-app-singbox-ui

RUN make defconfig && make package/luci-app-singbox-ui/compile V=s -j4
