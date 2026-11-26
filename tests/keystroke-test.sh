#!/usr/bin/env bash
# The launcher (config/quickshell/keystroke, config/keystroke), checked without a compositor.
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# Qt 6's runner by path: /usr/bin/qmltestrunner is Qt 5's when qt5-declarative is installed
runner=/usr/lib/qt6/bin/qmltestrunner

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

if [[ ! -x $runner ]] || ! command -v jq >/dev/null; then
  echo "ok - keystroke # SKIP qmltestrunner (qt6-declarative) or jq is not installed"
  exit 0
fi

# Upstream's unit tests for the parts kept here, and tests of the adapters this
# repo adds: keybinds from hyprctl, clipboard from cliphist, the spell checker.
log=$(mktemp)
trap 'rm -f "$log"' EXIT

if ! (cd "$root/tests/keystroke" && env -u QT_QPA_PLATFORMTHEME QT_QPA_PLATFORM=offscreen "$runner" -input . >"$log" 2>&1); then
  grep -A4 '^FAIL!' "$log" >&2 || cat "$log" >&2
  fail "keystroke's logic passes its unit tests"
fi
echo "ok - keystroke's logic passes its unit tests"

# A settings file that does not parse is ignored, which turns every bundled
# provider back on; a broken manifest drops its extension.
jq -e '.version == 1' "$root/config/keystroke/keystroke.json" >/dev/null || fail "the default settings parse"
for manifest in "$root"/config/keystroke/extensions/*/extension.json "$root"/config/quickshell/keystroke/extensions/*/extension.json; do
  jq -e '.apiVersion == 1 and (.name | length > 0)' "$manifest" >/dev/null || fail "$manifest is a usable manifest"
done
echo "ok - the default settings and extension manifests parse"

# Keybinds call the launcher IPC target by method name. Every name they use
# must be one shell.qml declares.
declared=$(sed -n '/target: "launcher"/,/^  }/p' "$root/config/quickshell/shell.qml" | grep -oE '^    function [A-Za-z]+' | awk '{print $2}' | sort -u)
used=$(grep -rhoE 'qs ipc call launcher [A-Za-z]+' "$root/config" "$root/bin" | awk '{print $NF}' | sort -u)
missing=$(comm -13 <(echo "$declared") <(echo "$used"))

[[ -z $missing ]] || fail "every launcher IPC method callers use is declared (missing: $missing)"
echo "ok - every launcher IPC method callers use is declared"
