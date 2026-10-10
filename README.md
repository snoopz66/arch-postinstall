# arch-postinstall

Post-archinstall setup: NVIDIA (open DKMS), Hyprland (Lua config), a HyDE-styled shell (waybar, Quickshell, hyprlock, wlogout, swaync, regreet) coloured from the wallpaper by matugen, dev tools, snapper + Limine snapshots.

Run as your user after first boot:

```
git clone https://github.com/snoopz66/arch-postinstall && bash arch-postinstall/arch-postinstall.sh
```

Layout: `config/` → `~/.config`, `bin/` → `~/.local/bin`, `etc/` → `/etc`. Existing user files are kept. `monitors.lua` and `input.lua` are generated from `MONITOR`, `MONITOR_MODE`, `KB_LAYOUT` at the top of the script.

Toggles: `INSTALL_GAMING=0 SETUP_SNAPSHOTS=0 SWITCH_TO_NM=0 NVIDIA_DOCKER=0`. The script asks for a git name and email at the start unless git already has them or `GIT_NAME`/`GIT_EMAIL` are set.

Change wallpaper and colours: `wallpaper ~/Pictures/some.jpg`.

kubectl aliases (`config/kubectl_aliases.sh`, sourced from `~/.bashrc`): `k`, then verb and resource initials (`kgp` get pods, `kdd` describe deployment, `klf` logs -f), plus `kns`/`kctx` to switch namespace and context. The file's header explains the pattern.

Widgets are Quickshell (`config/quickshell`), themed from the same matugen palette through `~/.cache/wallpaper/colors.json`. The audio popup (volume, devices, peak meters) opens from the bar's volume module or `qs ipc call audio toggle`.

The app launcher (`Super+Space`, `config/quickshell/Launcher.qml`): type to filter, `Up`/`Down` and `Return` launch, `Escape` or a click outside closes. It is also the calculator: type an expression (`2+2`, `(1200*3)/7`, `5 km to miles`) and the result is the first row, `Return` copies it. `qalc` does the maths; start with `=` to send it anything (`=sqrt(pi)`). It is a spell checker as well: a single word that matches no app is checked by `hunspell` against the dictionary of the session's locale (`hunspell-en_us` is installed), and the rows are the word with a tick if it is right or its corrections if it is not; `Return` copies the selected one. It can also be opened with `qs ipc call launcher toggle`.

The other menus are Quickshell too (`Menu.qml`, `WallpaperPicker.qml`), opened with `qs ipc call menu toggle <list>`: `quick` (`Super+Alt+Space`: wallpaper, screenshot, keybinds), `windows` (`Alt+Tab`, most recent first, the previous window preselected), `clipboard` (`Super+V`, cliphist) and `keybinds`. The wallpaper picker is `qs ipc call wallpapers toggle`: thumbnails of `~/Pictures/Wallpapers` and the stock walls.

Windows that ask for focus get it (`misc:focus_on_activate`): clicking a notification jumps to the window that sent it, and a link opened by another program (`gh auth login`, `xdg-open`) jumps to the browser, switching workspace if needed. Only works for apps whose notifications carry a default action.

The login screen (regreet inside Hyprland) mirrors the session: `greeter-sync` copies the wallpaper, colours and monitor layout into `/var/lib/greeter` whenever the wallpaper changes, Hyprland reloads its config or a monitor is (un)plugged.
