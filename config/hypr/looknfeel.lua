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

-- Animations. Without this block Hyprland falls back to 800ms on everything, which is slow
-- enough to be nauseating. Speed is in 100ms units. Workspaces fade instead of sliding so
-- switching does not drag the whole screen sideways.
-- https://wiki.hypr.land/Configuring/Animations/
hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })

hl.animation({ leaf = "global", enabled = true, speed = 2, bezier = "easeOutQuint" })
hl.animation({ leaf = "border", enabled = true, speed = 2, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows", enabled = true, speed = 2, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 2, bezier = "easeOutQuint", style = "popin 90%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.2, bezier = "linear", style = "popin 90%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 2, bezier = "easeOutQuint" })
hl.animation({ leaf = "fade", enabled = true, speed = 1.5, bezier = "quick" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.2, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1, bezier = "almostLinear" })
hl.animation({ leaf = "layers", enabled = true, speed = 1.5, bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 1.5, bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1, bezier = "linear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.2, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 1.5, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 1.2, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.5, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 1.5, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 3, bezier = "quick" })
