#!/usr/bin/env bash
# bar-agent-usage-update against stub collectors. From Omarchy's
# test/shell.d/agent-usage-update-test.sh.
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
home=$(mktemp -d)
bin=$(mktemp -d)
trap 'rm -rf "$home" "$bin"' EXIT

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

if ! command -v jq >/dev/null; then
  echo "ok - the updater # SKIP jq is not installed"
  exit 0
fi

# The updater runs the collectors beside it.
cp "$root/bin/bar-agent-usage-update" "$bin/"
printf '%s\n' '#!/bin/bash' "echo '{\"schemaVersion\":1,\"id\":\"good\",\"name\":\"Good Agent\",\"totalPrompts\":3}'" >"$bin/bar-agent-usage-good"
printf '%s\n' '#!/bin/bash' 'echo "this is not json"' >"$bin/bar-agent-usage-noisy"
printf '%s\n' '#!/bin/bash' "echo '{\"id\":\"skipped\"}'" >"$bin/bar-agent-usage-skipped"
chmod +x "$bin"/bar-agent-usage-*

usage_dir=$home/.local/state/bar/agents/usage
update() {
  HOME=$home XDG_STATE_HOME="" "$bin/bar-agent-usage-update" "$@"
}

if update --except skipped 2>/dev/null; then
  fail "update reports a failing collector"
fi
echo "ok - update reports a failing collector"

[[ $(jq -r '.name' "$usage_dir/good.json") == "Good Agent" ]] || fail "update writes each collector's record to the usage directory"
echo "ok - update writes each collector's record to the usage directory"

[[ ! -e $usage_dir/noisy.json ]] || fail "update refuses records that are not valid JSON"
echo "ok - update refuses records that are not valid JSON"

[[ ! -e $usage_dir/skipped.json ]] || fail "update skips agents excluded with --except"
echo "ok - update skips agents excluded with --except"

[[ ! -e $usage_dir/update.json ]] || fail "update does not treat itself as a collector"
echo "ok - update does not treat itself as a collector"

update skipped 2>/dev/null || fail "update succeeds when the requested collectors all pass"
[[ -e $usage_dir/skipped.json && ! -e $usage_dir/noisy.json ]] || fail "update with agent arguments only runs the named collectors"
echo "ok - update with agent arguments only runs the named collectors"

rm -rf "$usage_dir"
if output=$(update --except '' 2>&1); then
  fail "update refuses an empty --except"
fi
[[ $output == "--except needs an agent" && ! -e $usage_dir/good.json ]] || fail "update refuses an empty --except before collecting anything"
echo "ok - update refuses an empty --except before collecting anything"
