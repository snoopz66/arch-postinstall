// Whether a notification reaches the screen. Pure functions over a snapshot
// row (Store.snapshot).
.pragma library

var CRITICAL = 2

// Bare notify-send critical alerts get through Do Not Disturb. Critical alone
// is not enough: chat apps send critical to force visibility, under their own
// app name.
function bypassesQuiet(row) {
  return String((row && row.app) || "") === "notify-send" && Number(row.urgency) === CRITICAL
}

// The buttons a card offers, in the order it draws them and the number keys
// count them: copying each code it found, then the sender's own actions. A
// code's label is left to the card, which translates it.
function deeds(row, senderActions) {
  var out = []
  var codes = String((row && (row.codes || row.code)) || "").split(" ")
  for (var c = 0; c < codes.length; c++)
    if (codes[c]) out.push({ kind: "code", value: codes[c], label: "" })
  var actions = senderActions || []
  for (var i = 0; i < actions.length; i++)
    out.push({ kind: "action", value: String(actions[i].id), label: String(actions[i].text || "") })
  return out
}

// Nobody looks back at these (the `transient` hint, or an unnamed sender), so
// quiet drops them rather than holding them.
function isEphemeral(row) {
  if (row && row.transient === true) return true
  return String((row && row.app) || "") === "notify-send"
}

// "silenced", or "" when the row shows. A verification code always passes: it
// was asked for a moment ago and expires in minutes.
function quietReason(row, doNotDisturb) {
  if (!doNotDisturb) return ""
  if (bypassesQuiet(row)) return ""
  if (String((row && row.code) || "")) return ""
  return "silenced"
}

// A summary that opens with its own glyph ("󰂚  Silenced": one code point, two
// spaces) already carries its mark, so the card drops the icon slot.
function summaryStartsWithGlyph(summary) {
  var text = String(summary || "").replace(/^\s+/, "")
  if (!text) return false
  var offset = 1
  var first = text.charCodeAt(0)
  if (first >= 0xd800 && first <= 0xdbff && text.length > 1) offset = 2
  var spaces = 0
  while (offset < text.length && text.charAt(offset) === " ") {
    spaces++
    offset++
  }
  return spaces >= 2
}
