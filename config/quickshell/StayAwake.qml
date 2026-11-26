import QtQuick
import Quickshell.Io

// Stay awake: while on, holds a systemd idle inhibitor, which hypridle honours.
// Stands in for Omarchy's idle service, whose API bar/indicators/StayAwake.qml calls.
Item {
  id: root

  property bool stayAwake: false

  // The indicator says whether idling is allowed, the opposite of staying awake.
  function setIdleEnabled(enabled) { stayAwake = !enabled }

  Process {
    running: root.stayAwake
    command: ["systemd-inhibit", "--what=idle", "--who=Bar", "--why=Stay awake", "sleep", "infinity"]
  }
}
