// Colors from the wallpaper: matugen renders every Material role into colors.json (see matugen/config.toml),
// the FileView re-reads it on change so widgets recolor live. Fonts and radii match the waybar pills.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  readonly property var colors: adapter
  readonly property string font: "JetBrainsMono Nerd Font"
  readonly property int fontSize: 14
  readonly property int radius: 14
  readonly property int padding: 16

  FileView {
    path: Quickshell.env("HOME") + "/.cache/wallpaper/colors.json"
    watchChanges: true
    onFileChanged: reload()

    JsonAdapter {
      id: adapter
      // defaults are the stock wall2 palette, used until the file loads
      property string surface: "#101418"
      property string surface_container: "#1c2024"
      property string surface_container_high: "#272a2f"
      property string surface_container_highest: "#32353a"
      property string on_surface: "#e0e2e9"
      property string on_surface_variant: "#c4c6cf"
      property string outline: "#8e9099"
      property string outline_variant: "#44474e"
      property string primary: "#a8c8ff"
      property string on_primary: "#00315b"
      property string primary_fixed: "#d5e3ff"
      property string secondary: "#bdc7dc"
      property string tertiary: "#cec0e8"
      property string on_tertiary: "#352b4b"
      property string tertiary_fixed: "#eaddff"
      property string error: "#ffb4ab"
    }
  }
}
