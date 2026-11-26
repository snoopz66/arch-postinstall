import QtQuick
import QtTest
import "../../config/keystroke/extensions/spellcheck/core/Spell.js" as Spell

TestCase {
    name: "Spell"
    property string banner: "@(#) International Ispell Version 3.2.06 (but really Hunspell 1.7.2)\n"

    function test_word_is_a_single_word_of_letters() {
        compare(Spell.word("recieve"), "recieve")
        compare(Spell.word("  naïve "), "naïve")
        compare(Spell.word("don't"), "don't")
        compare(Spell.word("two words"), "")
        compare(Spell.word("abc123"), "")
        compare(Spell.word("a"), "")
        compare(Spell.word("foo/bar"), "")
        compare(Spell.word(""), "")
    }

    function test_argv_passes_the_word_as_an_argument_never_as_script() {
        var argv = Spell.argv("$(id)")

        compare(argv[argv.length - 1], "$(id)")
        verify(argv[2].indexOf("id") < 0)
        verify(argv[2].indexOf("hunspell -a") > 0)
    }

    // The script prints the word, then hunspell's banner and verdict.
    function output(word, verdict) { return word + "\n" + banner + verdict + "\n\n" }

    function test_parse_knows_a_correct_word() {
        compare(Spell.parse(output("receive", "*")), { word: "receive", state: "known", suggestions: [] })
        compare(Spell.parse(output("receives", "+ RECEIVE")).state, "known")
        compare(Spell.parse(output("re-ceive", "-")).state, "known")
    }

    function test_parse_lists_the_corrections_of_a_misspelled_word() {
        var result = Spell.parse(output("recieve", "& recieve 3 0: receive, relieve, reprieve"))

        compare(result, { word: "recieve", state: "wrong", suggestions: ["receive", "relieve", "reprieve"] })
    }

    function test_parse_has_no_corrections_for_a_word_hunspell_cannot_place() {
        compare(Spell.parse(output("xqzvk", "# xqzvk 0")), { word: "xqzvk", state: "wrong", suggestions: [] })
    }

    function test_parse_has_no_verdict_when_hunspell_gave_none() {
        compare(Spell.parse("recieve\n"), { word: "recieve", state: "unchecked", suggestions: [] })
        compare(Spell.parse("recieve\nCan't open affix or dictionary files for dictionary named \"xx_XX\".\n").state, "unchecked")
    }

    function test_rows_offer_a_correct_word_for_copying() {
        var rows = Spell.rows({ word: "receive", state: "known", suggestions: [] }, "answer", 5)

        compare(rows.length, 1)
        compare(rows[0].title, "receive")
        compare(rows[0].subtitle, "Spelled correctly")
        compare(rows[0].tier, "answer")
        compare(rows[0].action, { type: "copy", text: "receive" })
    }

    function test_rows_offer_each_correction_up_to_the_limit() {
        var result = { word: "recieve", state: "wrong", suggestions: ["receive", "relieve", "reprieve"] }

        var rows = Spell.rows(result, "fallback", 2)

        compare(rows.map(function(r) { return r.title }), ["receive", "relieve"])
        compare(rows[0].subtitle, "Spelling of recieve")
        compare(rows[0].tier, "fallback")
        compare(rows[1].action, { type: "copy", text: "relieve" })
        verify(rows[0].score > rows[1].score)
    }

    function test_rows_say_so_when_there_is_nothing_to_suggest() {
        var rows = Spell.rows({ word: "xqzvk", state: "wrong", suggestions: [] }, "answer", 5)

        compare(rows.length, 1)
        compare(rows[0].disabled, true)
        compare(rows[0].title, "No spelling suggestions")
    }

    function test_rows_are_empty_without_a_verdict() {
        compare(Spell.rows({ word: "recieve", state: "unchecked", suggestions: [] }, "answer", 5), [])
    }
}
