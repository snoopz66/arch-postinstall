#!/usr/bin/env bash
#
# Arch post-install: NVIDIA, Hyprland (Lua), Noctalia v5, dev tools.
# Run as your user after the first boot of an archinstall system.
# Idempotent: safe to re-run.
#
#   bash arch-postinstall.sh
#
# Toggles:
#   INSTALL_GAMING=0   skip steam, gamemode, gamescope
#   SETUP_SNAPSHOTS=0  skip snapper + limine snapshot boot entries
#   SWITCH_TO_NM=0     keep systemd-networkd (Noctalia wifi widget wants NetworkManager)
#   NVIDIA_DOCKER=0    skip nvidia-container-toolkit

set -euo pipefail

INSTALL_GAMING=${INSTALL_GAMING:-1}
SETUP_SNAPSHOTS=${SETUP_SNAPSHOTS:-1}
SWITCH_TO_NM=${SWITCH_TO_NM:-1}
NVIDIA_DOCKER=${NVIDIA_DOCKER:-1}
DROPBOX_KEY="1C61A2656FB57B7E4DE0F4C1FC918B335044912E"

MONITOR="DP-1"
MONITOR_MODE="5120x1440@120"
KB_LAYOUT="us,no"
KB_OPTIONS="grp:caps_toggle"

HYPR_DIR="$HOME/.config/hypr"
NOCTALIA_DIR="$HOME/.config/noctalia"

# ---------- helpers ----------

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m!! %s\033[0m\n' "$*" >&2; }
die() { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

pac() { sudo pacman -S --needed --noconfirm "$@"; }
aur() { yay -S --needed --noconfirm "$@"; }
svc_enable() { sudo systemctl enable "$@"; }

# write_root PATH  (content on stdin, overwrites)
write_root() { sudo install -Dm644 /dev/stdin "$1"; }

# write_user PATH  (content on stdin, keeps existing file)
write_user() {
  if [[ -e $1 ]]; then
    warn "keep existing $1"
    return
  fi

  install -Dm644 /dev/stdin "$1"
}

preflight() {
  [[ $EUID -ne 0 ]] || die "run as your user, not root"
  command -v pacman >/dev/null || die "not Arch"
  command -v sudo >/dev/null || die "sudo missing"

  sudo -v
  (while true; do sudo -n true; sleep 50; done) &
  SUDO_PID=$!
  trap 'kill $SUDO_PID 2>/dev/null' EXIT
}

# ---------- system ----------

setup_pacman() {
  log "pacman: multilib, color, parallel downloads"
  sudo sed -i 's/^#Color$/Color/; s/^#ParallelDownloads.*/ParallelDownloads = 10/' /etc/pacman.conf
  sudo sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' /etc/pacman.conf
  sudo pacman -Syu --noconfirm
}

install_base() {
  log "base tools, firmware, headers"
  pac base-devel git curl wget rsync unzip zip 7zip tree less man-db man-pages openssh \
    bash-completion linux-firmware amd-ucode linux-headers btrfs-progs
}

install_yay() {
  if command -v yay >/dev/null; then
    return
  fi

  log "yay"
  local tmp
  tmp=$(mktemp -d)
  git clone --depth 1 https://aur.archlinux.org/yay.git "$tmp/yay"
  (cd "$tmp/yay" && makepkg -si --noconfirm)
  rm -rf "$tmp"
}

# https://wiki.hypr.land/nvidia/
install_nvidia() {
  log "NVIDIA open kernel modules (DKMS)"
  pac nvidia-open-dkms nvidia-utils lib32-nvidia-utils egl-wayland libva-nvidia-driver

  write_root /etc/modprobe.d/nvidia.conf <<'EOF'
options nvidia_drm modeset=1
options nvidia NVreg_PreserveVideoMemoryAllocations=1
EOF

  if ! grep -qE '^MODULES=.*nvidia_drm' /etc/mkinitcpio.conf; then
    sudo sed -i -E 's/^MODULES=\((.*)\)/MODULES=(\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/; s/MODULES=\( /MODULES=(/' /etc/mkinitcpio.conf
  fi

  svc_enable nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service
  sudo mkinitcpio -P
}

# https://wiki.archlinux.org/title/Professional_audio
install_audio() {
  log "PipeWire, realtime audio"
  pac pipewire pipewire-pulse pipewire-alsa pipewire-jack wireplumber pavucontrol playerctl \
    realtime-privileges rtkit alsa-utils qpwgraph

  # rtprio 98, memlock unlimited, /dev/cpu_dma_latency
  sudo usermod -aG realtime "$USER"

  write_root /etc/sysctl.d/99-audio.conf <<'EOF'
vm.swappiness = 10
fs.inotify.max_user_watches = 600000
EOF
}

install_network() {
  log "NetworkManager, Bluetooth"
  pac networkmanager iwd bluez bluez-utils
  svc_enable bluetooth.service

  if [[ $SWITCH_TO_NM -eq 0 ]]; then
    return
  fi

  # NM drives iwd, so wifi networks known from the ISO survive
  write_root /etc/NetworkManager/conf.d/wifi-backend.conf <<'EOF'
[device]
wifi.backend=iwd
EOF
}

# Runs last: network changes only take effect at reboot.
switch_network() {
  if [[ $SWITCH_TO_NM -eq 0 ]]; then
    return
  fi

  log "NetworkManager replaces systemd-networkd at next boot"
  sudo systemctl disable systemd-networkd.service systemd-networkd.socket 2>/dev/null || true
  sudo systemctl mask NetworkManager-wait-online.service
  svc_enable systemd-resolved.service iwd.service NetworkManager.service
  sudo ln -sf ../run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
}

# https://wiki.hypr.land/useful-utilities/must-have/
install_hyprland() {
  log "Hyprland and desktop plumbing"
  pac hyprland xdg-desktop-portal-hyprland xdg-desktop-portal-gtk qt5-wayland qt6-wayland \
    polkit gnome-keyring libsecret seahorse hyprpicker wl-clipboard \
    upower power-profiles-daemon accountsservice \
    xdg-user-dirs udiskie gvfs gvfs-mtp \
    noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols inter-font \
    papirus-icon-theme adwaita-icon-theme gnome-themes-extra

  svc_enable upower.service power-profiles-daemon.service accounts-daemon.service
  xdg-user-dirs-update
}

# https://docs.noctalia.dev/greeter/installation/
install_noctalia() {
  log "Noctalia shell and greeter"
  pac noctalia greetd
  aur noctalia-greeter

  write_root /etc/greetd/config.toml <<'EOF'
[terminal]
vt = 1

[default_session]
command = "/usr/bin/noctalia-greeter-session"
user = "greeter"
EOF

  sudo install -d /var/lib/noctalia-greeter
  write_root /var/lib/noctalia-greeter/greeter.toml <<EOF
[session]
default = "Hyprland"

[user]
default = "$USER"
EOF
  sudo chown -R greeter:greeter /var/lib/noctalia-greeter

  # unlock gnome-keyring at login
  if ! grep -q pam_gnome_keyring /etc/pam.d/greetd; then
    printf '%s\n' \
      'auth       optional     pam_gnome_keyring.so' \
      'session    optional     pam_gnome_keyring.so auto_start' |
      sudo tee -a /etc/pam.d/greetd >/dev/null
  fi

  local dm
  for dm in sddm gdm lightdm ly; do
    if systemctl is-enabled -q "$dm.service" 2>/dev/null; then
      sudo systemctl disable "$dm.service"
    fi
  done

  svc_enable greetd.service
}

install_dev() {
  log "developer tools"
  pac btop fzf ripgrep fd bat eza zoxide jq yq tldr tmux starship fastfetch \
    lazygit github-cli stow plocate inotify-tools dua-cli \
    neovim ghostty ghostty-nautilus \
    docker docker-compose docker-buildx ducker \
    openai-codex
  aur visual-studio-code-bin claude-code

  sudo usermod -aG docker "$USER"
  svc_enable docker.socket

  if [[ $NVIDIA_DOCKER -eq 1 ]]; then
    pac nvidia-container-toolkit
    sudo nvidia-ctk runtime configure --runtime=docker
  fi

  if [[ ! -d $HOME/.config/nvim ]]; then
    git clone --depth 1 https://github.com/LazyVim/starter "$HOME/.config/nvim"
    rm -rf "$HOME/.config/nvim/.git"
  fi
}

install_apps() {
  log "desktop apps"
  pac firefox nautilus sushi file-roller loupe papers mpv mpv-mpris obsidian deluge-gtk \
    gnome-disk-utility gpu-screen-recorder discord spotify-launcher \
    btrfs-assistant mission-center tailscale \
    fcitx5 fcitx5-gtk fcitx5-qt fcitx5-configtool
  aur localsend-bin

  svc_enable tailscaled.service
  install_dropbox
}

install_dropbox() {
  # PKGBUILD verifies the Dropbox release signature
  gpg --keyserver keyserver.ubuntu.com --recv-keys "$DROPBOX_KEY"
  aur dropbox nautilus-dropbox
}

install_gaming() {
  if [[ $INSTALL_GAMING -eq 0 ]]; then
    return
  fi

  log "gaming"
  pac steam gamemode gamescope lib32-mesa vulkan-icd-loader lib32-vulkan-icd-loader
}

# ---------- snapshots ----------

create_snapper_root() {
  if [[ -f /etc/snapper/configs/root ]]; then
    return
  fi

  # archinstall mounts @.snapshots on /.snapshots; snapper insists on creating it
  local had_mount=0
  if mountpoint -q /.snapshots; then
    sudo umount /.snapshots
    had_mount=1
  fi

  sudo rm -rf /.snapshots
  sudo snapper --no-dbus -c root create-config /

  if [[ $had_mount -eq 1 ]]; then
    sudo btrfs subvolume delete /.snapshots
    sudo mkdir /.snapshots
    sudo mount /.snapshots
  fi

  sudo chmod 750 /.snapshots
}

setup_snapshots() {
  if [[ $SETUP_SNAPSHOTS -eq 0 ]]; then
    return
  fi

  if ! pacman -Q limine >/dev/null 2>&1; then
    warn "limine not installed, skipping snapshots"
    return
  fi

  log "snapper, snap-pac, limine snapshot entries"
  pac snapper snap-pac
  aur limine-mkinitcpio-hook limine-snapper-sync

  create_snapper_root
  sudo snapper -c root set-config \
    TIMELINE_CREATE=yes TIMELINE_LIMIT_HOURLY=5 TIMELINE_LIMIT_DAILY=7 \
    TIMELINE_LIMIT_WEEKLY=0 TIMELINE_LIMIT_MONTHLY=0 TIMELINE_LIMIT_YEARLY=0 \
    NUMBER_LIMIT=10 NUMBER_LIMIT_IMPORTANT=5 ALLOW_USERS="$USER" SYNC_ACL=yes

  local cmdline
  cmdline=$(sed -E 's/\b(BOOT_IMAGE|initrd)=[^ ]* ?//g' /proc/cmdline)
  # threadirqs: realtime audio
  grep -qw threadirqs <<<"$cmdline" || cmdline+=" threadirqs"
  write_root /etc/limine-entry-tool.d/10-postinstall.conf <<EOF
KERNEL_CMDLINE[default]="$cmdline"
MAX_SNAPSHOT_ENTRIES=5
EOF

  if [[ ! -e /boot/limine.conf.pre-postinstall ]]; then
    sudo cp /boot/limine.conf /boot/limine.conf.pre-postinstall
  fi

  sudo limine-update
  svc_enable snapper-timeline.timer snapper-cleanup.timer limine-snapper-sync.service
}

setup_system() {
  log "system services, zram, firewall"
  pac pacman-contrib kernel-modules-hook zram-generator ufw
  svc_enable fstrim.timer systemd-timesyncd.service paccache.timer \
    linux-modules-cleanup.service systemd-oomd.service

  write_root /etc/systemd/zram-generator.conf <<'EOF'
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
EOF

  sudo ufw default deny incoming
  sudo ufw default allow outgoing
  sudo ufw allow 53317/tcp comment localsend
  sudo ufw allow 53317/udp comment localsend
  sudo ufw allow in on tailscale0
  sudo ufw --force enable
}

# ---------- user ----------

setup_bashrc() {
  local rc="$HOME/.bashrc"
  if grep -q '# >>> postinstall' "$rc" 2>/dev/null; then
    return
  fi

  cat >>"$rc" <<'EOF'

# >>> postinstall >>>
export EDITOR=nvim
export TERMINAL=ghostty
alias ls='eza --icons --group-directories-first'
alias ll='eza -l --icons --group-directories-first'
alias cat='bat --paging=never'
alias lg='lazygit'
source /usr/share/fzf/key-bindings.bash
source /usr/share/fzf/completion.bash
eval "$(zoxide init bash)"
eval "$(starship init bash)"
# <<< postinstall <<<
EOF
}

setup_user() {
  log "user defaults"

  write_user "$HOME/.config/environment.d/10-apps.conf" <<'EOF'
TERMINAL=ghostty
EDITOR=nvim
EOF

  write_user "$HOME/.config/xdg-terminals.list" <<'EOF'
com.mitchellh.ghostty.desktop
EOF

  write_user "$HOME/.config/ghostty/config" <<'EOF'
font-family = JetBrainsMono Nerd Font
font-size = 10
window-padding-x = 12
window-padding-y = 12
confirm-close-surface = false
EOF

  xdg-settings set default-web-browser firefox.desktop 2>/dev/null || true
  xdg-mime default org.gnome.Nautilus.desktop inode/directory
  xdg-mime default org.gnome.Loupe.desktop image/png image/jpeg image/gif image/webp image/svg+xml image/avif
  xdg-mime default mpv.desktop video/mp4 video/x-matroska video/webm audio/mpeg audio/flac
  xdg-mime default org.gnome.Papers.desktop application/pdf

  dbus-run-session -- sh -c "
    gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
    gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
    gsettings set org.gnome.desktop.interface font-name 'Inter 11'
    gsettings set org.gnome.desktop.interface monospace-font-name 'JetBrainsMono Nerd Font 10'
  " || warn "gsettings skipped"

  setup_bashrc
}

# https://docs.noctalia.dev/noctalia/configuration/shell/
write_noctalia_config() {
  log "Noctalia config"
  write_user "$NOCTALIA_DIR/00-base.toml" <<'EOF'
# Hand-written base. Settings UI (~/.local/state/noctalia/settings.toml) wins on conflict.

[shell]
polkit_agent = true
telemetry_enabled = false

[lockscreen]
enabled = true
lock_before_suspend = true

[idle]
behavior_order = ["lock", "screen-off"]

[idle.behavior.lock]
timeout = 600
action = "lock"
enabled = true

[idle.behavior.screen-off]
timeout = 900
action = "screen_off"
enabled = true
EOF
}

# https://wiki.hypr.land/configuring/core/
# https://docs.noctalia.dev/noctalia/compositor-settings/hyprland/
write_hypr_config() {
  log "Hyprland Lua config"

  write_user "$HYPR_DIR/hyprland.lua" <<'EOF'
-- Hyprland Lua config. Docs: https://wiki.hypr.land/configuring/core/
require("env")
require("monitors")
require("input")
require("looknfeel")
require("rules")
require("binds")
require("autostart")
EOF

  write_user "$HYPR_DIR/env.lua" <<'EOF'
-- NVIDIA: https://wiki.hypr.land/nvidia/
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("NVD_BACKEND", "direct")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- Toolkits
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("XMODIFIERS", "@im=fcitx")

-- Default apps
hl.env("TERMINAL", "ghostty")
hl.env("EDITOR", "nvim")
EOF

  write_user "$HYPR_DIR/monitors.lua" <<EOF
-- List outputs: hyprctl monitors all
hl.monitor({ output = "$MONITOR", mode = "$MONITOR_MODE", position = "0x0", scale = 1 })
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
EOF

  write_user "$HYPR_DIR/input.lua" <<EOF
hl.config({
  input = {
    kb_layout = "$KB_LAYOUT",
    kb_options = "$KB_OPTIONS",
    follow_mouse = 1,
    sensitivity = 0,
    accel_profile = "flat",
  },
})
EOF

  write_user "$HYPR_DIR/looknfeel.lua" <<'EOF'
-- Values from https://docs.noctalia.dev/noctalia/compositor-settings/hyprland/
hl.config({
  general = {
    gaps_in = 5,
    gaps_out = 10,
    border_size = 2,
    col = {
      active_border = "rgba(89b4faee)",
      inactive_border = "rgba(595959aa)",
    },
    layout = "dwindle",
    resize_on_border = true,
  },
  decoration = {
    rounding = 20,
    rounding_power = 2,
    shadow = { enabled = true, range = 4, render_power = 3, color = 0xee1a1a1a },
    blur = { enabled = true, size = 3, passes = 2, vibrancy = 0.1696 },
  },
  dwindle = { preserve_split = true },
  binds = { workspace_back_and_forth = true },
  misc = {
    disable_hyprland_logo = true,
    force_default_wallpaper = 0,
    middle_click_paste = false,
  },
})

-- Animations (Hyprland defaults)
hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })
hl.curve("easy", { type = "spring", mass = 1, stiffness = 238.1191, dampening = 24.21279333 })

hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows", enabled = true, speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.1, spring = "easy", style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.49, bezier = "linear", style = "popin 87%" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade", enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers", enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 4, bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.5, bezier = "linear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 7, bezier = "quick" })
EOF

  write_user "$HYPR_DIR/rules.lua" <<EOF
-- Noctalia layers: blur, and no Hyprland layer animation
hl.layer_rule({
  name = "noctalia",
  match = { namespace = "^noctalia-(bar-.+|notification|dock|panel|attached-panel|osd|window-switcher)$" },
  no_anim = true,
  ignore_alpha = 0.5,
  blur = true,
  blur_popups = true,
})

hl.window_rule({
  name = "noctalia-settings",
  match = { class = "dev.noctalia.Noctalia" },
  float = true,
  size = { 1080, 920 },
})

hl.window_rule({
  name = "suppress-maximize",
  match = { class = ".*" },
  suppress_event = "maximize",
})

hl.window_rule({
  name = "fix-xwayland-drags",
  match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
  no_focus = true,
})

-- Persistent workspaces keep Noctalia's indicator stable
for i = 1, 5 do
  hl.workspace_rule({ workspace = tostring(i), monitor = "$MONITOR", persistent = true })
end
EOF

  write_user "$HYPR_DIR/binds.lua" <<'EOF'
local mod = "SUPER"
local ipc = "noctalia msg "
local terminal = "ghostty"
local files = "nautilus --new-window"
local browser = "firefox"

-- Noctalia
hl.bind(mod .. " + SPACE", hl.dsp.exec_cmd(ipc .. "panel-toggle launcher"))
hl.bind(mod .. " + S", hl.dsp.exec_cmd(ipc .. "panel-toggle control-center"))
hl.bind(mod .. " + comma", hl.dsp.exec_cmd(ipc .. "settings-toggle"))
hl.bind(mod .. " + V", hl.dsp.exec_cmd(ipc .. "panel-toggle clipboard"))
hl.bind(mod .. " + ESCAPE", hl.dsp.exec_cmd(ipc .. "panel-toggle session"))
hl.bind(mod .. " + L", hl.dsp.exec_cmd(ipc .. "session lock"))
hl.bind("ALT + TAB", hl.dsp.exec_cmd(ipc .. "window-switcher"))
hl.bind("PRINT", hl.dsp.exec_cmd(ipc .. "screenshot-region"))
hl.bind("SHIFT + PRINT", hl.dsp.exec_cmd(ipc .. "screenshot-fullscreen"))

-- Media keys (Noctalia draws the OSD)
local held = { locked = true, repeating = true }
local once = { locked = true }
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(ipc .. "volume-up"), held)
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(ipc .. "volume-down"), held)
hl.bind("XF86AudioMute", hl.dsp.exec_cmd(ipc .. "volume-mute"), once)
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd(ipc .. "mic-mute"), once)
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd(ipc .. "media toggle"), once)
hl.bind("XF86AudioNext", hl.dsp.exec_cmd(ipc .. "media next"), once)
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd(ipc .. "media previous"), once)

-- Apps
hl.bind(mod .. " + RETURN", hl.dsp.exec_cmd(terminal))
hl.bind(mod .. " + E", hl.dsp.exec_cmd(files))
hl.bind(mod .. " + B", hl.dsp.exec_cmd(browser))

-- Windows
hl.bind(mod .. " + Q", hl.dsp.window.close())
hl.bind(mod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind(mod .. " + ALT + F", hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind(mod .. " + T", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + P", hl.dsp.window.pseudo())
hl.bind(mod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

local dirs = { left = "l", right = "r", up = "u", down = "d" }
for key, dir in pairs(dirs) do
  hl.bind(mod .. " + " .. key, hl.dsp.focus({ direction = dir }))
  hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.swap({ direction = dir }))
end

local grow = { repeating = true }
hl.bind(mod .. " + minus", hl.dsp.window.resize({ x = -100, y = 0, relative = true }), grow)
hl.bind(mod .. " + equal", hl.dsp.window.resize({ x = 100, y = 0, relative = true }), grow)
hl.bind(mod .. " + SHIFT + minus", hl.dsp.window.resize({ x = 0, y = -100, relative = true }), grow)
hl.bind(mod .. " + SHIFT + equal", hl.dsp.window.resize({ x = 0, y = 100, relative = true }), grow)

-- Workspaces
for i = 1, 10 do
  local key = i % 10
  hl.bind(mod .. " + " .. key, hl.dsp.focus({ workspace = i }))
  hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind(mod .. " + TAB", hl.dsp.focus({ workspace = "previous" }))
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mod .. " + grave", hl.dsp.workspace.toggle_special("scratch"))
hl.bind(mod .. " + SHIFT + grave", hl.dsp.window.move({ workspace = "special:scratch" }))
EOF

  write_user "$HYPR_DIR/autostart.lua" <<'EOF'
hl.on("hyprland.start", function()
  hl.exec_cmd("noctalia")
  hl.exec_cmd("udiskie --no-notify --no-tray")
  hl.exec_cmd("fcitx5 -d")
  hl.exec_cmd("dropbox")
end)
EOF
}

summary() {
  cat <<EOF

Done. Next:
  1. sudo reboot
  2. Noctalia greeter -> session "Hyprland"
  3. SUPER+SPACE launcher, SUPER+comma Noctalia settings, SUPER+RETURN ghostty
  4. Verify:
       cat /sys/module/nvidia_drm/parameters/modeset   # Y
       snapper list && limine-snapper-list
       docker run --rm hello-world                     # after re-login
  5. Wifi: NetworkManager now drives iwd; reconnect from the bar if needed
  6. sudo tailscale up ; Dropbox asks to link on first start
  7. Audio interface: pick the "Pro Audio" profile in pavucontrol for direct channels
EOF
}

main() {
  preflight
  setup_pacman
  install_base
  install_yay
  install_nvidia
  install_audio
  install_network
  install_hyprland
  install_noctalia
  install_dev
  install_apps
  install_gaming
  setup_snapshots
  setup_system
  setup_user
  write_noctalia_config
  write_hypr_config
  switch_network
  summary
}

main "$@"
