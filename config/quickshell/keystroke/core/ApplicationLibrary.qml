import QtQuick
import Quickshell
import "Terminal.js" as Terminal

// The applications Keystroke lists and launches: the desktop entries
// Quickshell indexes, hidden ones left out. Stands in for Omarchy's
// AppLibrary, whose API providers/Applications.qml and the host call.
Item {
  id: root
  signal appsChanged()

  Connections {
    target: DesktopEntries.applications
    function onValuesChanged() { root.appsChanged() }
  }

  function entryName(entry) { return String(entry.name || entry.id) }
  function entrySubtext(entry) { return String(entry.genericName || "") }

  // [{ entry }], by name.
  function sortedEntries() {
    return DesktopEntries.applications.values
      .filter(function(entry) { return !entry.noDisplay })
      .sort(function(a, b) { return root.entryName(a).localeCompare(root.entryName(b), undefined, { sensitivity: "base" }) })
      .map(function(entry) { return { entry: entry } })
  }

  function iconSource(icon) { return Quickshell.iconPath(String(icon || ""), "application-x-executable") }

  function launch(id) {
    var entry = DesktopEntries.byId(id)
    if (!entry) {
      return
    }

    if (entry.runInTerminal) {
      Quickshell.execDetached(Terminal.run(entry.command))
    } else {
      entry.execute()
    }
  }
}
