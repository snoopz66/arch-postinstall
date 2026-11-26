#!/usr/bin/env bash
# The bar (config/quickshell/{bar,panels,services}, BarHost, bin/bar-*, bin/screenrecord),
# checked without a compositor.
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
  for name in bar tray keyboard-layout audio bluetooth network tailscale nightlight; do
    node "$root/tests/bar/$name.cjs" >"$log" 2>&1 || { cat "$log" >&2; fail "the $name model passes upstream's tests"; }
  done
  echo "ok - the models pass upstream's tests"
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
called=$(grep -rhoE '"(bar-[a-z-]+|screenrecord)[" ]' "$shell/bar" "$shell/panels" "$shell/services" | tr -d '" ' | sort -u)
[[ -n $called ]] || fail "the bar's code names the scripts it runs"
for script in $called; do
  [[ -x $root/bin/$script ]] || fail "bin/$script, which the bar runs, exists"
done
for script in "$root"/bin/bar-* "$root/bin/screenrecord"; do
  bash -n "$script" || fail "$script parses"
done
echo "ok - every script the bar runs is installed and parses"

# No Omarchy command is left to call: none of them exist here.
if left=$(grep -rnE '"omarchy-[a-z-]+|\bomarchy-[a-z-]+ ' "$shell/bar" "$shell/panels" "$shell/services" "$root"/bin/bar-* | grep -vE '^\S+:[0-9]+:\s*(//|#)'); then
  printf '%s\n' "$left" >&2
  fail "no Omarchy command is called"
fi
echo "ok - no Omarchy command is called"

bash "$root/tests/bar/dns-test.sh" "$root/bin/bar-dns" >"$log" 2>&1 || { cat "$log" >&2; fail "bar-dns reads and sets the connection's DNS"; }
echo "ok - bar-dns reads and sets the connection's DNS"

bash "$root/tests/bar/screenrecord-test.sh" "$root/bin/screenrecord" >"$log" 2>&1 || { cat "$log" >&2; fail "screenrecord starts, stops and reports"; }
echo "ok - screenrecord starts, stops and reports"
