-- Shell layers: blur behind them, no Hyprland layer animation. Quickshell windows are named qs-*
hl.layer_rule({
  name = "shell",
  match = { namespace = "^(waybar|rofi|swaync-.*|swayosd|logout_dialog|qs-.*)$" },
  no_anim = true,
  blur = true,
})

-- Blur only where these layers paint something; wlogout is left out so its
-- transparent window blurs the whole screen behind the buttons
hl.layer_rule({
  name = "shell-ignore-alpha",
  match = { namespace = "^(waybar|rofi|swaync-.*|swayosd|qs-.*)$" },
  ignore_alpha = 0,
})

-- Browser and editor stay fully opaque
hl.window_rule({
  name = "opaque-apps",
  match = { class = "^(firefox|[Cc]ode|code-url-handler|com\\.microsoft\\.VSCode)$" },
  opaque = true,
})

-- Tools and dialogs float, centred (HyDE window_rules.lua, trimmed to what is installed)
hl.window_rule({
  name = "float-tools",
  match = {
    class = "^(com\\.gabm\\.satty|org\\.pulseaudio\\.pavucontrol|blueman-manager|nm-connection-editor"
      .. "|hyprland-share-picker|hyprpolkitagent|xdg-desktop-portal-gtk|org\\.gnome\\.Loupe)$",
  },
  float = true,
  center = true,
})

hl.window_rule({
  name = "float-dialogs",
  match = { title = "^(Open|Save As|Open File|Choose Files|Authentication Required|File Upload).*" },
  float = true,
  center = true,
})

-- Browser Picture-in-Picture: float, pin to every workspace, sit bottom-right
-- and do not steal focus from the page that spawned it
hl.window_rule({
  name = "picture-in-picture",
  match = { title = "^(Picture-in-Picture|Picture in Picture)$" },
  float = true,
  pin = true,
  keep_aspect_ratio = true,
  no_initial_focus = true,
  -- 16:9, half the screen height wide. move runs before size, so it repeats
  -- the size expressions instead of using window_w/window_h
  size = { "monitor_h * 0.5", "monitor_h * 0.28125" },
  move = { "monitor_w - monitor_h * 0.5 - 20", "monitor_h - monitor_h * 0.28125 - 20" },
})

hl.window_rule({
  name = "suppress-maximize",
  match = { class = ".*" },
  suppress_event = "maximize",
})

hl.window_rule({
  name = "fix-xwayland-drags",
  match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
  no_focus = true,
})

-- Persistent workspaces keep the bar's workspace indicator stable
for i = 1, 5 do
  hl.workspace_rule({ workspace = tostring(i), monitor = MONITOR, persistent = true })
end
