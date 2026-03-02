#!/bin/sh
# deploy.sh — Copy scripts to reMarkable and run enable-usb-keyboard
#
# Usage: ./deploy.sh [remarkable-ip]
#   Default IP: 192.168.1.211 (WiFi) or 10.11.99.1 (USB)

set -e

REMARKABLE_IP="${1:-10.11.99.1}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Deploying to reMarkable at $REMARKABLE_IP..."

# Ensure WiFi SSH is enabled first (needed if switching away from USB)
ssh "root@${REMARKABLE_IP}" 'command -v rm-ssh-over-wlan >/dev/null && rm-ssh-over-wlan on || true'

# Copy scripts
scp "$SCRIPT_DIR/enable-usb-keyboard.sh" \
    "$SCRIPT_DIR/disable-usb-keyboard.sh" \
    "$SCRIPT_DIR/wifi-ssh-on.sh" \
    "$SCRIPT_DIR/wifi-ssh-off.sh" \
    "root@${REMARKABLE_IP}:/home/root/"
ssh "root@${REMARKABLE_IP}" 'chmod +x /home/root/enable-usb-keyboard.sh /home/root/disable-usb-keyboard.sh /home/root/wifi-ssh-on.sh /home/root/wifi-ssh-off.sh'

echo "Scripts deployed. Run on reMarkable:"
echo "  USB keyboard on:  ssh root@192.168.1.211 /home/root/enable-usb-keyboard.sh"
echo "  USB keyboard off: ssh root@192.168.1.211 /home/root/disable-usb-keyboard.sh"
echo "  WiFi SSH on:      ssh root@10.11.99.1 /home/root/wifi-ssh-on.sh"
echo "  WiFi SSH off:     ssh root@10.11.99.1 /home/root/wifi-ssh-off.sh"

# Ask before running
printf "Run enable-usb-keyboard.sh now? [y/N] "
read -r answer
if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
    # If we deployed over USB, switch to WiFi for the enable step
    WIFI_IP="192.168.1.211"
    echo "Running enable script over WiFi ($WIFI_IP)..."
    ssh "root@${WIFI_IP}" /home/root/enable-usb-keyboard.sh
fi
