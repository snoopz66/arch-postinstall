.pragma library
.import "Match.js" as Match

// Hyprland's keybindings as palette rows, from `hyprctl binds -j`. A bind is
// listed when it has a description (hypr/binds.lua gives every bind one).
// Hyprland reports a Lua bind's action as an opaque handle, so binds.lua also
// keeps each dispatcher in the global table `keybinds`, by description;
// running a row dispatches `keybinds["<description>"]`.

var MODMASKS = [[64, "SUPER"], [4, "CTRL"], [8, "ALT"], [1, "SHIFT"]]
var POINTER = { "mouse:272": "LEFT MOUSE BUTTON", "mouse:273": "RIGHT MOUSE BUTTON", "mouse:274": "MIDDLE MOUSE BUTTON",
                mouse_down: "SCROLL DOWN", mouse_up: "SCROLL UP" }

function loadArgv() { return ["hyprctl", "binds", "-j"] }

// The Lua expression is one literal argument; no shell reads it.
function dispatchArgv(arg) { return ["hyprctl", "dispatch", String(arg || "")] }

function slug(text) {
  return String(text || "").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "")
}

function luaString(text) { return "\"" + String(text).replace(/\\/g, "\\\\").replace(/"/g, "\\\"") + "\"" }

// "SUPER SHIFT + RETURN", the spelling keys() reads.
function combo(bind) {
  var mods = []
  for (var i = 0; i < MODMASKS.length; i++) if (bind.modmask & MODMASKS[i][0]) mods.push(MODMASKS[i][1])
  var key = POINTER[bind.key] || String(bind.key || "")
  return mods.length ? mods.join(" ") + " + " + key : key
}

// One bind per description, in config order. A description bound twice
// (Browser on Super+Shift+Return and Super+Shift+B) is one bind with two
// combos, so the row the user learns from lists every way to press it. A
// mouse bind (drag to move) has nothing to run from a menu.
function parse(text) {
  var list
  try { list = JSON.parse(String(text || "")) } catch (e) { return [] }
  if (!Array.isArray(list)) return []
  var binds = [], byLabel = ({})
  for (var i = 0; i < list.length; i++) {
    var b = list[i]
    if (!b || !b.has_description || !b.description) continue
    var label = String(b.description), keys = combo(b)
    var hit = byLabel[label]
    if (hit) { if (hit.combos.indexOf(keys) < 0) hit.combos.push(keys); continue }
    var kind = String(b.dispatcher || "").replace(/^HL\.Dispatcher\((.*)\)$/, "$1")
    var bind = { id: slug(label) || "bind", label: label, combos: [keys], dispatcher: b.mouse ? "" : "lua",
                 arg: b.mouse ? "" : "keybinds[" + luaString(label) + "]", kind: kind, order: binds.length }
    byLabel[label] = bind
    binds.push(bind)
  }
  return binds
}

var MODIFIERS = { SUPER: "Super", SHIFT: "Shift", CTRL: "Ctrl", ALT: "Alt" }
var KEYS = {
  RETURN: "↵", ENTER: "↵", SPACE: "Space", ESCAPE: "Esc", TAB: "Tab", BACKSPACE: "⌫", DELETE: "Del",
  PRINT: "Print", HOME: "Home", END: "End", PRIOR: "PgUp", NEXT: "PgDn", INSERT: "Ins",
  LEFT: "←", RIGHT: "→", UP: "↑", DOWN: "↓",
  COMMA: ",", PERIOD: ".", MINUS: "-", EQUAL: "=", SLASH: "/", BACKSLASH: "\\", GRAVE: "`",
  BRACKETLEFT: "[", BRACKETRIGHT: "]", SEMICOLON: ";", APOSTROPHE: "'"
}

function keyName(raw) {
  var key = String(raw || "").trim()
  if (!key) return ""
  var upper = key.toUpperCase()
  if (KEYS[upper]) return KEYS[upper]
  if (key.indexOf("XF86") === 0) return key.substring(4).replace(/([a-z])([A-Z])/g, "$1 $2")
  if (/^(LEFT|RIGHT|MIDDLE) MOUSE BUTTON$/.test(upper)) return upper.charAt(0) + upper.substring(1, upper.indexOf(" ")).toLowerCase() + " click"
  if (/^[A-Z]$/.test(upper)) return upper
  if (/^F[0-9]{1,2}$/.test(upper)) return upper
  if (upper === key && key.length > 1 && !/^(code|mouse):/.test(key)) return key.charAt(0) + key.substring(1).toLowerCase()
  return key
}

// "SUPER SHIFT + RETURN" → "Super + Shift + ↵": the record's spelling, made
// readable the way the palette's own key hints are.
function keys(combo) {
  var text = String(combo || "").trim()
  if (!text) return ""
  var plus = text.lastIndexOf(" + ")
  var mods = plus < 0 ? [] : text.substring(0, plus).split(/\s+/)
  var key = plus < 0 ? text : text.substring(plus + 3)
  var parts = []
  for (var i = 0; i < mods.length; i++) if (mods[i]) parts.push(MODIFIERS[mods[i].toUpperCase()] || keyName(mods[i]))
  parts.push(keyName(key))
  return parts.join(" + ")
}

function accessory(bind) {
  var out = []
  for (var i = 0; i < bind.combos.length; i++) out.push(keys(bind.combos[i]))
  return out.join("  ·  ")
}

function runnable(bind) { return !!bind.dispatcher }

function subtitle(bind) {
  if (!bind.dispatcher) return "Only with the mouse"
  return bind.kind === "exec_cmd" ? "Runs a command" : "Hyprland " + bind.kind.replace(/_/g, " ")
}

function comboKey(text) { return String(text || "").toLowerCase().replace(/\s*\+\s*/g, " ").replace(/\s+/g, " ").trim() }

// Abbreviations and the combo itself both find a bind: "flcrn" walks Full
// screen, "super f" lands on its keys.
function keywords(bind) {
  if (bind.searchKeywords !== undefined) return bind.searchKeywords
  var words = []
  for (var i = 0; i < bind.combos.length; i++) words.push(comboKey(bind.combos[i]))
  return (bind.searchKeywords = words.join(" "))
}

function row(bind, score) {
  var can = runnable(bind)
  return {
    id: bind.id, title: bind.label, subtitle: subtitle(bind), icon: "",
    section: "Hotkeys", verb: can ? "Run" : "", tier: "item", score: score, order: bind.order,
    accessory: accessory(bind), disabled: !can, remember: can,
    previewLabel: "HOTKEY", previewDetail: accessory(bind),
    action: can ? { type: "hotkey", dispatcher: bind.dispatcher, arg: bind.arg } : { type: "noop" }
  }
}

function navRow(score) {
  return { id: "hotkeys", title: "Hotkeys", subtitle: "Every Hyprland keybinding, searchable", icon: "", section: "Hotkeys",
           verb: "Open", tier: "item", score: score, order: 8, action: { type: "navigate", scope: "hotkeys", title: "Hotkeys" } }
}

// The screen lists every bind in config order; the root mixes
// the best `limit` matches into the global search and never the whole list.
function rows(query, binds, settings, inScreen) {
  var q = String(query || "").trim()
  var qk = comboKey(q)
  // "super + f" as people write combos: a lone plus is punctuation, not a term.
  var needle = q.replace(/(^|\s)\+(?=\s|$)/g, " ").replace(/\s+/g, " ").trim() || q
  var showKeyboardOnly = !settings || settings.keyboardOnly !== false
  var limit = settings && settings.limit > 0 ? settings.limit : 10
  var out = [], scored = []
  for (var i = 0; i < binds.length; i++) {
    var bind = binds[i]
    if (!runnable(bind) && !showKeyboardOnly) continue
    if (!q) { if (inScreen) out.push(row(bind, 1)); continue }
    var s = Match.match(needle, bind.label, keywords(bind))
    if (!s) continue
    // The keys spelled out ("super f") name one bind; it outranks the binds that merely contain them.
    for (var c = 0; c < bind.combos.length; c++) if (comboKey(bind.combos[c]) === qk) { s += 25; break }
    if (inScreen) out.push(row(bind, s)); else scored.push({ bind: bind, score: s, order: bind.order })
  }
  if (!inScreen && q) {
    // At the root only `limit` rows survive; build just those.
    scored.sort(function(a, b) { return b.score - a.score || a.order - b.order })
    for (i = 0; i < scored.length && i < limit; i++) out.push(row(scored[i].bind, scored[i].score))
  }
  return out
}
