#!/bin/sh

wget -O /root/luci-app-singb.ipk https://github.com/Vancltkin/singb/releases/latest/download/luci-app-singb.ipk
chmod 0755 /root/luci-app-singb.ipk
opkg update && opkg install openssh-sftp-server nano curl jq
opkg install /root/luci-app-singb.ipk
/etc/init.d/uhttpd restart
