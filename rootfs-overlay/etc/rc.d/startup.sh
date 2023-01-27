#!/bin/bash
mount /proc
mount /sys
mount /tmp
mount /home
mkdir /dev/pts
mount /dev/pts

mkdir /tmp/var
mkdir /tmp/run
mkdir /var/lib
mkdir -p /var/log
touch /tmp/resolv.conf

/bin/load-modules.sh MODULES
chown root:dialout /dev/ttyAMA0
chmod 660 /dev/ttyAMA0

syslogd
dmesg --console-level 2
hostname --file /etc/hostname
ifup lo
setupcon
chvt 2

