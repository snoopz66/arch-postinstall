# arch-postinstall

Post-archinstall setup: NVIDIA (open DKMS), Hyprland (Lua config), a HyDE-styled shell (waybar, rofi, hyprlock, wlogout, swaync, regreet) coloured from the wallpaper by matugen, dev tools, snapper + Limine snapshots.

Run as your user after first boot:

```
git clone https://github.com/snoopz66/arch-postinstall && bash arch-postinstall/arch-postinstall.sh
```

Layout: `config/` → `~/.config`, `bin/` → `~/.local/bin`, `etc/` → `/etc`. Existing user files are kept. `monitors.lua` and `input.lua` are generated from `MONITOR`, `MONITOR_MODE`, `KB_LAYOUT` at the top of the script.

Toggles: `INSTALL_GAMING=0 SETUP_SNAPSHOTS=0 SWITCH_TO_NM=0 NVIDIA_DOCKER=0`. The script asks for a git name and email at the start unless git already has them or `GIT_NAME`/`GIT_EMAIL` are set.

Change wallpaper and colours: `wallpaper ~/Pictures/some.jpg`.

The rofi launcher has a calculator mode from `rofi-calc`: `Super+C` opens it, `Return` copies the result. `Ctrl+Tab` switches between its modes (apps, calculator, windows, run).

Widgets are Quickshell (`config/quickshell`), themed from the same matugen palette through `~/.cache/wallpaper/colors.json`. The audio popup (volume, devices, peak meters) opens from the bar's volume module or `qs ipc call audio toggle`.

The app launcher (`Super+Space`) is Quickshell (`config/quickshell/Launcher.qml`), replacing rofi's drun mode with the same theme minus the mode switcher: type to filter, `Up`/`Down` and `Return` launch, `Escape` or a click outside closes. It can also be opened with `qs ipc call launcher toggle`.

The login screen (regreet inside Hyprland) mirrors the session: `greeter-sync` copies the wallpaper, colours and monitor layout into `/var/lib/greeter` whenever the wallpaper changes, Hyprland reloads its config or a monitor is (un)plugged.
