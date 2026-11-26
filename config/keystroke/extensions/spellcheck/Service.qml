import QtQuick
import Quickshell.Io
import "core/Spell.js" as Spell

// Spell check: one word through hunspell. `sp recieve` answers first; a lone
// word typed at the root is checked too, below the other results.
QtObject {
  id: root
  property var extension: null
  property var host: null
  readonly property string key: extension && extension.id ? String(extension.id) : "spellcheck"
  property var results: ({})   // word → Spell.parse's result, for the session
  property string checking: ""

  readonly property var provider: ({
    apiVersion: 1, name: "Spell check", icon: Spell.ICON, color: "#e5c07b",
    description: "Check a word's spelling with hunspell",
    settings: [
      { key: "limit", type: "number", label: "Corrections shown", "default": 5, min: 1, max: 15, integer: true }
    ],
    query: function(ctx) { return root.query(ctx) }
  })

  function query(ctx) {
    root.host = ctx.host || root.host
    if (ctx.scope) {
      return []
    }

    var word = Spell.word(ctx.command ? ctx.command.rest : ctx.query)
    if (!word) {
      return []
    }

    var result = root.results[word]
    if (result) {
      return Spell.rows(result, ctx.command ? "answer" : "fallback", ctx.settings.limit)
    }

    root.check(word)
    ctx.pending()
    return []
  }

  // One word at a time; a newer word replaces the one being checked.
  function check(word) {
    if (root.checking === word) {
      return
    }

    root.checking = word
    hunspell.exec(Spell.argv(word))
  }

  readonly property Process hunspell: Process {
    stdout: StdioCollector { id: verdict }
    // A check cut short by the next word exits abnormally and is dropped.
    onExited: function(code, status) {
      if (code !== 0 || status !== 0) {
        return
      }

      var result = Spell.parse(verdict.text)
      var next = Object.assign({}, root.results)
      next[result.word] = result
      root.results = next
      if (result.word === root.checking) {
        root.checking = ""
      }
      if (root.host.opened) {
        root.host.requery({ catalog: false, provider: root.key })
      }
    }
  }
}
