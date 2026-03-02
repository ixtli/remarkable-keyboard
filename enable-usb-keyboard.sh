#!/bin/sh
# enable-usb-keyboard.sh — Idempotent script to enable USB keyboard on reMarkable Paper Pro 2
#
# Prerequisites:
#   - reMarkable Paper Pro 2 in developer mode
#   - USB-C to USB-A OTG adapter (C male → A female)
#   - Powered USB-A hub (with its own AC adapter)
#   - USB keyboard plugged into the powered hub
#
# Hardware chain (can be pre-connected, no plug/unplug needed):
#   reMarkable [USB-C] → OTG adapter → powered USB-A hub → keyboard
#
# This script is meant to run ON the reMarkable via SSH over WiFi.
# It can be re-run safely; all operations are idempotent.

set -e

log() { echo "[usb-keyboard] $*"; }

# 1. Enable SSH over WiFi (so we don't lose access when USB switches to host)
if ! systemctl is-active --quiet dropbear-wlan.socket 2>/dev/null; then
    log "Enabling SSH over WiFi..."
    rm-ssh-over-wlan on
else
    log "SSH over WiFi already enabled."
fi

# 2. Disable autosleep (prevents kernel from suspending and tearing down USB host)
current_autosleep=$(cat /sys/power/autosleep 2>/dev/null || echo "unknown")
if [ "$current_autosleep" != "off" ]; then
    log "Disabling autosleep (was: $current_autosleep)..."
    echo off > /sys/power/autosleep
else
    log "Autosleep already disabled."
fi

# 3. Mask systemd suspend targets (belt-and-suspenders with autosleep)
for target in suspend.target sleep.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target; do
    state=$(systemctl is-enabled "$target" 2>/dev/null || echo "unknown")
    if [ "$state" != "masked" ]; then
        log "Masking $target..."
        systemctl mask "$target" 2>/dev/null
    fi
done
log "Suspend targets masked."

# 4. Unbind USB gadget (frees the USB controller from ethernet-over-USB duty)
gadget_udc=$(cat /sys/kernel/config/usb_gadget/g_ether/UDC 2>/dev/null || echo "")
if [ -n "$gadget_udc" ]; then
    log "Unbinding USB gadget (was bound to: $gadget_udc)..."
    echo "" > /sys/kernel/config/usb_gadget/g_ether/UDC
else
    log "USB gadget already unbound."
fi

# 5. Switch USB controller ci_hdrc.0 to host mode
role=$(cat /sys/devices/platform/soc@0/32c00000.bus/32e40000.usb/ci_hdrc.0/role 2>/dev/null || echo "")
if [ "$role" != "host" ]; then
    log "Switching ci_hdrc.0 to host mode (was: $role)..."
    echo host > /sys/devices/platform/soc@0/32c00000.bus/32e40000.usb/ci_hdrc.0/role
else
    log "ci_hdrc.0 already in host mode."
fi

# 6. Load USB HID driver
if ! lsmod | grep -q usbhid; then
    log "Loading usbhid module..."
    modprobe usbhid
else
    log "usbhid module already loaded."
fi

# 7. Rebind fusb303b to trigger clean CC renegotiation as source.
#    This is the critical step — just writing to port_type on the existing typec port
#    does not reliably trigger CC renegotiation. The unbind/rebind creates a fresh
#    typec port and forces a proper handshake with whatever is plugged in.
#    The port number increments each rebind (port0 → port1 → port2...).
log "Rebinding fusb303b for clean CC negotiation..."
echo "4-0021" > /sys/bus/i2c/drivers/fusb303b/unbind 2>/dev/null || true
sleep 1
echo "4-0021" > /sys/bus/i2c/drivers/fusb303b/bind 2>/dev/null || true
sleep 2

# 8. Set the new Type-C port to source mode
TYPEC_PORT=$(ls /sys/class/typec/ 2>/dev/null | grep "^port[0-9]*$" | tail -n 1)
if [ -n "$TYPEC_PORT" ]; then
    log "Setting Type-C $TYPEC_PORT to source mode..."
    echo source > /sys/class/typec/$TYPEC_PORT/port_type 2>/dev/null || true
    echo source > /sys/class/typec/$TYPEC_PORT/preferred_role 2>/dev/null || true
else
    log "WARNING: No typec port found after rebind."
fi

# 9. Wait for USB enumeration
log "Waiting for USB devices to enumerate..."
sleep 5

# 10. Report results
keyboard_found=0
if cat /proc/bus/input/devices 2>/dev/null | grep -qi "keyboard.*usb\|usb.*keyboard\|keychron\|hid.*keyboard"; then
    keyboard_found=1
fi

if [ "$keyboard_found" = "1" ]; then
    log "SUCCESS: USB keyboard detected!"
    cat /proc/bus/input/devices | grep -B1 "Handlers=.*kbd" | grep "^N:" | sed 's/^/  /'
else
    log "No USB keyboard detected yet."
    log "If hardware is already connected, it should appear within a few seconds."
    log "Check: cat /proc/bus/input/devices"
fi

log ""
log "NOTE: Battery indicator shows empty while in USB host mode."
log "This is cosmetic — actual battery level is tracked correctly."
log "Check real battery: cat /sys/class/power_supply/max1726x_battery/capacity"
