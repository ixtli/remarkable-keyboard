# reMarkable Paper Pro — Keyboard & Developer Tools

Use a Bluetooth or USB keyboard with a reMarkable Paper Pro.

> **WARNING: Developer mode required.** Everything in this project requires your reMarkable to be in [developer mode](https://support.remarkable.com/s/article/Developer-mode). Enabling developer mode **performs a factory reset** and erases all data on the device. Back up your work first. This cannot be undone without another factory reset.

**Designed for use with [Claude Code](https://claude.ai/claude-code)** — the `CLAUDE.md` file gives Claude full context to help you set up, troubleshoot, and extend this project. You can also do everything manually with the scripts and instructions below.

## Bluetooth Keyboard (Recommended)

No extra hardware needed. The reMarkable has a Bluetooth chip (NXP 88W8987) but the stock kernel doesn't include the HID Profile module (`hidp.ko`). This project cross-compiles it and installs it so BT keyboards auto-connect at boot.

### Prerequisites

- reMarkable Paper Pro in [developer mode](https://support.remarkable.com/s/article/Developer-mode)
- SSH access to device (USB cable)
- Docker (for cross-compiling the kernel module)
- A Bluetooth keyboard

### Quick Start

```sh
# 1. Download prerequisites (not included in repo due to size)
#    - SDK: remarkable-production-image-5.5.125-ferrari-public-x86_64-toolchain.sh
#      Save as build/toolchain.sh
#    - Kernel source: git clone https://github.com/reMarkable/linux-imx-rm
#      into build/linux-imx-rm/ and extract the tarball inside

# 2. Build the Bluetooth HID module
cd build
./build-hidp.sh

# 3. Install to device (over USB SSH)
./install-hidp.sh

# 4. Reboot the reMarkable — BT keyboard auto-connects
```

After install, the boot chain is fully automatic:
```
btnxpuart loads → bluetooth.service starts → adapter powers on → keyboard reconnects → hidp auto-loads
```

The keyboard survives sleep/wake cycles (keypress wakes the device) and reboots.

### Pairing a New Keyboard

```sh
ssh root@10.11.99.1 '
  echo -e "power on\nscan on\n" | bluetoothctl
'
# Wait for your keyboard to appear, then:
ssh root@10.11.99.1 '
  echo -e "pair <BD_ADDR>\ntrust <BD_ADDR>\nconnect <BD_ADDR>\nquit\n" | bluetoothctl
'
```

## USB Keyboard (Fallback)

Requires: USB-C OTG adapter + powered USB-A hub + keyboard.

```sh
# Deploy scripts to device
./deploy.sh

# Enable (WiFi SSH must be on first)
ssh root@10.11.99.1 /home/root/wifi-ssh-on.sh
ssh root@192.168.1.211 /home/root/enable-usb-keyboard.sh

# Disable
ssh root@192.168.1.211 /home/root/disable-usb-keyboard.sh
ssh root@10.11.99.1 /home/root/wifi-ssh-off.sh
```

## Repository Structure

```
├── CLAUDE.md                    # Claude Code project instructions
├── deploy.sh                    # Deploy device scripts over SSH
├── enable-usb-keyboard.sh       # Switch USB to host mode (runs on device)
├── disable-usb-keyboard.sh      # Restore USB gadget mode (runs on device)
├── wifi-ssh-on.sh               # Enable WiFi SSH (runs on device)
├── wifi-ssh-off.sh              # Disable WiFi SSH (runs on device)
└── build/
    ├── build-hidp.sh            # Cross-compile hidp.ko via Docker
    ├── install-hidp.sh          # Deploy module + remove BT blacklist
    ├── Dockerfile.hidp          # Docker build for hidp.ko
    ├── Dockerfile.base          # Base image with SDK (for debugging)
    └── Module.symvers           # Device-extracted symbol CRCs
```

**Not included (too large):**
- `build/toolchain.sh` — reMarkable SDK installer (~464MB). Download from reMarkable's public release artifacts.
- `build/linux-imx-rm/` — Kernel source (~2.1GB). Clone from https://github.com/reMarkable/linux-imx-rm branch `rmpp_6.12.34_v3.25.x`.

## After a Factory Reset

```sh
cd build
./build-hidp.sh       # Rebuild module (~20 min on Apple Silicon)
./install-hidp.sh     # Deploy + configure
# Reboot — done
```

If the kernel version changed, you'll also need to re-extract `Module.symvers` from the device. See `CLAUDE.md` or ask Claude Code for help.

## Tested Hardware

- **Keychron K7 Pro** (Bluetooth Classic)
- **Apple Magic Keyboard (USB-C, 2024)** — VID 05ac PID 0320 (Bluetooth Classic)
- reMarkable Paper Pro, firmware 5.5.125, kernel 6.12.34

### Apple Keyboard Notes

Apple keyboards need an extra config change (`ClassicBondedOnly=false` in `input.conf`) because they send `store_hint=0` during pairing, preventing BlueZ from persisting link keys. The install script handles this automatically.

Apple keyboards also don't show up in `bluetoothctl scan` — use `hcitool scan` to find the address, then `hcitool cc <addr>` before pairing in `bluetoothctl`. macOS will silently auto-pair Apple keyboards when plugged in via USB — disable Bluetooth on the Mac first or the keyboard will reconnect there instead.
