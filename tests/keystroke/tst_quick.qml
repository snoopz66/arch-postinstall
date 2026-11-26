import QtQuick
import QtTest
import "../../config/keystroke/extensions/quick/core/Quick.js" as Quick
import "../../config/quickshell/keystroke/core/Match.js" as Match

TestCase {
    name: "Quick"

    function test_rows_are_wallpaper_screenshot_and_keybinds() {
        var rows = Quick.rows("key", "/home/me")

        compare(rows.map(function(r) { return r.title }), ["Wallpaper", "Screenshot", "Keybinds"])
    }

    // The first list already shows that screen as Hotkeys.
    function test_first_list_leaves_keybinds_to_the_hotkeys_row() {
        var rows = Quick.rows("", "/home/me")

        compare(rows.map(function(r) { return r.id }), ["wallpaper", "screenshot"])
    }

    function test_keybinds_opens_the_hotkeys_screen() {
        var row = Quick.rows("key", "/home/me")[2]

        compare(row.action, { type: "navigate", scope: "hotkeys", title: "Hotkeys" })
    }

    function test_wallpaper_opens_the_picker_of_the_running_shell() {
        var row = Quick.rows("", "/home/me")[0]

        compare(row.action, { type: "exec", argv: ["qs", "ipc", "call", "wallpapers", "open"] })
    }

    function test_screenshot_runs_the_script_on_a_region() {
        var row = Quick.rows("", "/home/me")[1]

        compare(row.action, { type: "exec", argv: ["/home/me/.local/bin/screenshot", "region"] })
    }

    // "Open" draws the chevron of a row that leads to another list or picker.
    function test_only_rows_that_lead_somewhere_say_open() {
        var rows = Quick.rows("key", "/home/me")

        compare(rows.map(function(r) { return r.verb }), ["Open", "Capture", "Open"])
    }

    // Applications is 30 on the launcher's first list, Clipboard History 26.
    function test_rows_sit_under_applications_on_the_first_list() {
        var rows = Quick.rows("", "/home/me")

        compare(rows.map(function(r) { return r.score }), [29, 28])
    }

    function test_rows_leave_the_score_to_the_launcher_once_something_is_typed() {
        var rows = Quick.rows("wall", "/home/me")

        compare(rows[0].score, undefined)
        verify(rows[0].keywords.indexOf("background") >= 0)
    }

    function test_searched_rows_rise_with_use() {
        compare(Quick.rows("wall", "/home/me")[0].remember, true)
    }

    // A remembered row would climb over Applications after one pick.
    function test_first_list_keeps_its_order() {
        compare(Quick.rows("", "/home/me")[0].remember, false)
    }

    // "shot" sits mid-word in the title, which alone scores as a weak fuzzy hit.
    function test_shot_finds_screenshot_as_a_word() {
        var row = Quick.rows("shot", "/home/me")[1]

        verify(Match.match("shot", row.title, row.keywords) > Match.match("shot", row.title, ""))
    }
}
