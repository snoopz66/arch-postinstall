// Quickshell widgets, popups next to waybar. Docs: https://quickshell.org/docs/
// Toggle from waybar or a keybind: qs ipc call audio toggle, launcher toggle, wallpapers toggle,
// menu toggle quick|windows|clipboard|keybinds
import Quickshell
import Quickshell.Io

ShellRoot {
  AudioPanel { id: audio }
  Launcher { id: launcher }
  Menu { id: menu; onWallpaperPicker: wallpapers.open() }
  WallpaperPicker { id: wallpapers }

  IpcHandler {
    target: "audio"
    function toggle(): void { audio.visible = !audio.visible; }
    // not "show"/"hide": those are subcommands of `qs ipc` and the CLI eats them
    function open(): void { audio.visible = true; }
    function close(): void { audio.visible = false; }
  }

  IpcHandler {
    target: "launcher"
    function toggle(): void { launcher.toggle(); }
    function open(): void { launcher.open(); }
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
