import QtQuick
import QtTest
import "../../config/quickshell/keystroke/core/Cliphist.js" as Cliphist

TestCase {
    name: "Cliphist"
    // As `cliphist list` prints them: id, a tab, the preview.
    property string list:
        "12\thello world\n" +
        "11\t[[ binary data 144 KiB png 1280x720 ]]\n" +
        "\n" +
        "10\tcolumn a\tcolumn b\n" +
        "9\t   \n" +
        "no tab here\n"

    function test_parse_reads_text_entries_newest_first() {
        var entries = Cliphist.parse(list)

        compare(entries.length, 3)
        compare(entries[0], { line: "12\thello world", text: "hello world", image: false })
    }

    function test_parse_names_an_image_by_its_size_and_type() {
        var image = Cliphist.parse(list)[1]

        compare(image.image, true)
        compare(image.text, "Image · 144 KiB png 1280x720")
        compare(image.line, "11\t[[ binary data 144 KiB png 1280x720 ]]")
    }

    function test_parse_keeps_a_tab_inside_the_preview() {
        compare(Cliphist.parse(list)[2].text, "column a\tcolumn b")
    }

    function test_parse_returns_nothing_for_no_history() {
        compare(Cliphist.parse("").length, 0)
    }

    function test_copy_passes_the_line_as_an_argument_never_as_script() {
        var argv = Cliphist.copyArgv("7\t$(rm -rf ~); `id`")

        compare(argv.length, 5)
        compare(argv[4], "7\t$(rm -rf ~); `id`")
        verify(argv[2].indexOf("rm") < 0)
        verify(argv[2].indexOf("cliphist decode") > 0)
    }
}
