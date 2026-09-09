-- Shell layers: blur behind them, no Hyprland layer animation
hl.layer_rule({
  name = "shell",
  match = { namespace = "^(waybar|rofi|swaync-.*|swayosd|logout_dialog)$" },
  no_anim = true,
  blur = true,
})

-- Blur only where these layers paint something; wlogout is left out so its
-- transparent window blurs the whole screen behind the buttons
hl.layer_rule({
  name = "shell-ignore-alpha",
  match = { namespace = "^(waybar|rofi|swaync-.*|swayosd)$" },
  ignore_alpha = 0,
})

-- Browser and editor stay fully opaque
hl.window_rule({
  name = "opaque-apps",
  match = { class = "^(firefox|[Cc]ode|code-url-handler)$" },
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
