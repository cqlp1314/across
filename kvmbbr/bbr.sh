#!/usr/bin/env bash
# Usage: debian 10 & 9 && linux-image-cloud-amd64 bbr: 
#   export qdisc=fq   && bash <(curl -s https://raw.githubusercontent.com/mixool/across/master/kvmbbr/bbr.sh)                        # 仅开启fq+bbr
#   export qdisc=cake && bash <(curl -s https://raw.githubusercontent.com/mixool/across/master/kvmbbr/bbr.sh)                        # 仅开启cake+bbr
#   export qdisc=cake && bash <(curl -s https://raw.githubusercontent.com/mixool/across/master/kvmbbr/bbr.sh) cloud                  # 危险操作: 安装cloud内核并开启cake+bbr
#   export qdisc=cake && bash <(curl -s https://raw.githubusercontent.com/mixool/across/master/kvmbbr/bbr.sh) removeold              # 危险操作: 卸载未使用内核并开启cake+bbr
###

# only root can run this script
[[ $EUID -ne 0 ]] && echo "Error, This script must be run as root!" && exit 1

# version stretch || buster
version=$(cat /etc/os-release | grep -oE "VERSION_ID=\"(9|10)\"" | grep -oE "(9|10)")
if [[ $version == "9" ]]; then
    backports_version="stretch-backports-sloppy"
else
    [[ $version != "10" ]] && echo "Error, OS should be debian stretch or buster " && exit 1 || backports_version="buster-backports"
fi

# install cloud kernel 
if [[ "$1" == "cloud" ]]; then
    cat /etc/apt/sources.list | grep -q "$backports_version" || echo -e "deb http://deb.debian.org/debian $backports_version main" >> /etc/apt/sources.list
    apt update
    apt -t $backports_version install linux-image-cloud-amd64 linux-headers-cloud-amd64 -y
    update-grub
fi

# remove old kernel  
if [[ "$1" == "removeold" ]]; then
    echo $(dpkg --list | grep linux-image | awk '{ print $2 }' | sort -V | sed -n '/'`uname -r`'/q;p') $(dpkg --list | grep linux-headers | awk '{ print $2 }' | sort -V | sed -n '/'"$(uname -r | sed "s/\([0-9.-]*\)-\([^0-9]\+\)/\1/")"'/q;p') | xargs apt --purge -y autoremove
    update-grub
fi

# bbr 
sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
echo "net.core.default_qdisc = ${qdisc:=fq}" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.conf
echo $(date) /etc/sysctl.conf info:
sysctl -p

# end
if [[ "$1" == "cloud" ]]; then
    read -p "The system needs to reboot. Do you want to restart system? [y/n]" is_reboot
    if [[ ${is_reboot} == "y" || ${is_reboot} == "Y" ]]; then
        echo "Rebooting..." && reboot
    else
        echo "Reboot has been canceled..." && exit 0
    fi
fi
