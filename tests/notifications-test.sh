#!/usr/bin/env bash
# Notifications (config/quickshell/notifications), checked without a compositor.
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
service=$root/config/quickshell/notifications/Service.qml

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

if ! command -v node >/dev/null; then
  echo "ok - notifications # SKIP node is not installed"
  exit 0
fi

# The JS modules, plus the service's admission, close and replay functions run
# against a fake ListModel and fake senders.
node "$root/tests/notifications/logic.cjs" >/dev/null || fail "notification logic holds its policies"
echo "ok - notification logic holds its policies"

# The startup step that makes the state directory, run as the service runs it,
# on a scratch directory. It must keep the current files, replace a symlinked
# one rather than write through it, and leave everything private.
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

prepare=$(node -e '
  const source = require("node:fs").readFileSync(process.argv[1], "utf8")
  const m = source.match(/id: storePrepare\s+command: \["bash", "-c",([^]*?),\s*"qs-notifications-state"/)
  process.stdout.write(require("node:vm").runInNewContext(m[1]))
' "$service")
state=$tmp/state
mkdir -p "$state" "$tmp/outside"
touch "$tmp/outside/keep.json"
echo '[{"key":"n2"}]' >"$state/history.json"
chmod 644 "$state/history.json"
ln -s "$tmp/outside/keep.json" "$state/quiet.json"

bash -c "$prepare" qs-notifications-state "$state" || fail "the state directory is prepared"

[[ $(cd "$state" && find . | sort | tr '\n' ' ') == ". ./history.json ./live.json ./quiet.json " ]] ||
  fail "the state files are made"
[[ -f $tmp/outside/keep.json && $(cat "$state/history.json") == '[{"key":"n2"}]' && ! -L $state/quiet.json && ! -s $state/quiet.json ]] ||
  fail "current state is kept and a symlinked state file replaced"
[[ $(stat -c %a "$state" "$state/live.json" "$state/history.json" "$state/quiet.json" | tr '\n' ' ') == "700 600 600 600 " ]] ||
  fail "the state directory and its files are private"
echo "ok - the state directory is prepared"

# Keybinds, the bar and scripts call the notifications IPC target by method
# name. Every name they use must be one the service declares.
declared=$(sed -n '/target: "notifications"/,/^  }/p' "$service" | grep -oE '^    function [A-Za-z]+' | awk '{print $2}' | sort -u)
used=$(grep -rhoE 'qs ipc call notifications [A-Za-z]+' "$root/config" "$root/bin" | awk '{print $NF}' | sort -u)
missing=$(comm -13 <(echo "$declared") <(echo "$used"))

[[ -z $missing ]] || fail "every notifications IPC method callers use is declared (missing: $missing)"
echo "ok - every notifications IPC method callers use is declared"
