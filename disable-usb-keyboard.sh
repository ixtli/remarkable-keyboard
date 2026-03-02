#!/bin/sh
# disable-usb-keyboard.sh — Revert to default state (USB gadget/charging mode)
#
# Run ON the reMarkable via SSH over WiFi.
# After running, USB-C will work normally for charging and USB networking.

set -e

log() { echo "[usb-keyboard] $*"; }

# 1. Switch ci_hdrc.0 back to gadget mode
role=$(cat /sys/devices/platform/soc@0/32c00000.bus/32e40000.usb/ci_hdrc.0/role 2>/dev/null || echo "")
if [ "$role" != "gadget" ]; then
    log "Switching ci_hdrc.0 back to gadget mode..."
    echo gadget > /sys/devices/platform/soc@0/32c00000.bus/32e40000.usb/ci_hdrc.0/role
fi

# 2. Re-bind USB gadget (restore USB networking)
gadget_udc=$(cat /sys/kernel/config/usb_gadget/g_ether/UDC 2>/dev/null || echo "")
if [ -z "$gadget_udc" ]; then
    log "Re-binding USB gadget to ci_hdrc.0..."
    echo "ci_hdrc.0" > /sys/kernel/config/usb_gadget/g_ether/UDC 2>/dev/null || true
fi

# 3. Rebind fusb303b for clean CC renegotiation back to default
log "Rebinding fusb303b for clean CC negotiation..."
echo "4-0021" > /sys/bus/i2c/drivers/fusb303b/unbind 2>/dev/null || true
sleep 1
echo "4-0021" > /sys/bus/i2c/drivers/fusb303b/bind 2>/dev/null || true
sleep 2

# 4. Restore Type-C to default sink/dual mode
TYPEC_PORT=$(ls /sys/class/typec/ 2>/dev/null | grep "^port[0-9]*$" | tail -n 1)
if [ -n "$TYPEC_PORT" ]; then
    echo sink > /sys/class/typec/$TYPEC_PORT/preferred_role 2>/dev/null || true
    echo dual > /sys/class/typec/$TYPEC_PORT/port_type 2>/dev/null || true
fi
log "Type-C port restored to default (dual/sink)."

# 5. Restore charger mode (gets stuck in OTG Supply after host mode)
charger_mode=$(cat /sys/class/power_supply/max77963-charger/charger_mode 2>/dev/null || echo "")
if [ "$charger_mode" = "OTG Supply" ]; then
    log "Restoring charger from OTG Supply to Charger mode..."
    echo "Charger" > /sys/class/power_supply/max77963-charger/charger_mode 2>/dev/null || true
else
    log "Charger mode already normal ($charger_mode)."
fi

# 6. Re-enable autosleep
echo mem > /sys/power/autosleep 2>/dev/null || true
log "Autosleep re-enabled."

# 7. Unmask suspend targets
for target in suspend.target sleep.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target; do
    systemctl unmask "$target" 2>/dev/null || true
done
log "Suspend targets unmasked."

log "Done. USB-C is back to default charging/networking mode."
log "You can now use USB networking (10.11.99.1) again."
