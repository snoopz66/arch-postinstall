// List menus in the launcher's style without the sidebar: quick actions, window switcher, clipboard
// history and the keybind list. Type to filter, Up/Down and Return pick, Escape closes.
// Open with: qs ipc call menu toggle quick|windows|clipboard|keybinds
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets

PanelWindow {
  id: menu
  visible: false

  // same em as the launcher: 18px, text at 10pt
  readonly property int em: 18
  readonly property int fontSize: 13

  // the list on show and its rows: { text, note, icon, glyph, run }, all but text optional
  property string list: ""
  property var items: []

  // per list: window width in em, rows before it scrolls, whether rows carry an icon, and for the
  // lists that come from a command, the command and what turns its output into rows
  readonly property var lists: ({
    quick: { width: 30, lines: 8, icons: true },
    windows: { width: 44, lines: 8, icons: true, command: ["hyprctl", "clients", "-j"], parse: windowRows },
    clipboard: { width: 44, lines: 12, icons: false, command: ["cliphist", "list"], parse: clipboardRows },
    keybinds: { width: 44, lines: 18, icons: false, command: ["hyprctl", "binds", "-j"], parse: keybindRows },
  })
  readonly property var shape: lists[list] ?? lists.quick

  readonly property int rowHeight: (shape.icons ? 1.6 : 1) * em + em // 0.5em padding above and below
  readonly property int rowSpacing: 0.2 * em
  readonly property int shown: Math.max(1, Math.min(items.length, shape.lines))

  // unanchored, so the compositor centers it; as tall as its rows, up to the list's limit
  implicitWidth: shape.width * em
  implicitHeight: 2 * em + 35 + 0.6 * em + shown * rowHeight + (shown - 1) * rowSpacing
  color: "transparent"
  WlrLayershell.namespace: "qs-menu"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

  signal wallpaperPicker()

  readonly property var quickRows: [
    { glyph: "", text: "Wallpaper", run: () => menu.wallpaperPicker() },
    { glyph: "", text: "Screenshot", run: () => Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/screenshot", "region"]) },
    { glyph: "", text: "Keybinds", run: () => menu.open("keybinds") },
  ]

  // most recently focused first, so the second row is the window to go back to
  function windowRows(json: string): var {
    return JSON.parse(json)
      .filter(c => c.mapped)
      .sort((a, b) => a.focusHistoryID - b.focusHistoryID)
      .map(c => ({
        text: c.title,
        note: c.workspace.name,
        icon: DesktopEntries.heuristicLookup(c.class)?.icon ?? c.class,
        run: () => Quickshell.execDetached(["hyprctl", "dispatch", `hl.dsp.focus({ window = "address:${c.address}" })`]),
      }));
  }

  // cliphist lists "id<TAB>preview" and decodes the same line back into the entry
  function clipboardRows(lines: string): var {
    return lines.split("\n").filter(l => l !== "").map(l => ({
      text: l.slice(l.indexOf("\t") + 1),
      run: () => Quickshell.execDetached(["sh", "-c", 'printf %s "$1" | cliphist decode | wl-copy', "sh", l]),
    }));
  }

  // every Hyprland bind that has a description (hypr/binds.lua)
  function keybindRows(json: string): var {
    const mods = [[64, "SUPER"], [4, "CTRL"], [8, "ALT"], [1, "SHIFT"]];
    const names = { "mouse:272": "LMB", "mouse:273": "RMB", mouse_down: "scroll down", mouse_up: "scroll up" };
    return JSON.parse(json).filter(b => b.has_description).map(b => ({
      text: b.description,
      note: mods.filter(m => b.modmask & m[0]).map(m => m[1])
        .concat(names[b.key] ?? b.key.replace("XF86Audio", "")).join(" + "),
    }));
  }

  // lists that come from a command show once it has answered, so the window opens at its final size
  function open(name: string): void {
    if (!lists[name]) return;
    list = name;
    if (shape.command) source.exec(shape.command);
    else present(quickRows);
  }
  function present(rows: var): void {
    items = rows;
    search.text = "";
    view.currentIndex = list === "windows" && rows.length > 1 ? 1 : 0;
    visible = true;
    search.forceActiveFocus();
  }
  function close(): void { visible = false; }
  function toggle(name: string): void {
    if (visible && list === name) close();
    else open(name);
  }

  // hide first: the row's action may open another list
  function pick(row: var): void {
    visible = false;
    if (row && row.run) row.run();
  }

  Process {
    id: source
    stdout: StdioCollector {
      onStreamFinished: menu.present(menu.shape.parse(text))
    }
  }

  // every word typed has to be in the row
  readonly property var matches: {
    const words = search.text.toLowerCase().split(/\s+/).filter(w => w !== "");
    if (words.length === 0) return items;
    return items.filter(i => {
      const row = (i.text + " " + (i.note ?? "")).toLowerCase();
      return words.every(w => row.includes(w));
    });
  }

  // click outside closes
  HyprlandFocusGrab {
    windows: [menu]
    active: menu.visible
    onCleared: menu.visible = false
  }

  Rectangle {
    anchors.fill: parent
    radius: 30
    // main-bg: surface at 70%; Hyprland blurs behind qs-* layers (hypr/rules.lua)
    color: Qt.alpha(Theme.colors.surface, 0.7)
    border.width: 2
    border.color: Qt.alpha(Theme.colors.primary, 0.9) // main-br

    Column {
      anchors { fill: parent; margins: menu.em }
      spacing: 0.6 * menu.em

      // inputbar
      Rectangle {
        width: parent.width
        height: 35
        radius: 20
        color: Qt.alpha(Theme.colors.surface_container, 0.9) // main-ex

        TextInput {
          id: search
          anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
          anchors.leftMargin: 1.2 * menu.em
          anchors.rightMargin: 1.2 * menu.em
          font.family: Theme.font
          font.pixelSize: menu.fontSize
          color: Qt.alpha(Theme.colors.primary_fixed, 0.9) // main-fg
          selectionColor: Qt.alpha(Theme.colors.primary, 0.5)
          selectedTextColor: Theme.colors.on_primary
          clip: true

          Keys.onUpPressed: view.decrementCurrentIndex()
          Keys.onDownPressed: view.incrementCurrentIndex()
          Keys.onReturnPressed: menu.pick(menu.matches[view.currentIndex])
          Keys.onEnterPressed: menu.pick(menu.matches[view.currentIndex])
          Keys.onEscapePressed: menu.visible = false

          Text {
            anchors.fill: parent
            visible: search.text === ""
            text: "Search"
            font: search.font
            color: search.color
            verticalAlignment: Text.AlignVCenter
          }
        }
      }

      // listview
      ListView {
        id: view
        width: parent.width
        height: menu.shown * menu.rowHeight + (menu.shown - 1) * menu.rowSpacing
        model: menu.matches
        onModelChanged: currentIndex = 0
        spacing: menu.rowSpacing
        clip: true
        keyNavigationWraps: true // cycle
        boundsBehavior: Flickable.StopAtBounds
        highlightMoveDuration: 0
        highlightResizeDuration: 0
        preferredHighlightBegin: 0
        preferredHighlightEnd: height
        highlightRangeMode: ListView.ApplyRange

        // element
        delegate: Rectangle {
          id: row
          required property var modelData
          required property int index
          readonly property bool selected: ListView.isCurrentItem
          readonly property color fg: selected ? Qt.alpha(Theme.colors.on_primary, 0.9) : Qt.alpha(Theme.colors.primary_fixed, 0.9)
          width: view.width
          height: menu.rowHeight
          radius: 20
          color: selected ? Qt.alpha(Theme.colors.primary, 0.5) : "transparent" // select-bg

          // the icon's column: an app icon or a font glyph, nothing on lists without icons
          Item {
            id: icon
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            anchors.leftMargin: menu.em
            width: menu.shape.icons ? 1.6 * menu.em : 0
            height: 1.6 * menu.em

            IconImage {
              anchors.fill: parent
              visible: row.modelData.icon !== undefined
              source: visible ? Quickshell.iconPath(row.modelData.icon, true) : ""
              asynchronous: true
            }
            Text {
              anchors.centerIn: parent
              visible: row.modelData.glyph !== undefined
              text: row.modelData.glyph ?? ""
              font.family: Theme.font
              font.pixelSize: 1.1 * menu.em
              color: row.fg
            }
          }

          Text {
            anchors { left: icon.right; right: note.left; verticalCenter: parent.verticalCenter }
            anchors.leftMargin: menu.shape.icons ? 0.8 * menu.em : 0
            anchors.rightMargin: 0.8 * menu.em
            text: row.modelData.text
            font.family: Theme.font
            font.pixelSize: menu.fontSize
            color: row.fg
            elide: Text.ElideRight
            maximumLineCount: 1
          }

          // right-hand column: the workspace of a window, the keys of a bind
          Text {
            id: note
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            anchors.rightMargin: menu.em
            text: row.modelData.note ?? ""
            font.family: Theme.font
            font.pixelSize: menu.fontSize
            color: row.fg
            opacity: 0.7
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: view.currentIndex = row.index
            onClicked: menu.pick(row.modelData)
          }
        }
      }
    }
  }
}
