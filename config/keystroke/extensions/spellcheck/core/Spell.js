.pragma library

// One word through `hunspell -a`, which checks it against the dictionary of
// the session's locale. After its version banner hunspell prints "*", "+ root"
// or "-" for a word it knows, "& word count offset: a, b, c" for a misspelled
// one and "# word offset" when it has nothing to suggest.

var ICON = "󰓆"
var SECTION = "Spelling"
// The script prints the word first, so a verdict says which word it is for.
// "^" keeps hunspell from reading the line as one of its pipe-mode commands.
var CHECK = "printf '%s\\n' \"$1\"; printf '^%s\\n' \"$1\" | hunspell -a"

// QML's regex engine has no \p{L}: a word is two or more characters without
// spaces, digits or ASCII punctuation, the apostrophe aside.
var WORD = /^[^\s\d!-&(-\/:-@\[-`{-~]{2,}$/

function word(text) {
  var w = String(text || "").trim()
  return WORD.test(w) ? w : ""
}

// The word is one literal argument; the script never interpolates it.
function argv(w) { return ["sh", "-c", CHECK, "sh", String(w)] }

// { word, state: "known" | "wrong" | "unchecked", suggestions }. Unchecked:
// hunspell gave no verdict (no dictionary for the locale, say).
function parse(output) {
  var lines = String(output || "").split("\n"), verdict = lines[2] || ""
  var result = { word: lines[0], state: "unchecked", suggestions: [] }
  if (/^[*+-]/.test(verdict)) {
    result.state = "known"
  }
  if (/^[#&]/.test(verdict)) {
    result.state = "wrong"
  }
  if (verdict.charAt(0) === "&") {
    result.suggestions = verdict.slice(verdict.indexOf(":") + 1).split(",").map(function(s) { return s.trim() })
  }

  return result
}

function row(id, title, subtitle, tier, score) {
  return { id: id, title: title, subtitle: subtitle, icon: ICON, section: SECTION, tier: tier, score: score,
           verb: "Copy", action: { type: "copy", text: title } }
}

function rows(result, tier, limit) {
  if (result.state === "unchecked") {
    return []
  }
  if (result.state === "known") {
    return [row("known", result.word, "Spelled correctly", tier, 100)]
  }
  if (!result.suggestions.length) {
    return [{ id: "none", title: "No spelling suggestions", subtitle: result.word, icon: ICON, section: SECTION, tier: tier, score: 1,
              verb: "", disabled: true, action: { type: "noop" } }]
  }

  var out = []
  for (var i = 0; i < result.suggestions.length && i < limit; i++) {
    out.push(row("suggestion-" + i, result.suggestions[i], "Spelling of " + result.word, tier, 100 - i))
  }
  return out
}
