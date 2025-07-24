FROM itdoginfo/openwrt-sdk:24.10.1

COPY ./luci-app-singbox-ui /builder/package/feeds/luci/luci-app-singbox-ui

RUN make defconfig && make package/luci-app-singbox-ui/compile  V=s -j4
