FROM openwrt/sdk:x86_64-v24.10.1

RUN ./scripts/feeds update -a && ./scripts/feeds install luci-base && mkdir -p /builder/package/feeds/utilites/ && mkdir -p /builder/package/feeds/luci/

COPY ./luci-app-singbox-ui /builder/package/feeds/luci/luci-app-singbox-ui

RUN make defconfig && make package/luci-app-singbox-ui/compile V=s -j4
