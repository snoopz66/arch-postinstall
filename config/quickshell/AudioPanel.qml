// Audio popup: output and input volume, device pickers, live peak meters.
// Pipewire API: https://quickshell.org/docs/types/Quickshell.Services.Pipewire/
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire

PanelWindow {
  id: panel
  visible: false

  // below the bar's exclusive zone, at the right where the audio pill is
  anchors { top: true; right: true }
  margins { top: 6; right: 16 }
  implicitWidth: 440
  implicitHeight: content.implicitHeight + 2 * Theme.padding
  color: "transparent"
  WlrLayershell.namespace: "qs-audio"
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var source: Pipewire.defaultAudioSource
  readonly property var sinks: Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream)
  readonly property var sources: Pipewire.nodes.values.filter(n => n.audio && !n.isSink && !n.isStream)

  // volume and mute are only readable on bound nodes
  PwObjectTracker { objects: [panel.sink, panel.source].filter(n => n !== null) }
  PeakMonitor { id: sinkPeak; node: panel.sink }
  PeakMonitor { id: sourcePeak; node: panel.source }

  // click outside closes
  HyprlandFocusGrab {
    windows: [panel]
    active: panel.visible
    onCleared: panel.visible = false
  }

  Rectangle {
    anchors.fill: parent
    radius: Theme.radius
    // same 80% surface as the waybar pills; Hyprland blurs behind qs-* layers (hypr/rules.lua)
    color: Qt.alpha(Theme.colors.surface, 0.8)
    border.width: 2
    border.color: Theme.colors.tertiary
    focus: true
    Keys.onEscapePressed: panel.visible = false

    ColumnLayout {
      id: content
      anchors { fill: parent; margins: Theme.padding }
      spacing: 14

      Section {
        Layout.fillWidth: true
        title: "Output"
        node: panel.sink
        nodes: panel.sinks
        peak: sinkPeak
        iconOn: "󰕾"
        iconOff: "󰝟"
        onPicked: n => Pipewire.preferredDefaultAudioSink = n
      }

      Rectangle { Layout.fillWidth: true; height: 1; color: Theme.colors.outline_variant }

      Section {
        Layout.fillWidth: true
        title: "Input"
        node: panel.source
        nodes: panel.sources
        peak: sourcePeak
        iconOn: "󰍬"
        iconOff: "󰍭"
        onPicked: n => Pipewire.preferredDefaultAudioSource = n
      }
    }
  }

  // one direction: mute + volume slider, peak meter, device list
  component Section: ColumnLayout {
    id: section
    required property string title
    required property var node
    required property var nodes
    required property PeakMonitor peak
    readonly property var peaks: peak.unsupported ? [0, 0] : peak.peaks
    required property string iconOn
    required property string iconOff
    signal picked(var node)

    readonly property bool ready: node !== null && node.audio !== null
    readonly property bool muted: ready && node.audio.muted
    readonly property real volume: ready ? node.audio.volume : 0
    spacing: 8

    Label { text: section.title; color: Theme.colors.on_surface_variant; font.pixelSize: Theme.fontSize - 2 }

    RowLayout {
      spacing: 12

      // mute toggle
      Rectangle {
        width: 36; height: 36; radius: 10
        color: section.muted ? Theme.colors.error : Theme.colors.surface_container_high
        Label {
          anchors.centerIn: parent
          text: section.muted ? section.iconOff : section.iconOn
          color: section.muted ? Theme.colors.surface : Theme.colors.on_surface
          font.pixelSize: Theme.fontSize + 4
        }
        MouseArea {
          anchors.fill: parent
          enabled: section.ready
          onClicked: section.node.audio.muted = !section.node.audio.muted
        }
      }

      // volume slider, scroll anywhere on it
      Item {
        id: slider
        Layout.fillWidth: true
        height: 36
        readonly property real value: Math.min(section.volume, 1)

        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width; height: 8; radius: 4
          color: Theme.colors.surface_container_high
          Rectangle {
            width: parent.width * slider.value; height: parent.height; radius: 4
            color: section.muted ? Theme.colors.outline : Theme.colors.tertiary
          }
        }
        Rectangle {
          x: (slider.width - width) * slider.value
          anchors.verticalCenter: parent.verticalCenter
          width: 18; height: 18; radius: 9
          color: Theme.colors.tertiary_fixed
          border.width: 2; border.color: Theme.colors.surface
        }
        MouseArea {
          anchors.fill: parent
          enabled: section.ready
          function set(x) { section.node.audio.volume = Math.max(0, Math.min(1, x / slider.width)); }
          onPressed: mouse => set(mouse.x)
          onPositionChanged: mouse => { if (pressed) set(mouse.x); }
          onWheel: wheel => {
            section.node.audio.volume = Math.max(0, Math.min(1, section.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05)));
          }
        }
      }

      Label {
        text: Math.round(section.volume * 100) + "%"
        color: Theme.colors.on_surface
        font.pixelSize: Theme.fontSize
        Layout.preferredWidth: 44
        horizontalAlignment: Text.AlignRight
      }
    }

    // peak meter: one bar per channel, filled from the left, quiet to loud
    ColumnLayout {
      Layout.fillWidth: true
      spacing: 3
      Repeater {
        model: section.peaks.length
        Rectangle {
          required property int index
          Layout.fillWidth: true
          height: 6; radius: 3
          color: Theme.colors.surface_container_high
          opacity: section.peak.unsupported ? 0.35 : 1
          Item {
            width: parent.width * Math.min(section.peaks[index], 1)
            height: parent.height
            clip: true
            Behavior on width { NumberAnimation { duration: 50 } }
            Rectangle {
              width: parent.parent.width; height: parent.height; radius: 3
              gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Theme.colors.primary }
                GradientStop { position: 0.7; color: Theme.colors.tertiary }
                GradientStop { position: 1.0; color: Theme.colors.error }
              }
            }
          }
        }
      }
    }

    // device list, the current default highlighted
    Repeater {
      model: section.nodes
      Rectangle {
        required property var modelData
        readonly property bool current: section.node !== null && modelData.id === section.node.id
        Layout.fillWidth: true
        height: 32; radius: 8
        color: current ? Theme.colors.tertiary : (hover.hovered ? Theme.colors.surface_container_high : "transparent")
        HoverHandler { id: hover }
        Label {
          anchors { left: parent.left; right: parent.right; margins: 10; verticalCenter: parent.verticalCenter }
          text: (current ? "󰄬  " : "    ") + (modelData.description || modelData.nickname || modelData.name)
          color: current ? Theme.colors.on_tertiary : Theme.colors.on_surface
          font.pixelSize: Theme.fontSize
          elide: Text.ElideRight
        }
        MouseArea { anchors.fill: parent; onClicked: section.picked(modelData) }
      }
    }
  }

  // Quickshell's capture stream comes up with FL/FR positions; a node whose channels are named differently
  // (Pro Audio profiles: AUX0/AUX1) cannot be mapped and the monitor logs an error per buffer, so stop it
  // and let the meter show as unavailable. A WirePlumber rule naming the channels FL/FR fixes it for good.
  component PeakMonitor: PwNodePeakMonitor {
    id: monitor
    property bool unsupported: false
    enabled: panel.visible && !unsupported
    onNodeChanged: unsupported = false
    onChannelsChanged: {
      if (!node || !node.audio || channels.length === 0 || node.audio.channels.length === 0) return;
      const nodeChannels = node.audio.channels;
      if (channels.some(c => nodeChannels.indexOf(c) < 0)) unsupported = true;
    }
  }

  component Label: Text {
    font.family: Theme.font
    font.pixelSize: Theme.fontSize
    color: Theme.colors.on_surface
    verticalAlignment: Text.AlignVCenter
  }
}
