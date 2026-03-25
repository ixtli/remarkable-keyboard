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
#   4. Sets ClassicBondedOnly=false in input.conf (required for Apple keyboards)
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
# Root filesystem may be mounted read-only — remount rw first
ssh "root@${REMARKABLE_IP}" "mount -o remount,rw / && mkdir -p $MODULE_DIR"
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
    # Remount root rw so we can access the underlying rootfs
    mount -o remount,rw /
    mkdir -p /tmp/rootfs
    mount /dev/mmcblk0p2 /tmp/rootfs

    # Remove btnxpuart blacklist
    BLACKLIST="/tmp/rootfs/etc/modprobe.d/btnxpuart.conf"
    if [ -f "$BLACKLIST" ] && grep -q "^blacklist" "$BLACKLIST"; then
        echo "# blacklist removed to enable BT keyboard at boot" > "$BLACKLIST"
        echo "Blacklist removed (persistent)."
    else
        echo "Blacklist already cleared."
    fi

    # Allow HID connections from non-bonded devices (Apple keyboards
    # send store_hint=0 which prevents BlueZ from persisting link keys)
    INPUT_CONF="/tmp/rootfs/etc/bluetooth/input.conf"
    if [ -f "$INPUT_CONF" ] && ! grep -q "^ClassicBondedOnly=false" "$INPUT_CONF"; then
        sed -i "/^\[General\]/a ClassicBondedOnly=false" "$INPUT_CONF"
        echo "ClassicBondedOnly=false set (persistent)."
    else
        echo "ClassicBondedOnly already configured."
    fi

    umount /tmp/rootfs
    rmdir /tmp/rootfs 2>/dev/null
    mount -o remount,ro /
'

echo ""
echo "Done. BT keyboard will auto-connect after reboot."
echo ""
echo "Boot chain: btnxpuart loads -> bluetooth.service starts -> keyboard reconnects -> hidp auto-loads"
echo ""
echo "To verify now (without reboot):"
echo "  ssh root@${REMARKABLE_IP} 'modprobe btnxpuart && insmod ${MODULE_DIR}/hidp.ko && /usr/libexec/bluetooth/bluetoothd -n &'"
echo "  ssh root@${REMARKABLE_IP} 'sleep 2 && echo -e \"power on\nconnect 6C:93:08:62:5C:BF\nquit\n\" | bluetoothctl'"
