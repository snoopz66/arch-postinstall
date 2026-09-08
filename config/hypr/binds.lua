local mod = "SUPER"
local terminal = "ghostty"
local files = "nautilus --new-window"
local browser = "firefox"

-- Shell
hl.bind(mod .. " + SPACE", hl.dsp.exec_cmd("rofi -show drun"))
hl.bind("ALT + TAB", hl.dsp.exec_cmd("rofi -show window"))
hl.bind(mod .. " + V", hl.dsp.exec_cmd("cliphist list | rofi -dmenu -p Clipboard | cliphist decode | wl-copy"))
hl.bind(mod .. " + S", hl.dsp.exec_cmd("swaync-client -t"))
hl.bind(mod .. " + ESCAPE", hl.dsp.exec_cmd("~/.local/bin/logoutmenu"))
hl.bind(mod .. " + L", hl.dsp.exec_cmd("loginctl lock-session"))
hl.bind("PRINT", hl.dsp.exec_cmd("~/.local/bin/screenshot region"))
hl.bind("SHIFT + PRINT", hl.dsp.exec_cmd("~/.local/bin/screenshot screen"))

-- Media keys (swayosd draws the OSD)
local held = { locked = true, repeating = true }
local once = { locked = true }
local osd = "swayosd-client "
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(osd .. "--output-volume raise"), held)
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(osd .. "--output-volume lower"), held)
hl.bind("XF86AudioMute", hl.dsp.exec_cmd(osd .. "--output-volume mute-toggle"), once)
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd(osd .. "--input-volume mute-toggle"), once)
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), once)
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), once)
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), once)

-- Apps
hl.bind(mod .. " + RETURN", hl.dsp.exec_cmd(terminal))
hl.bind(mod .. " + E", hl.dsp.exec_cmd(files))
hl.bind(mod .. " + B", hl.dsp.exec_cmd(browser))

-- Windows
hl.bind(mod .. " + Q", hl.dsp.window.close())
hl.bind(mod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind(mod .. " + ALT + F", hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind(mod .. " + T", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + P", hl.dsp.window.pseudo())
hl.bind(mod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

local dirs = { left = "l", right = "r", up = "u", down = "d" }
for key, dir in pairs(dirs) do
  hl.bind(mod .. " + " .. key, hl.dsp.focus({ direction = dir }))
  hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.swap({ direction = dir }))
end

local grow = { repeating = true }
hl.bind(mod .. " + minus", hl.dsp.window.resize({ x = -100, y = 0, relative = true }), grow)
hl.bind(mod .. " + equal", hl.dsp.window.resize({ x = 100, y = 0, relative = true }), grow)
hl.bind(mod .. " + SHIFT + minus", hl.dsp.window.resize({ x = 0, y = -100, relative = true }), grow)
hl.bind(mod .. " + SHIFT + equal", hl.dsp.window.resize({ x = 0, y = 100, relative = true }), grow)

-- Workspaces
for i = 1, 10 do
  local key = i % 10
  hl.bind(mod .. " + " .. key, hl.dsp.focus({ workspace = i }))
  hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind(mod .. " + TAB", hl.dsp.focus({ workspace = "previous" }))
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mod .. " + grave", hl.dsp.workspace.toggle_special("scratch"))
hl.bind(mod .. " + SHIFT + grave", hl.dsp.window.move({ workspace = "special:scratch" }))
