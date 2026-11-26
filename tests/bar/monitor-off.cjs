// The display panel's Mirror goes through Omarchy's Hyprland toggles, which are not
// carried here. A Panel.qml brought in again from upstream must keep it off.
const { root, assert, assertEqual } = require('./prelude.cjs')
const source = require('fs').readFileSync(root + '/panels/monitor/Panel.qml', 'utf8')

const available = source.match(/readonly property bool mirrorAvailable: (.*)/)
const setMirror = source.match(/function setMirror\([^)]*\) \{([^]*?)\}/)

assertEqual(available && available[1], 'false', 'Mirror and Extend are never offered')
assertEqual(setMirror && setMirror[1].trim(), '', 'nothing is run to mirror a display')
assert(!/"omarchy-[a-z-]+"/.test(source), 'the panel runs no Omarchy command')
