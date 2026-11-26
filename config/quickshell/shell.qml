// Quickshell widgets, popups next to waybar. Docs: https://quickshell.org/docs/
// Toggle from waybar or a keybind: qs ipc call audio toggle, launcher toggle, wallpapers toggle,
// menu toggle windows|clipboard, notifications showHistory|toggleDnd|dismissAll|...
import Quickshell
import Quickshell.Io
import qs.keystroke as Keystroke
import qs.notifications as Notifications

ShellRoot {
  AudioPanel { id: audio }
  Keystroke.Keystroke { id: launcher }
  Menu { id: menu }
  WallpaperPicker { id: wallpapers }

  // the notification daemon; waybar's bell re-reads Do Not Disturb on signal 8
  Notifications.Service {
    onDoNotDisturbChanged: Quickshell.execDetached(["pkill", "-RTMIN+8", "waybar"])
  }

  IpcHandler {
    target: "audio"
    function toggle(): void { audio.visible = !audio.visible; }
    // not "show"/"hide": those are subcommands of `qs ipc` and the CLI eats them
    function open(): void { audio.visible = true; }
    function close(): void { audio.visible = false; }
  }

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
