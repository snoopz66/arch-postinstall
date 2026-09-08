# arch-postinstall

Post-archinstall setup: NVIDIA (open DKMS), Hyprland (Lua config), a HyDE-styled shell (waybar, rofi, hyprlock, wlogout, swaync, regreet) coloured from the wallpaper by matugen, dev tools, snapper + Limine snapshots.

Run as your user after first boot:

```
git clone https://github.com/snoopz66/arch-postinstall && bash arch-postinstall/arch-postinstall.sh
```

Layout: `config/` → `~/.config`, `bin/` → `~/.local/bin`, `etc/` → `/etc`. Existing user files are kept. `monitors.lua` and `input.lua` are generated from `MONITOR`, `MONITOR_MODE`, `KB_LAYOUT` at the top of the script.

Toggles: `INSTALL_GAMING=0 SETUP_SNAPSHOTS=0 SWITCH_TO_NM=0 NVIDIA_DOCKER=0`.

Change wallpaper and colours: `wallpaper ~/Pictures/some.jpg`.
