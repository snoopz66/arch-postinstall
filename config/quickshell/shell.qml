// Quickshell widgets, popups next to waybar. Docs: https://quickshell.org/docs/
// Toggle from waybar or a keybind: qs ipc call audio toggle
import Quickshell
import Quickshell.Io

ShellRoot {
  AudioPanel { id: audio }

  IpcHandler {
    target: "audio"
    function toggle(): void { audio.visible = !audio.visible; }
    // not "show"/"hide": those are subcommands of `qs ipc` and the CLI eats them
    function open(): void { audio.visible = true; }
    function close(): void { audio.visible = false; }
  }
}
