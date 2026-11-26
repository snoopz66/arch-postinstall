import QtQuick
import Quickshell
import Quickshell.Io
import "../core/Match.js" as Match
import "../core/Cliphist.js" as Cliphist

// The history cliphist already keeps (core/Cliphist.js), listed again on every
// summon. No second watcher, no duplicate capture. Never included in the
// global search.
Item {
  id: root
  property var host: null
  property var entries: []

  readonly property var provider: ({
    apiVersion: 1,
    id: "clipboard",
    name: "Clipboard History",
    icon: "󰅌",
    color: "#8dbaec",
    description: "Uses cliphist's existing history",
    settings: [
      { key: "limit", type: "number", label: "Maximum entries", "default": 100, min: 1, max: 300, integer: true }
    ],
    query: function(ctx) { return root.query(ctx) },
    opened: function() { lister.running = true }
  })

  Process {
    id: lister
    command: Cliphist.listArgv()
    stdout: StdioCollector {
      onStreamFinished: {
        root.entries = Cliphist.parse(text)
        if (root.host) root.host.requery({ catalog: false, provider: root.provider.id })
      }
    }
  }

  function query(ctx) {
    if (ctx.scope && ctx.scope !== "clipboard") return []
    if (!ctx.scope) {
      var s = ctx.query ? Match.match(ctx.query, "Clipboard History", "paste copied text images") : 26
      return s ? [{ id: "clipboard", title: "Clipboard History", subtitle: "Text & images, ready to use again", icon: "󰅌", section: "Clipboard",
                    verb: "Open", tier: "item", score: s, order: 2, action: { type: "navigate", scope: "clipboard", title: "Clipboard" } }] : []
    }
    var rows = []
    for (var i = 0; i < root.entries.length && rows.length < ctx.settings.limit; i++) {
      var e = root.entries[i]
      var title = e.text.replace(/\s+/g, " ").slice(0, 120)
      var score = Match.match(ctx.query, title)
      if (!score) continue
      rows.push({
        id: Qt.md5(e.line), title: title, subtitle: e.image ? "Image" : "Text", icon: "󰅌",
        section: "Clipboard", tier: "item", score: score, order: i,
        verb: "Copy", action: { type: "exec", argv: Cliphist.copyArgv(e.line) }
      })
    }
    return rows
  }
}
