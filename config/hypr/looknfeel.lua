-- HyDE look: https://github.com/HyDE-Project/hyde-themes (hypr.theme)
local colors = require("colors") -- written by matugen

hl.config({
  general = {
    gaps_in = 3,
    gaps_out = 8,
    border_size = 2,
    col = {
      active_border = { colors = colors.active, angle = 45 },
      inactive_border = { colors = colors.inactive, angle = 45 },
    },
    layout = "dwindle",
    resize_on_border = true,
  },
  decoration = {
    rounding = 10,
    active_opacity = 0.90,
    inactive_opacity = 0.75,
    fullscreen_opacity = 1,
    dim_special = 0.3,
    shadow = { enabled = false },
    blur = { enabled = true, size = 6, passes = 3, ignore_opacity = true, xray = false, special = true },
  },
  dwindle = { preserve_split = true },
  master = { new_status = "master" },
  binds = { workspace_back_and_forth = true },
  misc = {
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    force_default_wallpaper = 0,
    middle_click_paste = false,
  },
})
