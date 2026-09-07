# arch-postinstall

Post-archinstall setup: NVIDIA (open DKMS), Hyprland (Lua config), Noctalia v5 shell + greeter, dev tools, snapper + Limine snapshots.

Run as your user after first boot:

```
bash <(curl -fsSL https://raw.githubusercontent.com/snoopz66/arch-postinstall/main/arch-postinstall.sh)
```

Toggles: `INSTALL_GAMING=0 SETUP_SNAPSHOTS=0 SWITCH_TO_NM=0 NVIDIA_DOCKER=0`. Edit `MONITOR`, `MONITOR_MODE`, `KB_LAYOUT` at the top for other machines.
