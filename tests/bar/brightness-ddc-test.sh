#!/usr/bin/env bash
# bar-brightness-display-ddc against a fake ddcutil that answers for one monitor on
# bus 7 and records its calls. From the DDC part of upstream's brightness test.
set -euo pipefail

helper=$1
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fail() {
  [[ -z ${2:-} ]] || printf '%s\n' "$2" >&2
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

pass() {
  printf 'ok - %s\n' "$1"
}

call_log=$tmp/calls
runtime_dir=$tmp/runtime
bus_cache=$runtime_dir/bar-brightness-display-ddc/DP-1.bus
mkdir -p "$tmp/bin" "$runtime_dir"

cat >"$tmp/bin/ddcutil" <<'SH'
#!/bin/bash
printf 'ddcutil %s\n' "$*" >>"$CALL_LOG"

if [[ $* == *" detect --brief"* ]]; then
  cat <<EOF
Display 1
   I2C bus:             /dev/i2c-7
   DRM connector:       card1-DP-1
EOF
elif [[ $* == *" getvcp 10 "* ]]; then
  [[ ${DDC_READ_FAIL:-0} == "1" ]] && exit 1
  printf 'VCP 10 C %s %s\n' "${DDC_CURRENT:-40}" "${DDC_MAXIMUM:-80}"
fi
SH
chmod +x "$tmp/bin/ddcutil"

run_brightness() {
  CALL_LOG=$call_log XDG_RUNTIME_DIR=$runtime_dir PATH=$tmp/bin:$PATH "$helper" "$@"
}

brightness=$(run_brightness DP-1)
[[ $brightness == "50" ]] || fail "brightness is converted to a percentage" "actual: $brightness"
pass "brightness is converted to a percentage"

(( $(grep -c '^ddcutil --skip-ddc-checks detect --brief$' "$call_log") == 1 )) || fail "the bus is detected once"
run_brightness DP-1 >/dev/null
(( $(grep -c '^ddcutil --skip-ddc-checks detect --brief$' "$call_log") == 1 )) || fail "the bus mapping is cached"
pass "the bus mapping is cached"

run_brightness DP-1 25% >/dev/null
grep -F 'ddcutil --bus 7 --skip-ddc-checks --noverify setvcp 10 20' "$call_log" >/dev/null ||
  fail "a percentage is converted to the monitor's range"
pass "a percentage is converted to the monitor's range"

get_count=$(grep -c ' getvcp 10 ' "$call_log")
run_brightness DP-1 30% >/dev/null
(( $(grep -c ' getvcp 10 ' "$call_log") == get_count )) || fail "an absolute brightness reuses the cached range"
grep -F 'ddcutil --bus 7 --skip-ddc-checks --noverify setvcp 10 24' "$call_log" >/dev/null ||
  fail "an absolute brightness skips write verification"
pass "an absolute brightness reuses the cached range"

if run_brightness HDMI-A-1 >/dev/null 2>&1; then
  fail "a monitor ddcutil does not list has no brightness"
fi
pass "a monitor ddcutil does not list has no brightness"

rm -f "$bus_cache"
detect_count=$(grep -c ' detect --brief' "$call_log")
get_count=$(grep -c ' getvcp 10 ' "$call_log")
if DDC_READ_FAIL=1 run_brightness DP-1 >/dev/null 2>&1; then
  fail "an unreadable brightness is reported"
fi
if DDC_READ_FAIL=1 run_brightness DP-1 >/dev/null 2>&1; then
  fail "a cached unreadable brightness is reported"
fi
(( $(grep -c ' detect --brief' "$call_log") == detect_count + 1 )) || fail "an unreadable brightness is cached for a while"
(( $(grep -c ' getvcp 10 ' "$call_log") == get_count + 1 )) || fail "a cached unreadable brightness is not read again"
pass "an unreadable brightness is cached for a while"

printf 'unavailable 0\n' >"$bus_cache"
brightness=$(run_brightness DP-1)
[[ $brightness == "50" ]] || fail "an expired unreadable brightness is retried" "actual: $brightness"
pass "an expired unreadable brightness is retried"

printf '7 80 0\n' >"$bus_cache"
get_count=$(grep -c ' getvcp 10 ' "$call_log")
DDC_MAXIMUM=100 run_brightness DP-1 50% >/dev/null
(( $(grep -c ' getvcp 10 ' "$call_log") == get_count + 1 )) || fail "an expired range is read again"
grep -F 'ddcutil --bus 7 --skip-ddc-checks --noverify setvcp 10 50' "$call_log" >/dev/null ||
  fail "an expired range uses the maximum read again"
pass "an expired range is read again"

rm -f "$bus_cache"
DDC_CURRENT=4 DDC_MAXIMUM=100 run_brightness DP-1 +5% >/dev/null
grep -F 'ddcutil --bus 7 --skip-ddc-checks --noverify setvcp 10 5' "$call_log" >/dev/null ||
  fail "a low brightness steps by one percent"
pass "a low brightness steps by one percent"
