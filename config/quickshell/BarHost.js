.pragma library

// The bar's layout file (~/.config/bar/bar.json), as read and written by BarHost.qml.

// The bar's code knows its widgets as "omarchy.<name>"; the layout file leaves the prefix out.
var PREFIX = "omarchy."
var SECTIONS = ["left", "centerBegin", "center", "centerEnd", "right", "tray"]

function fullId(name) {
  return String(name).indexOf(".") < 0 ? PREFIX + name : String(name)
}

function shortId(id) {
  return String(id).indexOf(PREFIX) === 0 ? String(id).slice(PREFIX.length) : String(id)
}

// A copy of the bar config with the id of every widget entry passed through rename.
// Custom modules (entries with a type) keep the id they were given.
function renamed(bar, rename) {
  var copy = JSON.parse(JSON.stringify(bar))
  var layout = copy.layout || {}

  SECTIONS.forEach(function(section) {
    if (!Array.isArray(layout[section])) {
      return
    }

    layout[section] = layout[section].map(function(entry) {
      if (typeof entry === "string") {
        return { id: rename(entry) }
      }
      if (!entry.type) {
        entry.id = rename(entry.id)
      }
      return entry
    })
  })

  return copy
}

// The bar config in a layout file's text, ids prefixed; null when the text is not one.
function parse(text) {
  var bar = null
  try {
    bar = JSON.parse(text)
  } catch (error) {
    return null
  }

  if (bar === null || typeof bar !== "object" || Array.isArray(bar)) {
    return null
  }
  return renamed(bar, fullId)
}

function serialize(bar) {
  return JSON.stringify(renamed(bar, shortId), null, 2) + "\n"
}

// A copy of the bar config in which the widget's entry carries these settings, in the place
// it had; null when the widget is not on the bar or already has them.
function withEntry(bar, id, settings) {
  var copy = JSON.parse(JSON.stringify(bar))
  var layout = copy.layout || {}
  var next = { id: id }
  for (var key in settings) {
    if (key !== "id") {
      next[key] = settings[key]
    }
  }

  var changed = false
  SECTIONS.forEach(function(section) {
    var entries = Array.isArray(layout[section]) ? layout[section] : []
    for (var i = 0; i < entries.length; i++) {
      if (entries[i].id === id && JSON.stringify(entries[i]) !== JSON.stringify(next)) {
        entries[i] = next
        changed = true
      }
    }
  })

  return changed ? copy : null
}
