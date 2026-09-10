-- Login screen compositor: Hyprland running regreet, on the same monitor layout as the session.
-- greeter-sync (run by the session) writes /var/lib/greeter/monitors.lua from `hyprctl monitors all`;
-- cage cannot set a mode, so it showed this monitor's EDID-preferred 3840x1080 instead of 5120x1440.
-- https://github.com/rharish101/ReGreet#set-as-default-session
local ok, err = pcall(dofile, "/var/lib/greeter/monitors.lua")
if not ok then
  print("greeter: " .. tostring(err) .. ", using preferred modes")
  hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
end

hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("HYPRCURSOR_SIZE", "24")
-- no portal in the greeter session; without these GTK waits for one before showing the window
hl.env("GTK_USE_PORTAL", "0")
hl.env("GDK_DEBUG", "no-portals")

hl.config({
  misc = {
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    disable_hyprland_guiutils_check = true,
  },
  decoration = { blur = { enabled = false } },
  animations = { enabled = false },
})

hl.on("hyprland.start", function()
  hl.exec_cmd("regreet -s /var/lib/greeter/regreet.css; hyprctl dispatch exit")
end)
