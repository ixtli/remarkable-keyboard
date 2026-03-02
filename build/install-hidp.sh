#!/bin/sh
# install-hidp.sh — Deploy hidp.ko to reMarkable and enable BT keyboard at boot
#
# Runs on Mac. Connects to device via SSH (USB or WiFi).
# Idempotent — safe to re-run at any time.
#
# What it does:
#   1. Copies hidp.ko to /lib/modules/<version>/kernel/net/bluetooth/hidp/
#   2. Runs depmod to update module database
#   3. Removes btnxpuart blacklist on persistent rootfs (survives reboot)
#
# After install + reboot, BT keyboard auto-connects with no manual steps.
#
# Usage: ./install-hidp.sh [device-ip]
#   Default: 10.11.99.1 (USB)

set -e

REMARKABLE_IP="${1:-10.11.99.1}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HIDP_KO="$SCRIPT_DIR/output/hidp.ko"

if [ ! -f "$HIDP_KO" ]; then
    echo "ERROR: output/hidp.ko not found. Run ./build-hidp.sh first." >&2
    exit 1
fi

echo "Installing hidp.ko to reMarkable at $REMARKABLE_IP..."

# Get kernel version from device
KVER=$(ssh -o ConnectTimeout=5 "root@${REMARKABLE_IP}" 'uname -r')
echo "Device kernel: $KVER"

MODULE_DIR="/lib/modules/$KVER/kernel/net/bluetooth/hidp"

# Deploy hidp.ko
# Root filesystem is ext4 rw on mmcblk0p2 — module directory persists
ssh "root@${REMARKABLE_IP}" "mkdir -p $MODULE_DIR"
scp "$HIDP_KO" "root@${REMARKABLE_IP}:${MODULE_DIR}/hidp.ko"
echo "Copied hidp.ko to $MODULE_DIR/"

# Update module database
ssh "root@${REMARKABLE_IP}" "depmod -a"
echo "Module database updated."

# Remove btnxpuart blacklist on the persistent rootfs.
# /etc is a volatile overlay (upperdir=/var/volatile/etc) — editing /etc
# directly is lost on reboot. Must mount the root partition separately
# and modify the underlying file.
echo "Checking btnxpuart blacklist..."
ssh "root@${REMARKABLE_IP}" '
    mkdir -p /tmp/rootfs
    mount /dev/mmcblk0p2 /tmp/rootfs 2>/dev/null || true

    BLACKLIST="/tmp/rootfs/etc/modprobe.d/btnxpuart.conf"
    if [ -f "$BLACKLIST" ] && grep -q "^blacklist" "$BLACKLIST"; then
        echo "# blacklist removed to enable BT keyboard at boot" > "$BLACKLIST"
        echo "Blacklist removed (persistent)."
    else
        echo "Blacklist already cleared."
    fi

    umount /tmp/rootfs 2>/dev/null || true
    rmdir /tmp/rootfs 2>/dev/null || true
'

echo ""
echo "Done. BT keyboard will auto-connect after reboot."
echo ""
echo "Boot chain: btnxpuart loads -> bluetooth.service starts -> keyboard reconnects -> hidp auto-loads"
echo ""
echo "To verify now (without reboot):"
echo "  ssh root@${REMARKABLE_IP} 'modprobe btnxpuart && insmod ${MODULE_DIR}/hidp.ko && /usr/libexec/bluetooth/bluetoothd -n &'"
echo "  ssh root@${REMARKABLE_IP} 'sleep 2 && echo -e \"power on\nconnect 6C:93:08:62:5C:BF\nquit\n\" | bluetoothctl'"
