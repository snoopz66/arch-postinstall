hl.on("hyprland.start", function()
  hl.exec_cmd("systemctl --user start hyprpolkitagent")
  hl.exec_cmd("hyprpaper")
  hl.exec_cmd("waybar")
  hl.exec_cmd("qs")
  -- the unit: D-Bus activates it too, a plain exec races that and fails
  hl.exec_cmd("systemctl --user start swaync")
  hl.exec_cmd("swayosd-server")
  hl.exec_cmd("hypridle")
  hl.exec_cmd("wl-paste --type text --watch cliphist store")
  hl.exec_cmd("wl-paste --type image --watch cliphist store")
  hl.exec_cmd("udiskie --no-notify --no-tray")
  hl.exec_cmd("fcitx5 -d")
  hl.exec_cmd("dropbox")
end)

-- keep the login screen on this monitor layout (see bin/greeter-sync)
for _, event in ipairs({ "hyprland.start", "config.reloaded", "monitor.added", "monitor.removed", "monitor.layout_changed" }) do
  hl.on(event, function()
    hl.exec_cmd("~/.local/bin/greeter-sync")
  end)
end
