#!/usr/bin/env bash
# hypr/monitor-settings.lua against a fake hl that records what it asks for: the mode,
# position, scale and rotation saved for a monitor are applied whatever connector it is on.
# From upstream's test of the same file.
set -euo pipefail

module=$1
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

mkdir -p "$tmp/state/bar/monitors"
settings=$tmp/state/bar/monitors/settings

cat >"$tmp/fake.lua" <<'LUA'
applied, handlers, monitors = {}, {}, {}

hl = {
  get_monitors = function() return monitors end,
  monitor = function(spec) applied[#applied + 1] = spec end,
  on = function(name, handler) handlers[name] = handler end,
}

function plug(name, description, fields)
  fields.name = name
  fields.description = description
  monitors[#monitors + 1] = fields
end

function load_module()
  applied = {}
  dofile(os.getenv("MODULE"))
end

function check(condition, message)
  if not condition then error(message, 2) end
end
LUA

run_lua() {
  MODULE=$module XDG_STATE_HOME=$tmp/state lua -e "dofile('$tmp/fake.lua')" - <<<"$1"
}

# The display was set on DP-1 and comes back on DP-2 through a dock. It gets its
# settings there, and only the ones chosen: the laptop, with only a scale saved,
# keeps whatever mode and position monitors.lua gives it.
printf '%s\t%s\t%s\t%s\t%s\n' \
  "5120x2880@60" "0x0" "2" "" "Apple Computer Inc ProDisplayXDR 0x0A110A08" \
  "" "" "1.6" "" "LG Display 0x0804" >"$settings"
run_lua '
plug("DP-2", "Apple Computer Inc ProDisplayXDR 0x0A110A08", { width = 5120, height = 2880, refresh_rate = 60, scale = 2, x = 0, y = 0 })
plug("eDP-1", "LG Display 0x0804", { width = 2880, height = 1800, refresh_rate = 120, scale = 1.6, x = 2560, y = 0 })
load_module()
check(#applied == 2, "applies every saved monitor while the config loads, got " .. #applied)
check(applied[1].output == "DP-2" and applied[1].mode == "5120x2880@60" and applied[1].position == "0x0" and applied[1].scale == 2,
  "applies the settings on the new connector")
check(applied[2].output == "eDP-1" and applied[2].scale == 1.6 and applied[2].mode == nil and applied[2].position == nil,
  "applies only the settings chosen")
' || fail "saved settings follow the monitor and set only what was chosen"
echo "ok - saved settings follow the monitor and set only what was chosen"

# Plugged in again, a monitor already running as saved is left alone; one that
# is not gets its settings.
run_lua '
plug("DP-2", "Apple Computer Inc ProDisplayXDR 0x0A110A08", { width = 5120, height = 2880, refresh_rate = 60, scale = 2, x = 0, y = 0 })
plug("eDP-1", "LG Display 0x0804", { width = 2880, height = 1800, refresh_rate = 120, scale = 2, x = 2560, y = 0 })
load_module()
applied = {}
handlers["monitor.added"]({ name = "DP-2" })
check(#applied == 0, "leaves a monitor already running as saved alone")
handlers["monitor.added"]({ name = "eDP-1" })
check(#applied == 1 and applied[1].output == "eDP-1" and applied[1].scale == 1.6, "applies the settings of a returning monitor")
' || fail "an arriving monitor gets only what differs"
echo "ok - an arriving monitor gets only what differs"

# A saved rotation goes with the rest, and a monitor already turned that way is
# not turned again when it arrives.
printf '%s\t%s\t%s\t%s\t%s\n' "" "0x0" "1.5" "1" "Dell Inc. DELL U2723QE" >"$settings"
run_lua '
plug("DP-3", "Dell Inc. DELL U2723QE", { width = 3840, height = 2160, refresh_rate = 60, scale = 1.5, x = 0, y = 0, transform = 1 })
load_module()
check(#applied == 1 and applied[1].transform == 1, "applies the saved rotation")
applied = {}
handlers["monitor.added"]({ name = "DP-3" })
check(#applied == 0, "leaves a monitor already turned as saved alone")
' || fail "a saved rotation is applied"
echo "ok - a saved rotation is applied"

# A monitor that names no make or model is kept by its connector, as the script
# that saves names it.
printf '%s\t%s\t%s\t%s\t%s\n' "" "" "2" "" "HEADLESS-2" >"$settings"
run_lua '
plug("HEADLESS-2", "", { width = 1920, height = 1080, refresh_rate = 60, scale = 1, x = 0, y = 0 })
load_module()
check(#applied == 1 and applied[1].output == "HEADLESS-2" and applied[1].scale == 2, "applies settings saved by connector")
' || fail "a monitor without a description is kept by its connector"
echo "ok - a monitor without a description is kept by its connector"

# Until something is saved, monitors.lua alone decides.
rm -f "$settings"
run_lua '
plug("eDP-1", "LG Display 0x0804", { width = 2880, height = 1800, refresh_rate = 120, scale = 2, x = 0, y = 0 })
load_module()
check(#applied == 0, "applies nothing without saved settings")
' || fail "monitors.lua is left alone until something is saved"
echo "ok - monitors.lua is left alone until something is saved"
