#!/bin/sh
# pair-apple-kb.sh — Re-pair Apple Magic Keyboard after power cycle
# Apple keyboards don't persist link keys (store_hint=0), so a fresh
# pairing is needed after toggling the power switch.
#
# Usage: /home/root/pair-apple-kb.sh [bd_addr]
#   Default: 38:09:FB:0D:44:97

ADDR="${1:-38:09:FB:0D:44:97}"

echo "Pairing Apple Magic Keyboard ($ADDR)..."

# Remove stale pairing if present
bluetoothctl -- remove "$ADDR" 2>/dev/null

# Create HCI connection (Apple keyboards need this - bluetoothctl scan cannot find them)
hcitool cc "$ADDR" 2>/dev/null
sleep 3

# Pair, trust, connect
bluetoothctl -- pair "$ADDR"
sleep 2
bluetoothctl -- trust "$ADDR"
bluetoothctl -- connect "$ADDR"
