.pragma library

// Desktop actions as launcher rows: the wallpaper picker, a screenshot, the keybind list.

var SECTION = "Quick actions"
// The first list's scores: Applications is 30, Clipboard History 26.
var TOP = 29

function actions(home) {
  return [
    { id: "wallpaper", title: "Wallpaper", subtitle: "Pick one; the colours follow it", icon: "",
      keywords: "background theme colours colors", verb: "Open",
      action: { type: "exec", argv: ["qs", "ipc", "call", "wallpapers", "open"] } },
    { id: "screenshot", title: "Screenshot", subtitle: "Grab a region, then annotate, copy or save", icon: "",
      keywords: "shot capture grab region screen", verb: "Capture",
      action: { type: "exec", argv: [home + "/.local/bin/screenshot", "region"] } },
    // The first list already shows this screen as Hotkeys; this name finds it too.
    { id: "keybinds", title: "Keybinds", subtitle: "Every Hyprland keybinding, searchable", icon: "",
      keywords: "keys shortcuts bindings", verb: "Open", searchOnly: true,
      action: { type: "navigate", scope: "hotkeys", title: "Hotkeys" } }
  ]
}

// Without a query the rows take fixed places; with one, the launcher's own
// matcher scores them on title and keywords, and picks are remembered.
function rows(query, home) {
  var out = []
  actions(home).forEach(function(action, i) {
    if (!query && action.searchOnly) {
      return
    }

    var row = { id: action.id, title: action.title, subtitle: action.subtitle, icon: action.icon, keywords: action.keywords,
                section: SECTION, verb: action.verb, tier: "item", order: i, remember: !!query, action: action.action }
    if (!query) {
      row.score = TOP - i
    }
    out.push(row)
  })
  return out
}
