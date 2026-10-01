# Agent instructions

This repo is the source of truth for this machine's desktop environment: Hyprland, waybar, rofi,
Quickshell, swaync, wlogout, hyprlock, regreet, matugen theming and the helper scripts around them.
The running system is a *copy* of the repo, not a symlink, so the two drift unless you keep them in
sync.

## The rule

**Any change to a desktop-environment component on the live system must also land in this repo, in
the same task.** A fix that only exists in `~/.config` is lost on the next install.

Likewise, a change made in the repo should be copied to the live system so the user sees it
(see "Deploying" below).

## Where things live

| Live system         | Repo                                        |
| ------------------- | ------------------------------------------- |
| `~/.config/<app>/…` | `config/<app>/…`                            |
| `~/.local/bin/<x>`  | `bin/<x>`                                   |
| `/etc/…`            | `etc/…`                                     |
| installed packages, enabled services, gsettings, anything else done by command | `arch-postinstall.sh` |

So beyond config files:

- Installed or removed a package the DE depends on → update the package lists in
  `arch-postinstall.sh`, always. A new component brings its packages into the list in the same
  task; a component that is replaced or dropped takes its packages out (and the other files it
  needed: config, cache images, matugen templates). Do not leave unused packages behind.
- Enabled a service, changed a gsetting, added a firewall rule, wrote a file outside the three
  mapped directories → add the equivalent step to `arch-postinstall.sh`. Keep it idempotent; the
  script is meant to be safe to re-run.
- Added a new file under `etc/` → also add the `install` line for it in the script (`etc/` is not
  copied wholesale, unlike `config/` and `bin/`).
- Changed behaviour a user would notice (new keybind, new script, new toggle) → update `README.md`.

## Do not copy these into the repo

Generated files — edit their source instead:

- matugen outputs: `~/.config/hypr/colors.lua`, `colors-hyprlock.conf`, `hyprpaper.conf`,
  `~/.config/waybar/theme.css`, `~/.config/rofi/theme.rasi`, `~/.config/swaync/style.css`,
  `/var/lib/greeter/regreet.css`, `~/.cache/wallpaper/*`. Their sources are
  `config/matugen/templates/*` (mapping in `config/matugen/config.toml`). After editing a template,
  re-run `wallpaper <current image>` to regenerate.
- Machine-specific Hyprland files: `~/.config/hypr/monitors.lua` and `input.lua`. They are written
  by `write_machine_config` in `arch-postinstall.sh` from `MONITOR`, `MONITOR_MODE`, `KB_LAYOUT`,
  `KB_OPTIONS`. Change the template there if the *shape* must change; never commit this machine's
  values.
- `/var/lib/greeter/*` — mirrored from the session by `bin/greeter-sync`.

Also keep secrets, tokens and host-specific paths out of the repo.

## Deploying

Prefer editing the repo file first, then copying it to the live location:

```
cp config/rofi/config.rasi ~/.config/rofi/config.rasi
```

Before overwriting a live file, check it has no local edits that the repo lacks:

```
git show HEAD:config/rofi/config.rasi | diff - ~/.config/rofi/config.rasi
```

If they differ, the live file has drifted — merge the difference into the repo rather than
clobbering it, and tell the user what you found.

If you edited the live file first, copy it back into the repo afterwards and check `git diff` shows
only the change you intended.

The install script copies with `--update=none` (existing user files win), so re-running it will
*not* deploy an updated config. Copy the file yourself.

## Verifying

Check the change in the running session where practical: `hyprctl reload` and `hyprctl configerrors`
for Hyprland, restart the component for waybar/swaync/Quickshell, open the menu and screenshot it
with `grim` for rofi. Say so plainly if something could not be verified.

## Finishing

- Leave changes uncommitted unless the user asks for a commit.
- In your summary, state both halves: what changed in the repo and whether the live system was
  updated.
