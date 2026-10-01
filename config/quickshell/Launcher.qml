// App launcher: the look of the rofi drun theme (config/rofi/config.rasi, HyDE style 1) without the
// mode switcher. Wallpaper panel on the left, search box and eight app rows on the right.
// Open with: qs ipc call launcher toggle
// Desktop entries: https://quickshell.org/docs/types/Quickshell/DesktopEntries/
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets

PanelWindow {
  id: launcher
  visible: false

  // rofi sizes are in em of "JetBrainsMono Nerd Font 10", 1em = 18px: window 63em x 33em,
  // wallpaper 37em, list padding 1.2em 2em, rows 2.2em icons with 0.4em padding
  readonly property int em: 18
  readonly property int rows: 8
  readonly property int rowHeight: Math.round(2.2 * em + 0.8 * em)
  readonly property int rowSpacing: 1
  readonly property int fontSize: 13 // 10pt

  // unanchored, so the compositor centers it
  implicitWidth: 63 * em
  implicitHeight: 33 * em
  color: "transparent"
  WlrLayershell.namespace: "qs-launcher"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

  // what is typed in the search box
  property alias query: search.text

  function open(): void { visible = true; }
  function close(): void { visible = false; }
  function toggle(): void { visible = !visible; }

  onVisibleChanged: {
    if (visible) {
      search.text = "";
      list.currentIndex = 0;
      search.forceActiveFocus();
    }
  }

  // click outside closes
  HyprlandFocusGrab {
    windows: [launcher]
    active: launcher.visible
    onCleared: launcher.visible = false
  }

  // DesktopEntries fills in after startup, so keep this a binding
  readonly property var apps: DesktopEntries.applications.values
    .filter(a => !a.noDisplay)
    .sort((a, b) => a.name.localeCompare(b.name, undefined, { sensitivity: "base" }))

  // name prefix first, then name substring, then generic name / keywords / comment
  readonly property var matches: {
    const q = search.text.trim().toLowerCase();
    if (q === "") return apps;
    const rank = a => {
      const name = a.name.toLowerCase();
      if (name.startsWith(q)) return 0;
      if (name.includes(q)) return 1;
      const rest = [a.genericName, a.comment].concat(a.keywords).join(" ").toLowerCase();
      return rest.includes(q) ? 2 : -1;
    };
    return apps.map(a => ({ app: a, rank: rank(a) }))
      .filter(m => m.rank >= 0)
      .sort((x, y) => x.rank - y.rank)
      .map(m => m.app);
  }

  function launch(entry): void {
    if (!entry) return;
    if (entry.runInTerminal)
      Quickshell.execDetached(["ghostty", "-e"].concat(entry.command));
    else
      entry.execute();
    launcher.visible = false;
  }

  ClippingRectangle {
    anchors.fill: parent
    radius: 30
    // main-bg: surface at 70%; Hyprland blurs behind qs-* layers (hypr/rules.lua)
    color: Qt.alpha(Theme.colors.surface, 0.7)
    border.width: 2
    border.color: Qt.alpha(Theme.colors.primary, 0.9) // main-br
    focus: true
    Keys.onEscapePressed: launcher.visible = false

    // dummywall: the wallpaper scaled to the height, the left 37em of the window
    Image {
      id: wall
      anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
      width: 37 * launcher.em - 2
      source: Theme.colors.image
      sourceSize.height: launcher.implicitHeight
      fillMode: Image.PreserveAspectCrop
      horizontalAlignment: Image.AlignLeft // rofi draws it from the left edge
      asynchronous: true
    }

    // listbox: the rest, content centered vertically between the dummies
    Item {
      anchors { left: wall.right; right: parent.right; top: parent.top; bottom: parent.bottom }
      anchors.leftMargin: 0
      anchors.rightMargin: 2 * launcher.em - 2
      anchors.topMargin: 1.2 * launcher.em
      anchors.bottomMargin: 1.2 * launcher.em

      Column {
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
        anchors.leftMargin: 2 * launcher.em
        spacing: 0.8 * launcher.em

        // inputbar
        Rectangle {
          width: parent.width
          height: 35 // rofi: 0.6em padding around a 13px line
          radius: 20
          color: Qt.alpha(Theme.colors.surface_container, 0.9) // main-ex

          TextInput {
            id: search
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
            anchors.leftMargin: 1.2 * launcher.em
            anchors.rightMargin: 1.2 * launcher.em
            font.family: Theme.font
            font.pixelSize: launcher.fontSize
            color: Qt.alpha(Theme.colors.primary_fixed, 0.9) // main-fg
            selectionColor: Qt.alpha(Theme.colors.primary, 0.5)
            selectedTextColor: Theme.colors.on_primary
            clip: true
            onTextChanged: list.currentIndex = 0

            Keys.onUpPressed: list.decrementCurrentIndex()
            Keys.onDownPressed: list.incrementCurrentIndex()
            Keys.onReturnPressed: launcher.launch(launcher.matches[list.currentIndex])
            Keys.onEnterPressed: launcher.launch(launcher.matches[list.currentIndex])
            Keys.onEscapePressed: launcher.visible = false

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
          id: list
          width: parent.width
          height: launcher.rows * launcher.rowHeight + (launcher.rows - 1) * launcher.rowSpacing
          model: launcher.matches
          spacing: launcher.rowSpacing
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
            width: list.width
            height: launcher.rowHeight
            radius: 20
            color: selected ? Qt.alpha(Theme.colors.primary, 0.5) : "transparent" // select-bg

            IconImage {
              id: icon
              anchors { left: parent.left; verticalCenter: parent.verticalCenter }
              anchors.leftMargin: 1.5 * launcher.em
              implicitSize: 2.2 * launcher.em
              source: Quickshell.iconPath(row.modelData.icon, true)
              asynchronous: true
            }

            Text {
              anchors { left: icon.right; right: parent.right; verticalCenter: parent.verticalCenter }
              anchors.leftMargin: 0.8 * launcher.em
              anchors.rightMargin: 0.4 * launcher.em
              text: row.modelData.name
              font.family: Theme.font
              font.pixelSize: launcher.fontSize
              color: row.selected ? Qt.alpha(Theme.colors.on_primary, 0.9) : Qt.alpha(Theme.colors.primary_fixed, 0.9)
              elide: Text.ElideRight
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onEntered: list.currentIndex = row.index
              onClicked: launcher.launch(row.modelData)
            }
          }
        }
      }
    }
  }
}
