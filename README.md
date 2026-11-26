# arch-postinstall

Post-archinstall setup: NVIDIA (open DKMS), Hyprland (Lua config), a Quickshell shell (bar, launcher, notifications) with hyprlock, wlogout and regreet, coloured from the wallpaper by matugen, dev tools, snapper + Limine snapshots.

Run as your user after first boot:

```
git clone https://github.com/snoopz66/arch-postinstall && bash arch-postinstall/arch-postinstall.sh
```

Layout: `config/` → `~/.config`, `bin/` → `~/.local/bin`, `etc/` → `/etc`. Existing user files are kept. `monitors.lua` and `input.lua` are generated from `MONITOR`, `MONITOR_MODE`, `KB_LAYOUT` at the top of the script.

Toggles: `INSTALL_GAMING=0 SETUP_SNAPSHOTS=0 SWITCH_TO_NM=0 NVIDIA_DOCKER=0`. The script asks for a git name and email at the start unless git already has them or `GIT_NAME`/`GIT_EMAIL` are set.

Change wallpaper and colours: `wallpaper ~/Pictures/some.jpg`.

kubectl aliases (`config/kubectl_aliases.sh`, sourced from `~/.bashrc`): `k`, then verb and resource initials (`kgp` get pods, `kdd` describe deployment, `klf` logs -f), plus `kns`/`kctx` to switch namespace and context. The file's header explains the pattern.

The shell is Quickshell (`config/quickshell`), themed from the same matugen palette through `~/.cache/wallpaper/colors.json`.

The bar is [Omarchy](https://github.com/omacom/omarchy)'s (`config/quickshell/{bar,panels,services}`, see `LICENSE.omarchy`), without its branding, menu and updater. Left to right: power menu, workspaces, status indicators (screen recording, night light, Do Not Disturb, stay awake; the idle ones appear on hover), clock, now playing, tray, Dropbox, keyboard layout, agents, Tailscale, Bluetooth, display, audio, network. A click opens a widget's panel: calendar, AI agent limits, volume and devices, Wi-Fi with a DNS switch (DHCP, Cloudflare, Google), Bluetooth devices, Tailscale machines, display settings, Dropbox. Right-click the clock to change its format. The panels also open with `qs ipc call agents|audio|network|bluetooth|clock|tailscale|monitor|dropbox toggle`; `qs ipc call bar toggle` hides the bar. Drag a widget to move it, drag the bar itself to another screen edge, double-click an empty stretch of it to change its background.

The agents panel (the robot) shows the plan, limits and token use of the coding agents signed in here: Claude Code, Codex and Gemini (Antigravity). `bar-agent-usage-update` refreshes it every 15 minutes and when the panel opens: one collector per agent reads that agent's own history on disk and asks its provider for the limits with the CLI's sign-in (Anthropic's usage endpoint, `codex app-server`, Google's Cloud Code API). An agent is signed in with its own CLI. A line's `>_` opens the CLI in a terminal; deleting a line only hides it, and `qs ipc call agents showAgent claude true` brings it back. Middle-click the robot to refresh.

The display panel (the screen) sets a display's scale, resolution, refresh rate and rotation (`r`), arranges several displays by dragging them, and has one text size for the shell, GTK apps and Ghostty. A monitor that answers DDC/CI (`ddcutil`) also gets a brightness slider, and the wheel over the icon dims it. What is chosen is kept per monitor in `~/.local/state/bar/monitors/settings` and applied over `monitors.lua` by `hypr/monitor-settings.lua`; delete that file to go back to `monitors.lua`. Omarchy's Mirror is not carried.

The Dropbox panel shows what is stored and the files changed last; a click on one selects it in Files, and the switch pauses and resumes syncing (`dropbox-cli`). With the widget on the bar the tray leaves Dropbox's own icon out.

The layout is `~/.config/bar/bar.json` (`config/bar/`): `position` (`top`, `bottom`, `left`, `right`), `background` (`pills`, `glassy`, `opaque`, `none`) and the widgets per section. `pills` blurs what is behind the bar and draws a rounded pill behind each of the left, center and right groups. The bar's height and the kit's text size are `[bar]` and `[font]` in `~/.config/quickshell/shell.toml`; the text size is shared by the bar's panels, notifications and the launcher. Also available: `active-window`, `microphone`, `spacer`. The bar rewrites the file when a widget's setting changes. `screenrecord [start|stop|toggle]` records the screen into `~/Videos/Recordings`; the indicator starts and stops it too.

The launcher (`Super+Space`) is [Keystroke](https://github.com/evindor/keystroke) (`config/quickshell/keystroke`, v1.5.2, adapted from its Omarchy plugin; MIT, see its `LICENSE`). Type anything: apps (the ones you pick most rise), files and folders under `~`, a sum (`128 * 1.24`, `15% of 80`), a conversion (`5 km to miles`, `10am pt`), a colour (`#ff6644`), a web address, or a Hyprland keybind by what it does (`lock`, `fullscreen`), which `Return` then runs. Prefixes narrow it: `:` emoji, `~` files only, `>` open windows, `sp` spell check (`sp recieve`; a lone word is also checked below the other results), `/` lists them all. `Return` runs the row, `Ctrl+Return` its second action, `Escape` closes, `Ctrl+,` opens the settings. Clipboard history (cliphist), every keybind and the extensions have screens of their own from the first list. Wallpaper and Screenshot are on the first list too and found by name, and `keybinds` finds the keybind screen. It can also be opened with `qs ipc call launcher toggle`.

Its settings are `~/.config/keystroke/keystroke.json` (`config/keystroke/`), written by the settings screen. Off here: web search and assistant hand-offs (`ai`), Codex, dictation and voice (no voxtype); Smart Match is not included. Extensions of your own go in `~/.config/keystroke/extensions/` (`config/keystroke/extensions/`), where the spell checker and the quick actions live; `docs/providers.md` upstream describes the interface. Card colours are the `[menu]` section of `config/quickshell/shell.toml`.

The other menus are Quickshell too (`Menu.qml`, `WallpaperPicker.qml`), opened with `qs ipc call menu toggle <list>`: `windows` (`Alt+Tab`, most recent first, the previous window preselected) and `clipboard` (`Super+V`, cliphist). The wallpaper picker is `qs ipc call wallpapers toggle`: thumbnails of `~/Pictures/Wallpapers` and the stock walls.

Notifications are Quickshell too (`config/quickshell/notifications`, from [Omarchy](https://github.com/omacom/omarchy) along with its `Commons` and `Ui` kit, see `LICENSE.omarchy`). Cards stack per app or site in the top-right corner and open on hover. A click runs the sender's default action or jumps to its window; right-click or the `✕` dismisses. Action buttons sit along the card's bottom edge, and a verification code gets a copy button. `Super+S` or a click on the bar's bell puts the last few back on screen (kept for a day in `~/.local/state/quickshell/notifications`); right-click the bell for Do Not Disturb. The rest is IPC, for keybinds of your own: `qs ipc call notifications act|dismissOne|dismissAll|keyboard|toggleDnd`. Card colours and opacity are in `config/quickshell/shell.toml`.

Windows that ask for focus get it (`misc:focus_on_activate`): clicking a notification jumps to the window that sent it, and a link opened by another program (`gh auth login`, `xdg-open`) jumps to the browser, switching workspace if needed.

The login screen (regreet inside Hyprland) mirrors the session: `greeter-sync` copies the wallpaper, colours and monitor layout into `/var/lib/greeter` whenever the wallpaper changes, Hyprland reloads its config or a monitor is (un)plugged.

SSH: `sshd` is enabled and takes the user's password (`ssh <user>@<host>`). ufw rate-limits port 22: a source making 6 connections in 30 s is dropped.
