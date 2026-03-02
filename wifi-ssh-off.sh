#!/bin/sh
# wifi-ssh-off.sh — Disable SSH over WiFi on reMarkable
# Run from Mac over USB: ssh root@10.11.99.1 /home/root/wifi-ssh-off.sh
# Can also be run over WiFi (connection will drop after execution).

set -e
rm-ssh-over-wlan off
echo "WiFi SSH disabled."
