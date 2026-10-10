// Wallpaper picker: one row of square thumbnails (HyDE selector.rasi) of ~/Pictures/Wallpapers and the
// stock walls. Left/Right and Return or a click run `wallpaper` on the picture, Escape closes.
// Open with: qs ipc call wallpapers toggle
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets

PanelWindow {
  id: picker
  visible: false

  // same em as the launcher: 18px, text at 10pt. An 18em thumbnail with 0.8em of padding, 3em apart
  readonly property int em: 18
  readonly property int fontSize: 13
  readonly property int thumb: 18 * em
  readonly property int pad: 0.8 * em
  readonly property int cell: thumb + 2 * pad
  readonly property int gap: 3 * em

  // absolute paths
  property var images: []

  // as many columns as fit the focused monitor, with 5em between the row and the window's edge
  readonly property int columns: {
    const m = Hyprland.focusedMonitor;
    const room = (m ? m.width / m.scale : 1920) - 10 * em;
    return Math.max(1, Math.min(images.length, Math.floor((room + gap) / (cell + gap))));
  }

  // unanchored, so the compositor centers it
  implicitWidth: columns * cell + (columns - 1) * gap + 10 * em
  implicitHeight: strip.height + 6 * em
  color: "transparent"
  WlrLayershell.namespace: "qs-wallpapers"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

  // shows once the pictures are listed, so the window opens at its final size
  function open(): void { lister.running = true; }
  function close(): void { visible = false; }
  function toggle(): void {
    if (visible) close();
    else open();
  }

  function present(paths: var): void {
    // an unchanged list keeps its delegates, and with them the decoded thumbnails
    if (JSON.stringify(paths) !== JSON.stringify(images)) images = paths;
    strip.currentIndex = Math.max(0, images.indexOf(Theme.colors.image));
    strip.positionViewAtIndex(strip.currentIndex, ListView.Contain);
    visible = true;
    strip.forceActiveFocus();
  }

  function apply(path: string): void {
    if (path) Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/wallpaper", path]);
    visible = false;
  }

  Process {
    id: lister
    command: ["sh", "-c", "find \"$HOME/Pictures/Wallpapers\" /usr/share/hypr -maxdepth 1 -type f"
      + " \\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \\)"
      + " ! -name 'lockdead*' 2>/dev/null | sort"]
    stdout: StdioCollector {
      onStreamFinished: picker.present(text.split("\n").filter(p => p !== ""))
    }
  }

  // click outside closes
  HyprlandFocusGrab {
    windows: [picker]
    active: picker.visible
    onCleared: picker.visible = false
  }

  Rectangle {
    anchors.fill: parent
    radius: 30
    // main-bg: surface at 70%; Hyprland blurs behind qs-* layers (hypr/rules.lua)
    color: Qt.alpha(Theme.colors.surface, 0.7)
    border.width: 2
    border.color: Qt.alpha(Theme.colors.primary, 0.9) // main-br

    ListView {
      id: strip
      anchors.centerIn: parent
      width: picker.columns * picker.cell + (picker.columns - 1) * picker.gap
      // padding, thumbnail, 0.6em, one line of text, padding
      height: 2 * picker.pad + picker.thumb + 0.6 * picker.em + picker.em
      orientation: ListView.Horizontal
      model: picker.images
      spacing: picker.gap
      clip: true
      keyNavigationWraps: true // cycle
      boundsBehavior: Flickable.StopAtBounds
      highlightMoveDuration: 0
      // every picture stays instantiated: decoding them again on each open is the slow part
      cacheBuffer: 1000000

      Keys.onLeftPressed: decrementCurrentIndex()
      Keys.onRightPressed: incrementCurrentIndex()
      Keys.onReturnPressed: picker.apply(picker.images[currentIndex])
      Keys.onEnterPressed: picker.apply(picker.images[currentIndex])
      Keys.onEscapePressed: picker.visible = false

      // element
      delegate: Rectangle {
        id: tile
        required property string modelData
        required property int index
        readonly property bool selected: ListView.isCurrentItem
        width: picker.cell
        height: strip.height
        radius: 20
        color: selected ? Qt.alpha(Theme.colors.primary, 0.5) : "transparent" // select-bg

        ClippingRectangle {
          id: frame
          anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
          anchors.topMargin: picker.pad
          width: picker.thumb
          height: picker.thumb
          radius: 20
          color: "transparent"

          Image {
            anchors.fill: parent
            source: "file://" + tile.modelData
            // decoded at thumbnail height, then cropped square
            sourceSize.height: picker.thumb
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
          }
        }

        Text {
          anchors { top: frame.bottom; left: parent.left; right: parent.right }
          anchors.topMargin: 0.6 * picker.em
          anchors.leftMargin: picker.pad
          anchors.rightMargin: picker.pad
          // file name without directory and extension
          text: tile.modelData.replace(/^.*\//, "").replace(/\.[^.]*$/, "")
          font.family: Theme.font
          font.pixelSize: picker.fontSize
          color: tile.selected ? Qt.alpha(Theme.colors.on_primary, 0.9) : Qt.alpha(Theme.colors.primary_fixed, 0.9)
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideRight
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onEntered: strip.currentIndex = tile.index
          onClicked: picker.apply(tile.modelData)
        }
      }
    }
  }
}
