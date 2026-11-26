import QtQuick
import QtTest
import "../../config/quickshell/BarHost.js" as Host

TestCase {
    name: "BarHost"

    function layoutOf(section, entries) {
        var layout = {}
        layout[section] = entries
        return { position: "top", layout: layout }
    }

    function test_layout_names_gain_the_prefix_the_bar_code_uses() {
        var bar = Host.renamed(layoutOf("left", [{ id: "workspaces" }, { id: "clock", format: "HH:mm" }]), Host.fullId)

        compare(bar.layout.left, [{ id: "omarchy.workspaces" }, { id: "omarchy.clock", format: "HH:mm" }])
    }

    function test_a_bare_string_entry_becomes_an_entry_object() {
        var bar = Host.renamed(layoutOf("right", ["tray"]), Host.fullId)

        compare(bar.layout.right, [{ id: "omarchy.tray" }])
    }

    function test_custom_modules_keep_their_own_id() {
        var entry = { id: "vpn", type: "command", exec: "vpn-status" }

        var bar = Host.renamed(layoutOf("right", [entry]), Host.fullId)

        compare(bar.layout.right, [entry])
    }

    function test_saving_drops_the_prefix_again() {
        var loaded = Host.renamed(layoutOf("tray", [{ id: "audio" }]), Host.fullId)

        var saved = Host.renamed(loaded, Host.shortId)

        compare(saved.layout.tray, [{ id: "audio" }])
    }

    function test_renaming_leaves_the_original_alone() {
        var original = layoutOf("left", [{ id: "workspaces" }])

        Host.renamed(original, Host.fullId)

        compare(original.layout.left, [{ id: "workspaces" }])
    }

    function test_parse_reads_a_layout_file() {
        var bar = Host.parse('{ "position": "bottom", "layout": { "left": [{ "id": "tray" }] } }')

        compare(bar.position, "bottom")
        compare(bar.layout.left, [{ id: "omarchy.tray" }])
    }

    function test_parse_refuses_a_broken_file() {
        compare(Host.parse("{ not json"), null)
        compare(Host.parse("[]"), null)
        compare(Host.parse(""), null)
    }

    function test_serialize_writes_what_parse_reads() {
        var text = '{\n  "position": "top",\n  "layout": {\n    "left": [\n      {\n        "id": "tray"\n      }\n    ]\n  }\n}\n'

        compare(Host.serialize(Host.parse(text)), text)
    }

    function test_an_entry_takes_new_settings_and_keeps_its_place() {
        var bar = layoutOf("center", [{ id: "omarchy.spacer" }, { id: "omarchy.clock", format: "HH:mm" }])

        var next = Host.withEntry(bar, "omarchy.clock", { format: "HH:mm:ss", weekStartDay: "monday" })

        compare(next.layout.center, [{ id: "omarchy.spacer" }, { id: "omarchy.clock", format: "HH:mm:ss", weekStartDay: "monday" }])
    }

    function test_unchanged_settings_report_nothing_to_write() {
        var bar = layoutOf("center", [{ id: "omarchy.clock", format: "HH:mm" }])

        compare(Host.withEntry(bar, "omarchy.clock", { id: "omarchy.clock", format: "HH:mm" }), null)
    }

    function test_an_entry_not_on_the_bar_reports_nothing_to_write() {
        var bar = layoutOf("center", [{ id: "omarchy.clock" }])

        compare(Host.withEntry(bar, "omarchy.tray", { pinned: ["a"] }), null)
    }
}
