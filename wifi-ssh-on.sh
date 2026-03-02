#!/bin/sh
# wifi-ssh-on.sh — Enable SSH over WiFi on reMarkable
# Run from Mac over USB: ssh root@10.11.99.1 /home/root/wifi-ssh-on.sh

set -e
rm-ssh-over-wlan on
echo "WiFi SSH enabled. Connect via: ssh root@$(ip -4 addr show wlan0 2>/dev/null | grep -o 'inet [0-9.]*' | cut -d' ' -f2)"
