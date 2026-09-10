#!/usr/bin/env bash
#
# Arch post-install: NVIDIA, Hyprland (Lua), HyDE-styled shell, matugen, dev tools.
# Run as your user after the first boot of an archinstall system.
# Idempotent: safe to re-run. A non-empty ~/.config/hypr prompts for removal.
# Not from the archinstall chroot: it reads /proc/cmdline and enables ufw.
#
#   git clone https://github.com/snoopz66/arch-postinstall && bash arch-postinstall/arch-postinstall.sh
#
# config/ -> ~/.config, bin/ -> ~/.local/bin, etc/ -> /etc. Existing user files are kept.
#
# Toggles:
#   INSTALL_GAMING=0   skip steam, gamemode, gamescope
#   SETUP_SNAPSHOTS=0  skip snapper + limine snapshot boot entries
#   SWITCH_TO_NM=0     keep systemd-networkd (wifi then needs iwctl, not nmtui)
#   NVIDIA_DOCKER=0    skip nvidia-container-toolkit
#   GIT_NAME, GIT_EMAIL  git identity; asked for at the start when unset and git has none yet

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
SRC_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

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
  [[ -d $SRC_DIR/config ]] || die "config/ missing, run from a clone of the repo"
  # /proc/cmdline, ufw and the AUR builds need the installed system, not the chroot
  [[ -d /run/systemd/system ]] || die "systemd is not running, boot the installed system first"

  sudo -v
  (while true; do sudo -n true; sleep 50; done) &
  SUDO_PID=$!
  trap 'kill $SUDO_PID 2>/dev/null' EXIT
}

confirm_hypr_reset() {
  if [[ ! -d $HYPR_DIR ]] || [[ -z $(ls -A "$HYPR_DIR") ]]; then
    return
  fi

  local answer
  read -rp "$HYPR_DIR is not empty. Remove it and write a fresh config? [y/N] " answer
  if [[ $answer != [yY]* ]]; then
    warn "keeping $HYPR_DIR, exiting"
    exit 1
  fi

  rm -rf "$HYPR_DIR"
}

# Asked up front so the long install does not stop halfway for it; an existing identity is kept
ask_git_identity() {
  GIT_NAME=${GIT_NAME:-$(git config --global user.name || true)}
  GIT_EMAIL=${GIT_EMAIL:-$(git config --global user.email || true)}

  while [[ -z $GIT_NAME ]]; do
    read -rp "Git name (for commits): " GIT_NAME
  done

  # something@domain.tld, no spaces
  while [[ ! $GIT_EMAIL =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]]; do
    [[ -z $GIT_EMAIL ]] || warn "not an email address: $GIT_EMAIL"
    read -rp "Git email: " GIT_EMAIL
  done
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
  pac hyprland kitty xdg-desktop-portal-hyprland xdg-desktop-portal-gtk qt5-wayland qt6-wayland \
    polkit gnome-keyring libsecret seahorse hyprpicker wl-clipboard \
    upower power-profiles-daemon accountsservice \
    xdg-user-dirs udiskie gvfs gvfs-mtp \
    noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-nerd-fonts-symbols \
    ttf-jetbrains-mono-nerd ttf-cascadia-code-nerd ttf-mononoki-nerd cantarell-fonts \
    tela-circle-icon-theme-dracula adwaita-icon-theme gnome-themes-extra

  svc_enable upower.service power-profiles-daemon.service accounts-daemon.service
  xdg-user-dirs-update
}

# https://wiki.archlinux.org/title/Greetd
install_greeter() {
  log "greetd, regreet"
  pac greetd greetd-regreet

  # regreet runs inside Hyprland, not cage: cage cannot set a mode and shows the EDID-preferred one
  # (3840x1080 on the C49RG9x). The session mirrors its layout, wallpaper and colors into
  # /var/lib/greeter with greeter-sync, so that directory belongs to the user and is world-readable.
  write_root /etc/greetd/config.toml <<'EOF'
[terminal]
vt = 1

[default_session]
command = "dbus-run-session start-hyprland -- -c /etc/greetd/hyprland.lua"
user = "greeter"
EOF

  sudo install -Dm644 "$SRC_DIR/etc/greetd/regreet.toml" /etc/greetd/regreet.toml
  sudo install -Dm644 "$SRC_DIR/etc/greetd/hyprland.lua" /etc/greetd/hyprland.lua
  sudo install -d -o greeter -g greeter /var/lib/regreet
  sudo install -d -o "$USER" -g "$USER" -m 755 /var/lib/greeter
  sudo rm -f /usr/share/backgrounds/greeter.png

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

install_shell() {
  log "shell components"
  pac waybar rofi hyprlock hypridle hyprpaper hyprpolkitagent swaync swayosd cliphist \
    grim slurp satty matugen imagemagick blueman
  aur wlogout bibata-cursor-theme-bin
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
  # keyboxd lock survives a hard reboot; a reused PID makes gpg wait, then fail
  gpgconf --kill all
  rm -f "$HOME/.gnupg/public-keys.d/pubring.db.lock"

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

  # gradle + GraalVM native builds: slow, RAM hungry, break now and then
  if ! aur limine-mkinitcpio-hook limine-snapper-sync; then
    warn "limine tools failed to build; rerun later for snapshot boot entries"
    return
  fi

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

  # archinstall leaves limine.conf beside the EFI app; limine-update manages /boot/limine.conf only
  local conf
  for conf in /boot/EFI/*/limine.conf /boot/limine/limine.conf; do
    if [[ -f $conf ]]; then
      sudo mv "$conf" /boot/limine.conf
      break
    fi
  done

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
  # `ufw enable` loads the rules now; only the unit reloads them at boot
  svc_enable ufw.service
}

# ---------- user ----------

# Home kept from an Omarchy install: park configs that need Omarchy.
stash_omarchy() {
  if grep -qs 'default/bash/rc' "$HOME/.bashrc"; then
    log "Omarchy bashrc found, moving to .bashrc.omarchy"
    mv "$HOME/.bashrc" "$HOME/.bashrc.omarchy"
    printf '%s\n' \
      '[[ $- != *i* ]] && return' \
      '[[ -f ~/.cargo/env ]] && . ~/.cargo/env' \
      '[[ -f ~/.local/bin/env ]] && . ~/.local/bin/env' >"$HOME/.bashrc"
  fi

  # units from packages that no longer exist
  rm -f "$HOME"/.config/systemd/user/omarchy-*
  find "$HOME/.config/systemd/user" -xtype l -delete 2>/dev/null || true
}

setup_bashrc() {
  # login shells only: greetd starts Hyprland through one, so the session and everything it spawns
  # (terminals, Claude Code's non-interactive shell) see ~/.local/bin; .bashrc exits early when not interactive
  local profile="$HOME/.bash_profile"
  if ! grep -q '# >>> postinstall' "$profile" 2>/dev/null; then
    cat >>"$profile" <<'EOF'

# >>> postinstall >>>
export PATH="$HOME/.local/bin:$PATH"
# <<< postinstall <<<
EOF
  fi

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

setup_git() {
  log "git identity and GitHub credentials"
  git config --global user.name "$GIT_NAME"
  git config --global user.email "$GIT_EMAIL"
  # credential helper via gh; `gh auth login` itself needs a browser, see the summary
  gh auth setup-git
}

setup_user() {
  log "user defaults"
  xdg-settings set default-web-browser firefox.desktop 2>/dev/null || true
  xdg-mime default org.gnome.Nautilus.desktop inode/directory
  xdg-mime default org.gnome.Loupe.desktop image/png image/jpeg image/gif image/webp image/svg+xml image/avif
  xdg-mime default mpv.desktop video/mp4 video/x-matroska video/webm audio/mpeg audio/flac
  xdg-mime default org.gnome.Papers.desktop application/pdf

  # HyDE defaults
  dbus-run-session -- sh -c "
    gsettings set org.gnome.desktop.interface icon-theme 'Tela-circle-dracula'
    gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Ice'
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
    gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
    gsettings set org.gnome.desktop.interface font-name 'Cantarell 10'
    gsettings set org.gnome.desktop.interface monospace-font-name 'CaskaydiaCove Nerd Font Mono 9'
  " || warn "gsettings skipped"

  setup_bashrc
}

# config/ -> ~/.config, bin/ -> ~/.local/bin; existing files win
install_config() {
  log "shell config"
  cp -r --update=none "$SRC_DIR/config/." "$HOME/.config/"
  install -d "$HOME/.local/bin"
  cp --update=none "$SRC_DIR"/bin/* "$HOME/.local/bin/"

  # first palette and rofi sidebar images; `wallpaper IMAGE` changes them later
  "$HOME/.local/bin/wallpaper" /usr/share/hypr/wall2.png
}

# Machine-specific Hyprland files; the rest ships in config/hypr
write_machine_config() {
  log "monitor and keyboard"

  write_user "$HYPR_DIR/monitors.lua" <<EOF
-- List outputs: hyprctl monitors all
MONITOR = "$MONITOR"
hl.monitor({ output = MONITOR, mode = "$MONITOR_MODE", position = "0x0", scale = 1 })
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
EOF

  # the login screen's copy until the first session runs greeter-sync
  install -Dm644 "$HYPR_DIR/monitors.lua" /var/lib/greeter/monitors.lua

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
}

summary() {
  cat <<EOF

Done. Next:
  1. sudo reboot
  2. regreet -> Hyprland
  3. SUPER+SPACE launcher, SUPER+ESCAPE power menu, SUPER+V clipboard, PRINT screenshot
  4. Verify:
       sudo cat /sys/module/nvidia_drm/parameters/modeset   # Y
       snapper list && limine-snapper-list
       docker run --rm hello-world                     # after re-login
  5. Wifi: NetworkManager now drives iwd; reconnect with nmtui if needed
  6. sudo tailscale up ; gh auth login ; Dropbox asks to link on first start
  7. Audio interface: pick the "Pro Audio" profile in pavucontrol for direct channels
  8. Wallpaper and colors: wallpaper ~/Pictures/some.jpg
EOF
}

main() {
  preflight
  confirm_hypr_reset
  ask_git_identity
  setup_pacman
  install_base
  install_yay
  install_nvidia
  install_audio
  install_network
  install_hyprland
  install_greeter
  install_shell
  install_dev
  install_apps
  install_gaming
  setup_system
  stash_omarchy
  setup_git
  setup_user
  install_config
  write_machine_config
  setup_snapshots
  switch_network
  summary
}

main "$@"
