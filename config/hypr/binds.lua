local mod = "SUPER"
local terminal = "ghostty"
local files = "nautilus --new-window"
local browser = "firefox"

-- bind(keys, dispatcher, description, opts): the description feeds ~/.local/bin/keybinds
local function bind(keys, dispatcher, desc, opts)
  local o = {}
  for k, v in pairs(opts or {}) do
    o[k] = v
  end
  o.desc = desc
  hl.bind(keys, dispatcher, o)
end

-- Shell
bind(mod .. " + SPACE", hl.dsp.exec_cmd("qs ipc call launcher toggle"), "App launcher")
bind(mod .. " + C", hl.dsp.exec_cmd("rofi -show calc"), "Calculator (Return copies the result)")
bind(mod .. " + ALT + SPACE", hl.dsp.exec_cmd("~/.local/bin/quickmenu"), "Quick menu: wallpaper, screenshot, keybinds")
bind("ALT + TAB", hl.dsp.exec_cmd("rofi -show window"), "Window switcher")
bind(mod .. " + V", hl.dsp.exec_cmd("cliphist list | rofi -dmenu -p Clipboard | cliphist decode | wl-copy"), "Clipboard history")
bind(mod .. " + S", hl.dsp.exec_cmd("swaync-client -t"), "Notification panel")
bind(mod .. " + ESCAPE", hl.dsp.exec_cmd("~/.local/bin/logoutmenu"), "Power menu")
bind(mod .. " + L", hl.dsp.exec_cmd("loginctl lock-session"), "Lock screen")
bind("PRINT", hl.dsp.exec_cmd("~/.local/bin/screenshot region"), "Screenshot a region")
bind("SHIFT + PRINT", hl.dsp.exec_cmd("~/.local/bin/screenshot screen"), "Screenshot the screen")

-- Media keys (swayosd draws the OSD)
local held = { locked = true, repeating = true }
local once = { locked = true }
local osd = "swayosd-client "
bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(osd .. "--output-volume raise"), "Volume up", held)
bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(osd .. "--output-volume lower"), "Volume down", held)
bind("XF86AudioMute", hl.dsp.exec_cmd(osd .. "--output-volume mute-toggle"), "Mute", once)
bind("XF86AudioMicMute", hl.dsp.exec_cmd(osd .. "--input-volume mute-toggle"), "Mute microphone", once)
bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), "Play / pause", once)
bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), "Next track", once)
bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), "Previous track", once)

-- Apps
bind(mod .. " + RETURN", hl.dsp.exec_cmd(terminal), "Terminal")
bind(mod .. " + E", hl.dsp.exec_cmd(files), "Files")
bind(mod .. " + B", hl.dsp.exec_cmd(browser), "Browser")

-- Windows
bind(mod .. " + Q", hl.dsp.window.close(), "Close window")
bind(mod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }), "Fullscreen")
bind(mod .. " + ALT + F", hl.dsp.window.fullscreen({ mode = "maximized" }), "Maximise")
bind(mod .. " + T", hl.dsp.window.float({ action = "toggle" }), "Toggle floating")
bind(mod .. " + P", hl.dsp.window.pseudo(), "Toggle pseudo-tile")
bind(mod .. " + J", hl.dsp.layout("togglesplit"), "Toggle split direction")
bind(mod .. " + mouse:272", hl.dsp.window.drag(), "Move window", { mouse = true })
bind(mod .. " + mouse:273", hl.dsp.window.resize(), "Resize window", { mouse = true })

local dirs = { left = "l", right = "r", up = "u", down = "d" }
for key, dir in pairs(dirs) do
  bind(mod .. " + " .. key, hl.dsp.focus({ direction = dir }), "Focus " .. key)
  bind(mod .. " + SHIFT + " .. key, hl.dsp.window.swap({ direction = dir }), "Swap window " .. key)
end

local grow = { repeating = true }
bind(mod .. " + minus", hl.dsp.window.resize({ x = -100, y = 0, relative = true }), "Narrower", grow)
bind(mod .. " + equal", hl.dsp.window.resize({ x = 100, y = 0, relative = true }), "Wider", grow)
bind(mod .. " + SHIFT + minus", hl.dsp.window.resize({ x = 0, y = -100, relative = true }), "Shorter", grow)
bind(mod .. " + SHIFT + equal", hl.dsp.window.resize({ x = 0, y = 100, relative = true }), "Taller", grow)

-- Workspaces
for i = 1, 10 do
  local key = i % 10
  bind(mod .. " + " .. key, hl.dsp.focus({ workspace = i }), "Workspace " .. i)
  bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }), "Move window to workspace " .. i)
end

bind(mod .. " + TAB", hl.dsp.focus({ workspace = "previous" }), "Previous workspace")
bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), "Next workspace")
bind(mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }), "Previous workspace")
bind(mod .. " + grave", hl.dsp.workspace.toggle_special("scratch"), "Scratchpad")
bind(mod .. " + SHIFT + grave", hl.dsp.window.move({ workspace = "special:scratch" }), "Move window to scratchpad")
