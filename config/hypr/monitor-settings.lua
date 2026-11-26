-- Each monitor's mode, position, scale and rotation as chosen in the bar's display
-- panel, kept by the physical monitor rather than the port it's plugged into.
-- From Omarchy's default/hypr/monitor-settings.lua (see quickshell/LICENSE.omarchy).
--
-- They live in a state file, one line per monitor ever set: its mode, position,
-- scale and transform, any of them empty when never chosen, then its identity
-- (its description: make, model and serial). A dock renames its connectors
-- between plugs, so a rule naming DP-1 would hand one monitor's mode to
-- whatever turns up on that port next. bar-hyprland-monitor-persist writes the
-- file; nothing here writes it.
--
-- Applied while the config loads, after monitors.lua, so a choice made in the
-- panel wins over the rule written there and a reload settles on it in one go.
-- Applied again when a monitor arrives, skipping one that already runs as
-- saved, so plugging it back in doesn't reconfigure it for nothing.

local STATE_HOME = os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")
local STATE_FILE = STATE_HOME .. "/bar/monitors/settings"

local function load()
  local settings = {}
  local file = io.open(STATE_FILE, "r")
  if not file then
    return settings
  end

  for line in file:lines() do
    local mode, position, scale, transform, identity =
      line:match("^([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]+)$")
    if identity then
      settings[identity] = {
        mode = mode ~= "" and mode or nil,
        position = position ~= "" and position or nil,
        scale = tonumber(scale),
        transform = tonumber(transform),
      }
    end
  end

  file:close()
  return settings
end

-- As bar-hyprland-monitor-persist names it: the description, else the connector.
local function identity_of(monitor)
  local description = monitor.description or ""
  if description == "" then
    return monitor.name
  end
  return (description:gsub("[\t\n]", " "))
end

-- Whether a monitor already runs at its saved mode, position, scale and rotation.
local function matches(monitor, saved)
  if saved.scale and math.abs((monitor.scale or 0) - saved.scale) > 0.001 then
    return false
  end

  if saved.position then
    local x, y = saved.position:match("^(-?%d+)x(-?%d+)$")
    if tonumber(x) ~= monitor.x or tonumber(y) ~= monitor.y then
      return false
    end
  end

  if saved.mode then
    local width, height, rate = saved.mode:match("^(%d+)x(%d+)@?([%d.]*)$")
    if tonumber(width) ~= monitor.width or tonumber(height) ~= monitor.height then
      return false
    end
    if rate ~= "" and math.abs((monitor.refresh_rate or 0) - tonumber(rate)) > 0.5 then
      return false
    end
  end

  if saved.transform and saved.transform ~= (monitor.transform or 0) then
    return false
  end

  return true
end

-- Only what was chosen: hl.monitor updates the connector's existing rule, so
-- anything never set in the panel keeps what monitors.lua gives it.
local function rule(name, saved)
  return {
    output = name,
    mode = saved.mode,
    position = saved.position,
    scale = saved.scale,
    transform = saved.transform,
  }
end

-- Apply the saved settings of the connected monitors, or just of `only`. While
-- the config loads every one is applied, since the rules just read from
-- monitors.lua would otherwise win; afterwards one already running as saved is
-- left alone.
local function apply(loading, only)
  local settings = load()
  if next(settings) == nil then
    return
  end

  for _, monitor in ipairs(hl.get_monitors()) do
    local saved = settings[identity_of(monitor)]
    if
      not monitor.is_mirror
      and saved
      and (not only or monitor.name == only)
      and (loading or not matches(monitor, saved))
    then
      hl.monitor(rule(monitor.name, saved))
    end
  end
end

apply(true)

hl.on("hyprland.start", function()
  apply(false)
end)

hl.on("monitor.added", function(monitor)
  apply(false, monitor and monitor.name)
end)
