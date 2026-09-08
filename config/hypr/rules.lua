-- Shell layers: blur behind them, no Hyprland layer animation
hl.layer_rule({
  name = "shell",
  match = { namespace = "^(waybar|rofi|swaync-.*|swayosd|logout_dialog)$" },
  no_anim = true,
  ignore_alpha = 0,
  blur = true,
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
