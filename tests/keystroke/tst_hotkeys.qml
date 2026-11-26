import QtQuick
import QtTest
import "../../config/quickshell/keystroke/core/Hotkeys.js" as Hotkeys

TestCase {
    name: "Hotkeys"
    property var settings: ({ limit: 10, keyboardOnly: true })

    function bind(modmask, key, description, kind, mouse) {
        return { modmask: modmask, key: key, has_description: description !== "", description: description,
                 mouse: mouse === true, dispatcher: "HL.Dispatcher(" + kind + ")", arg: "6" }
    }
    // As `hyprctl binds -j` prints them: SHIFT 1, CTRL 4, ALT 8, SUPER 64.
    property string json: JSON.stringify([
        bind(64, "K", "Keybindings", "exec_cmd"),
        bind(64, "RETURN", "Terminal", "exec_cmd"),
        bind(65, "RETURN", "Browser", "exec_cmd"),
        bind(64, "F", "Full screen", "fullscreen"),
        bind(72, "F", "Full width", "fullscreen"),
        bind(64, "mouse:272", "Move window", "drag", true),
        bind(65, "B", "Browser", "exec_cmd"),
        bind(0, "PRINT", "Screenshot", "exec_cmd"),
        bind(64, "mouse_down", "Next workspace", "focus"),
        bind(64, "X", "", "exec_cmd"),
        bind(77, "Q", "Say \"hi\" \\ bye", "toggle_special")
    ])

    function test_parse_reads_described_binds_and_merges_a_description_bound_twice() {
        var binds = Hotkeys.parse(json)

        compare(binds.map(function(b) { return b.id }),
                ["keybindings", "terminal", "browser", "full-screen", "full-width", "move-window", "screenshot", "next-workspace", "say-hi-bye"])
        compare(binds[3], { id: "full-screen", label: "Full screen", combos: ["SUPER + F"], dispatcher: "lua",
                            arg: "keybinds[\"Full screen\"]", kind: "fullscreen", order: 3 })
        compare(binds[2].combos, ["SUPER SHIFT + RETURN", "SUPER SHIFT + B"])
        compare(binds[4].combos, ["SUPER ALT + F"])
        compare(binds[6].combos, ["PRINT"])
        compare(binds[7].combos, ["SUPER + SCROLL DOWN"])
        compare(binds[8].combos, ["SUPER CTRL ALT SHIFT + Q"])
    }

    function test_parse_leaves_a_mouse_bind_unrunnable() {
        var move = Hotkeys.parse(json)[5]

        compare(move.combos, ["SUPER + LEFT MOUSE BUTTON"])
        compare(move.dispatcher, "")
        compare(move.arg, "")
    }

    function test_parse_quotes_the_description_as_a_lua_string() {
        var bind = Hotkeys.parse(json)[8]

        compare(bind.arg, "keybinds[\"Say \\\"hi\\\" \\\\ bye\"]")
    }

    function test_parse_returns_nothing_for_output_that_is_not_json() {
        compare(Hotkeys.parse("").length, 0)
        compare(Hotkeys.parse("Couldn't connect to socket").length, 0)
    }

    function test_keys_are_readable() {
        compare(Hotkeys.keys("SUPER + F"), "Super + F")
        compare(Hotkeys.keys("SUPER SHIFT + RETURN"), "Super + Shift + ↵")
        compare(Hotkeys.keys("SUPER SHIFT CTRL + SPACE"), "Super + Shift + Ctrl + Space")
        compare(Hotkeys.keys("CTRL ALT + DELETE"), "Ctrl + Alt + Del")
        compare(Hotkeys.keys("PRINT"), "Print")
        compare(Hotkeys.keys("SUPER + 1"), "Super + 1")
        compare(Hotkeys.keys("SUPER + F11"), "Super + F11")
        compare(Hotkeys.keys("SUPER + COMMA"), "Super + ,")
        compare(Hotkeys.keys("SUPER + LEFT"), "Super + ←")
        compare(Hotkeys.keys("XF86AudioRaiseVolume"), "Audio Raise Volume")
        compare(Hotkeys.keys("SUPER + LEFT MOUSE BUTTON"), "Super + Left click")
        compare(Hotkeys.keys("SUPER + SCROLL DOWN"), "Super + Scroll down")
        compare(Hotkeys.keys("SUPER + code:20"), "Super + code:20")
        compare(Hotkeys.keys(""), "")
    }

    function test_argv_is_literal() {
        compare(Hotkeys.loadArgv(), ["hyprctl", "binds", "-j"])
        compare(Hotkeys.dispatchArgv("keybinds[\"Full screen\"]"), ["hyprctl", "dispatch", "keybinds[\"Full screen\"]"])
    }

    function test_screen_lists_every_bind_in_config_order() {
        var binds = Hotkeys.parse(json)

        var rows = Hotkeys.rows("", binds, settings, true)

        compare(rows.length, binds.length)
        compare(rows[0].title, "Keybindings")
        compare(rows[0].accessory, "Super + K")
        compare(rows[0].subtitle, "Runs a command")
        compare(rows[0].section, "Hotkeys")
        compare(rows[0].action, { type: "hotkey", dispatcher: "lua", arg: "keybinds[\"Keybindings\"]" })
        compare(rows[0].remember, true)
        compare(rows[2].accessory, "Super + Shift + ↵  ·  Super + Shift + B")
        compare(rows[3].subtitle, "Hyprland fullscreen")
        compare(rows[8].subtitle, "Hyprland toggle special")
        compare(rows[3].previewDetail, "Super + F")
    }

    function test_screen_shows_a_mouse_bind_for_learning_only() {
        var binds = Hotkeys.parse(json)

        var row = Hotkeys.rows("", binds, settings, true)[5]

        compare(row.disabled, true)
        compare(row.remember, false)
        compare(row.subtitle, "Only with the mouse")
        compare(row.action, { type: "noop" })
        compare(row.accessory, "Super + Left click")
        compare(Hotkeys.rows("", binds, { limit: 10, keyboardOnly: false }, true).length, binds.length - 1)
    }

    function test_root_lists_nothing_without_a_query() {
        compare(Hotkeys.rows("", Hotkeys.parse(json), settings, false).length, 0)
    }

    function test_root_finds_binds_by_abbreviation_and_keys() {
        var binds = Hotkeys.parse(json)
        var titles = function(q, s) { return Hotkeys.rows(q, binds, s || settings, false).map(function(r) { return r.title }) }

        compare(titles("flcrn")[0], "Full screen")
        compare(titles("full screen")[0], "Full screen")
        // The keys spelled out pick the bind on exactly those keys over Full width on Super + Alt + F.
        compare(titles("super f")[0], "Full screen")
        compare(titles("super alt f")[0], "Full width")
        compare(titles("SUPER + ALT + F")[0], "Full width")
        compare(titles("zzzz").length, 0)
        compare(titles("browser")[0], "Browser")
        compare(titles("b", { limit: 1, keyboardOnly: true }).length, 1)
    }
}
