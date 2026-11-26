#!/usr/bin/env bash
# The list menus (config/quickshell/Menu.qml), checked without a compositor.
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

# Menu.qml ignores a list it does not know, so a keybind left pointing at a
# removed list would do nothing and say nothing.
declared=$(sed -n '/readonly property var lists/,/^  })/p' "$root/config/quickshell/Menu.qml" | grep -oE '^    [a-z]+:' | tr -d ' :' | sort -u)
used=$(grep -rhoE 'qs ipc call menu (toggle|open) [a-z]+' "$root/config" "$root/bin" | awk '{print $NF}' | sort -u)
missing=$(comm -13 <(echo "$declared") <(echo "$used"))

[[ -n $declared ]] || fail "Menu.qml declares its lists"
[[ -z $missing ]] || fail "every menu list a caller opens is declared (missing: $missing)"
echo "ok - every menu list a caller opens is declared"
