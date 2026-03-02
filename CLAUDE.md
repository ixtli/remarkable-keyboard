# reMarkable Paper Pro 2 — Keyboard & Developer Tools

## Device
- **Model**: reMarkable Paper Pro 2
- **SoC**: i.MX8M Mini (aarch64, Cortex-A53)
- **Kernel**: Linux 6.12.34+git-imx8mm-ferrari-g95c3acd37afa
- **SSH**: Dropbear (not OpenSSH)
- **Shell**: BusyBox ash (not bash — no arrays, limited builtins, use `head -n 5` not `head -5`)
- **WiFi IP**: 192.168.1.211
- **USB IP**: 10.11.99.1
- **SSH user**: root (passwordless, ed25519 key)
- **Root filesystem**: ext4 on mmcblk0p2 (rw). `/etc` is a volatile overlay (tmpfs upper at `/var/volatile/etc` — changes lost on reboot). Persistent `/etc` changes require mounting mmcblk0p2 directly.
- **No package manager**, no python, no i2c-tools.

## SSH Connection Order
1. Try WiFi first: `ssh root@192.168.1.211`
2. If that fails, try USB: `ssh root@10.11.99.1`
3. If neither works, ask the user to plug the tablet into the computer with a standard USB-C cable, then retry USB

## Bluetooth Keyboard (Preferred)
No hardware accessories needed. BT keyboard auto-connects at boot.

**Keychron K7 Pro** — BD Address: `6C:93:08:62:5C:BF`
- Device BT chip: NXP 88W8987 on UART1, driver `btnxpuart`
- Device BT address: `24:FD:FA:07:90:04`
- Required module: `hidp.ko` (custom-built, stock kernel has CONFIG_BT_HIDP disabled)

### Boot persistence
BT keyboard auto-starts at boot:
1. `btnxpuart` loads automatically (blacklist removed from persistent rootfs)
2. `bluetooth.service` starts (already enabled, triggers when hci0 appears)
3. `AutoEnable=true` powers on adapter
4. Paired keyboard reconnects → kernel auto-loads `hidp` via `bt-proto-6` alias

### Manual enable (if modules not loaded)
```sh
ssh root@<IP> 'modprobe btnxpuart && insmod /lib/modules/$(uname -r)/kernel/net/bluetooth/hidp/hidp.ko && /usr/libexec/bluetooth/bluetoothd -n & sleep 2 && echo -e "power on\nconnect 6C:93:08:62:5C:BF\nquit\n" | bluetoothctl'
```

### Building hidp.ko (after factory reset or kernel update)
```sh
cd build
./build-hidp.sh      # Cross-compile via Docker (~20 min on Apple Silicon)
./install-hidp.sh    # Deploy to device + remove blacklist
# Reboot device — keyboard auto-connects
```

## USB Keyboard (Fallback)
**Required hardware**: `reMarkable [USB-C] → USB-C-to-USB-A OTG adapter → powered USB-A hub → keyboard`

### Enable
```sh
ssh root@10.11.99.1 /home/root/wifi-ssh-on.sh                  # WiFi SSH first
ssh root@192.168.1.211 /home/root/enable-usb-keyboard.sh       # kills USB networking
```

### Disable
```sh
ssh root@192.168.1.211 /home/root/disable-usb-keyboard.sh      # restore USB networking
ssh root@10.11.99.1 /home/root/wifi-ssh-off.sh                 # disable WiFi SSH
```

## Scripts
| Script | Runs on | Purpose |
|--------|---------|---------|
| `deploy.sh` | Mac | Copy device scripts to `/home/root/` |
| `enable-usb-keyboard.sh` | Device (WiFi SSH) | Switch USB to host mode |
| `disable-usb-keyboard.sh` | Device (WiFi SSH) | Restore USB gadget mode |
| `wifi-ssh-on.sh` | Device (USB SSH) | Enable Dropbear on WiFi |
| `wifi-ssh-off.sh` | Device | Disable Dropbear on WiFi |
| `build/build-hidp.sh` | Mac | Cross-compile hidp.ko via Docker |
| `build/install-hidp.sh` | Mac | Deploy hidp.ko + remove blacklist |

## Known Limitations
- **Battery indicator shows empty** in USB host mode (cosmetic). Real level: `cat /sys/class/power_supply/max1726x_battery/capacity`
- **DO NOT change `charger_mode`** while USB keyboard is connected — instantly disconnects all USB devices
- **hidp.ko must be rebuilt** if device kernel is updated (new vermagic + possibly new CRCs)
- **BT keyboard sleep/wake**: connection breaks on device suspend but auto-reconnects (BlueZ reconnect policy)
- All sysfs changes are volatile (reset on reboot). `systemctl mask` changes persist.
