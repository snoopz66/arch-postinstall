// The shell: bar and its panels, launcher, menus, notifications. Docs: https://quickshell.org/docs/
// Toggle from a keybind: qs ipc call launcher toggle, wallpapers toggle, menu toggle windows|clipboard,
// bar toggle, audio|network|bluetooth|clock|tailscale toggle, notifications showHistory|toggleDnd|...
import Quickshell
import Quickshell.Io
import qs.keystroke as Keystroke
import qs.notifications as Notifications

ShellRoot {
  BarHost { notifications: notifications }
  Keystroke.Keystroke { id: launcher }
  Menu { id: menu }
  WallpaperPicker { id: wallpapers }

  // the notification daemon
  Notifications.Service { id: notifications }

  IpcHandler {
    target: "launcher"
    function toggle(): void { launcher.opened ? launcher.close() : launcher.open("{}"); }
    function open(): void { launcher.open("{}"); }
    function close(): void { launcher.close(); }
  }

  IpcHandler {
    target: "menu"
    function toggle(list: string): void { menu.toggle(list); }
    function open(list: string): void { menu.open(list); }
    function close(): void { menu.close(); }
  }

  IpcHandler {
    target: "wallpapers"
    function toggle(): void { wallpapers.toggle(); }
    function open(): void { wallpapers.open(); }
    function close(): void { wallpapers.close(); }
  }
}
