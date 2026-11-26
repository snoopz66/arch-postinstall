#!/usr/bin/env bash
# The bar (config/quickshell/{bar,panels,services}, BarHost, bin/bar-*, bin/screenrecord,
# config/hypr/monitor-settings.lua), checked without a compositor or a network.
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
shell=$root/config/quickshell
# Qt 6's runner by path: /usr/bin/qmltestrunner is Qt 5's when qt5-declarative is installed
runner=/usr/lib/qt6/bin/qmltestrunner

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

log=$(mktemp)
trap 'rm -f "$log"' EXIT

# The layout file: names in it against the ids the bar's code uses, and what a widget's
# settings change writes back.
if [[ -x $runner ]]; then
  if ! (cd "$root/tests/bar" && env -u QT_QPA_PLATFORMTHEME QT_QPA_PLATFORM=offscreen "$runner" -input . >"$log" 2>&1); then
    grep -A4 '^FAIL!' "$log" >&2 || cat "$log" >&2
    fail "the host reads and writes the layout file"
  fi
  echo "ok - the host reads and writes the layout file"
else
  echo "ok - the host reads and writes the layout file # SKIP qmltestrunner (qt6-declarative) is not installed"
fi

# Upstream's tests of the models behind the bar and each panel.
if command -v node >/dev/null; then
  for name in bar tray keyboard-layout audio bluetooth network tailscale nightlight \
    agents-notes agents-limits agents-order agents-drag monitor; do
    node "$root/tests/bar/$name.cjs" >"$log" 2>&1 || { cat "$log" >&2; fail "the $name model passes upstream's tests"; }
  done
  echo "ok - the models pass upstream's tests"

  node "$root/tests/bar/looks.cjs" >"$log" 2>&1 || { cat "$log" >&2; fail "the bar's looks cycle, and the default layout asks for one of them"; }
  echo "ok - the bar's looks cycle, and the default layout asks for one of them"

  node "$root/tests/bar/agents-off.cjs" >"$log" 2>&1 || { cat "$log" >&2; fail "the agents panel's Omarchy-only parts are off"; }
  echo "ok - the agents panel's Omarchy-only parts are off"

  node "$root/tests/bar/monitor-off.cjs" >"$log" 2>&1 || { cat "$log" >&2; fail "the display panel's Mirror is off"; }
  echo "ok - the display panel's Mirror is off"

  node "$root/tests/bar/dropbox.cjs" >"$log" 2>&1 || { cat "$log" >&2; fail "the Dropbox panel reads a status, and runs what is here"; }
  echo "ok - the Dropbox panel reads a status, and runs what is here"
else
  echo "ok - the models pass upstream's tests # SKIP node is not installed"
fi

# The default layout must parse, and name only widgets the host can mount: the bar
# draws nothing for a name it does not know.
layout=$root/config/bar/bar.json
if command -v jq >/dev/null; then
  known=$(sed -n '/readonly property var widgets/,/^  })/p' "$shell/BarHost.qml" | grep -oE '"[a-z-]+":' | tr -d '":' | sort -u)
  named=$(jq -r '.layout[][] | .id' "$layout" | sort -u)
  unknown=$(comm -13 <(echo "$known") <(echo "$named"))

  [[ -n $known ]] || fail "BarHost.qml lists its widgets"
  [[ -z $unknown ]] || fail "the default layout names only widgets the host mounts (unknown: $unknown)"
  echo "ok - the default layout names only widgets the host mounts"
else
  echo "ok - the default layout names only widgets the host mounts # SKIP jq is not installed"
fi

# Every script the bar's code runs is one this repo installs, and parses.
called=$(grep -rhoE --include='*.qml' --include='*.js' '"(bar-[a-z-]+|screenrecord)[" ]' "$shell/bar" "$shell/panels" "$shell/services" | tr -d '" ' | sort -u)
[[ -n $called ]] || fail "the bar's code names the scripts it runs"
for script in $called; do
  [[ -x $root/bin/$script ]] || fail "bin/$script, which the bar runs, exists"
done
for script in "$root"/bin/bar-* "$root/bin/screenrecord"; do
  if head -1 "$script" | grep -q python; then
    python3 -c 'import ast, sys; ast.parse(open(sys.argv[1]).read())' "$script" || fail "$script parses"
  else
    bash -n "$script" || fail "$script parses"
  fi
done
echo "ok - every script the bar runs is installed and parses"

# No Omarchy command is left to call: none of them exist here. The agents panel keeps
# its own in the parts switched off, which agents-off.cjs holds off.
if left=$(grep -rnE --exclude-dir=agents '"omarchy-[a-z-]+|\bomarchy-[a-z-]+ ' "$shell/bar" "$shell/panels" "$shell/services" "$root"/bin/bar-* | grep -vE '^\S+:[0-9]+:\s*(//|#)'); then
  printf '%s\n' "$left" >&2
  fail "no Omarchy command is called"
fi
echo "ok - no Omarchy command is called"

bash "$root/tests/bar/dns-test.sh" "$root/bin/bar-dns" >"$log" 2>&1 || { cat "$log" >&2; fail "bar-dns reads and sets the connection's DNS"; }
echo "ok - bar-dns reads and sets the connection's DNS"

bash "$root/tests/bar/screenrecord-test.sh" "$root/bin/screenrecord" >"$log" 2>&1 || { cat "$log" >&2; fail "screenrecord starts, stops and reports"; }
echo "ok - screenrecord starts, stops and reports"

bash "$root/tests/bar/agent-usage-update-test.sh" >"$log" 2>&1 || { cat "$log" >&2; fail "the agent usage updater runs its collectors"; }
echo "ok - the agent usage updater runs its collectors"

if command -v python3 >/dev/null; then
  bash "$root/tests/bar/agent-usage-test.sh" >"$log" 2>&1 || { cat "$log" >&2; fail "the agent usage collectors print their records"; }
  echo "ok - the agent usage collectors print their records"
else
  echo "ok - the agent usage collectors print their records # SKIP python3 is not installed"
fi

# The display panel's scripts, against a fake hyprctl, ddcutil, gsettings and pkill.
if command -v jq >/dev/null; then
  bash "$root/tests/bar/monitor-state-test.sh" "$root/bin/bar-monitor-state" >"$log" 2>&1 || { cat "$log" >&2; fail "bar-monitor-state answers the display panel line by line"; }
  echo "ok - bar-monitor-state answers the display panel line by line"

  bash "$root/tests/bar/monitor-scripts-test.sh" "$root/bin" >"$log" 2>&1 || { cat "$log" >&2; fail "scale, resolution, rotation and layout are applied and saved"; }
  echo "ok - scale, resolution, rotation and layout are applied and saved"
else
  echo "ok - the display panel's scripts apply and save # SKIP jq is not installed"
fi

bash "$root/tests/bar/brightness-ddc-test.sh" "$root/bin/bar-brightness-display-ddc" >"$log" 2>&1 || { cat "$log" >&2; fail "bar-brightness-display-ddc reads and sets a monitor's brightness"; }
echo "ok - bar-brightness-display-ddc reads and sets a monitor's brightness"

bash "$root/tests/bar/display-text-size-test.sh" "$root/bin/bar-display-text-size" >"$log" 2>&1 || { cat "$log" >&2; fail "bar-display-text-size sets the shell, GTK and Ghostty together"; }
echo "ok - bar-display-text-size sets the shell, GTK and Ghostty together"

if command -v lua >/dev/null; then
  bash "$root/tests/bar/monitor-settings-test.sh" "$root/config/hypr/monitor-settings.lua" >"$log" 2>&1 || { cat "$log" >&2; fail "saved display settings are applied to their monitor"; }
  echo "ok - saved display settings are applied to their monitor"
else
  echo "ok - saved display settings are applied to their monitor # SKIP lua is not installed"
fi

if command -v python3 >/dev/null && command -v jq >/dev/null; then
  bash "$root/tests/bar/dropbox-status-test.sh" "$shell/panels/dropbox/status.py" >"$log" 2>&1 || { cat "$log" >&2; fail "the Dropbox status helper reports the account"; }
  echo "ok - the Dropbox status helper reports the account"
else
  echo "ok - the Dropbox status helper reports the account # SKIP python3 or jq is not installed"
fi
