import QtQuick
import Quickshell
import "core/Quick.js" as Quick

// Quick actions: the wallpaper picker and a screenshot on the launcher's
// first list, and those two and the keybind list found by name.
QtObject {
  id: root
  readonly property string home: Quickshell.env("HOME")

  readonly property var provider: ({
    apiVersion: 1, name: "Quick actions", icon: "", color: "#98c379",
    description: "Wallpaper, screenshot, keybinds",
    settings: [],
    query: function(ctx) { return ctx.scope ? [] : Quick.rows(ctx.query, root.home) }
  })
}
