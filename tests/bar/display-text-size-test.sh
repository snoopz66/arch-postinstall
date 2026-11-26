#!/usr/bin/env bash
# bar-display-text-size in a scratch home, with a fake gsettings and pkill: one size
# sets the shell's base-size, GTK's text scaling and Ghostty's font size together.
set -euo pipefail

helper=$1
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fail() {
  [[ -z ${2:-} ]] || printf '%s\n' "$2" >&2
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

home=$tmp/home
shell_toml=$home/.config/quickshell/shell.toml
ghostty=$home/.config/ghostty/config
calls=$tmp/calls
mkdir -p "$tmp/bin" "${shell_toml%/*}" "${ghostty%/*}"

cat >"$tmp/bin/gsettings" <<'STUB'
#!/usr/bin/env bash
printf 'gsettings %s\n' "$*" >>"$CALLS"
[[ $* == "get org.gnome.desktop.interface font-name" ]] && echo "'Cantarell 10'"
exit 0
STUB
# the real one would signal the terminals of the session running the test
cat >"$tmp/bin/pkill" <<'STUB'
#!/usr/bin/env bash
printf 'pkill %s\n' "$*" >>"$CALLS"
STUB
chmod +x "$tmp/bin/gsettings" "$tmp/bin/pkill"

text_size() {
  HOME=$home CALLS=$calls PATH=$tmp/bin:$PATH "$helper" "$@"
}

base_size() {
  sed -n '/^\[font\]/,/^\[/s/^base-size = //p' "$shell_toml"
}

fresh() {
  : >"$calls"
  printf '%s\n' '[notifications]' 'border = "accent"' '' '[font]' 'base-size = 14' '' '[bar]' 'size-horizontal = 31' >"$shell_toml"
  printf '%s\n' 'font-family = Mono' 'font-size = 10' 'theme = dark' >"$ghostty"
}

fresh
text_size 16
[[ $(base_size) == "16" ]] || fail "a size sets the shell's base-size" "$(<"$shell_toml")"
[[ $(grep -c . "$shell_toml") == 6 ]] && grep -qx 'border = "accent"' "$shell_toml" && grep -qx 'size-horizontal = 31' "$shell_toml" ||
  fail "the rest of shell.toml is left as it was" "$(<"$shell_toml")"
grep -qxF 'gsettings set org.gnome.desktop.interface text-scaling-factor 1.1000' "$calls" ||
  fail "a size scales GTK text to a whole point size" "$(<"$calls")"
grep -qx 'font-size = 11' "$ghostty" && grep -qx 'font-family = Mono' "$ghostty" ||
  fail "a size sets Ghostty's font size and nothing else" "$(<"$ghostty")"
grep -qxF 'pkill -SIGUSR2 ghostty' "$calls" || fail "running Ghostty windows are told to reload"
echo "ok - a size sets the shell, GTK and Ghostty together"

fresh
text_size 20
text_size 14
[[ $(base_size) == "14" ]] || fail "the shipped size is 14px"
tail -n 3 "$calls" | grep -qxF 'gsettings set org.gnome.desktop.interface text-scaling-factor 1.0000' ||
  fail "at 14px GTK text is unscaled" "$(<"$calls")"
grep -qx 'font-size = 10' "$ghostty" || fail "at 14px Ghostty is at 10pt" "$(<"$ghostty")"
echo "ok - 14px is this setup's unscaled size"

fresh
text_size 9
text_size reset
[[ $(base_size) == "14" ]] || fail "reset returns the shell to 14px" "$(<"$shell_toml")"
grep -qxF 'gsettings reset org.gnome.desktop.interface text-scaling-factor' "$calls" || fail "reset unscales GTK text"
grep -qx 'font-size = 10' "$ghostty" || fail "reset returns Ghostty to 10pt" "$(<"$ghostty")"
echo "ok - reset returns all three to their defaults"

fresh
for size in 8 21 big 14.5; do
  if text_size "$size" >/dev/null 2>&1; then
    fail "a size outside 9 to 20 is refused: $size"
  fi
done
[[ $(base_size) == "14" && ! -s $calls ]] || fail "a refused size changes nothing"
echo "ok - a size outside 9 to 20 is refused"

# A shell.toml without the section gets one, and a symlinked file stays a link.
fresh
mkdir "$tmp/dots"
printf '%s\n' '[bar]' 'size-horizontal = 31' >"$tmp/dots/shell.toml"
ln -sf "$tmp/dots/shell.toml" "$shell_toml"
text_size 12
[[ -L $shell_toml && $(base_size) == "12" ]] || fail "a symlinked shell.toml is written through, and gains [font]" "$(<"$tmp/dots/shell.toml")"
echo "ok - a missing [font] section is added, through a symlink"
