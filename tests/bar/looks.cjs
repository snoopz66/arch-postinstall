// The bar's background looks, and the one the default layout asks for.
const { root, assert, assertEqual, assertDeepEqual } = require('./prelude.cjs')
const fs = require('fs')
const path = require('node:path')
const source = fs.readFileSync(root + '/bar/Bar.qml', 'utf8')

// Double-clicking the bar steps through every look and back to the first.
const cycle = new Function('root', 'Util', 'requestedTransparent', 'glassy', 'pills',
  source.match(/function cycleBackground\(\) \{[^]*?\n  \}/)[0] + '\ncycleBackground()')

function next(look) {
  const config = { bar: {} }
  const shell = { mutateShellConfig: mutator => mutator(config) }
  cycle({ shell }, { isPlainObject: value => typeof value === 'object' }, look === 'none', look === 'glassy', look === 'pills')
  return config.bar.background
}

const seen = ['none']
while (seen.length < 5) seen.push(next(seen[seen.length - 1]))
assertDeepEqual(seen, ['none', 'glassy', 'opaque', 'pills', 'none'], 'the looks cycle through pills and around')

// A look the bar does not know draws as opaque and says nothing.
const looks = JSON.parse(source.match(/var looks = (\[[^\]]*\])/)[1])
const layout = JSON.parse(fs.readFileSync(path.join(root, '..', 'bar', 'bar.json'), 'utf8'))
assert(looks.includes(layout.background), 'the default layout asks for a look the bar has (' + layout.background + ')')
assert(/pills = look === "pills"/.test(source), 'the layout file can ask for pills')

// Behind the pills the bar is frosted: it paints a trace, and Hyprland blurs
// behind whatever a layer paints above the rule's ignore_alpha.
const strip = new Function('root', 'return ' + source.match(/color: (root\.transparent \? .*)/)[1])
const colors = { frostBackground: 'frost', glassBackground: 'glass', background: 'solid' }
assertEqual(strip({ ...colors, pills: true }), 'frost', 'behind the pills the bar is frosted')
assertEqual(strip({ ...colors, transparent: true }), 'transparent', 'a clear bar paints nothing')

const frost = Number(source.match(/frostBackground: Qt\.rgba\(.*, ([\d.]+)\)/)[1])
const rules = fs.readFileSync(path.join(root, '..', 'hypr', 'rules.lua'), 'utf8')
const ignored = Number(rules.match(/ignore_alpha = ([\d.]+)/)[1])
assert(Math.round(frost * 255) > Math.round(ignored * 255), 'the frost is more than Hyprland ignores')

// A size the kit does not read is dropped without a word.
const style = fs.readFileSync(root + '/Commons/Style.qml', 'utf8')
const sizes = [...fs.readFileSync(root + '/shell.toml', 'utf8').matchAll(/^([a-z-]+) *= *\d+$/gm)].map(match => match[1])
assert(sizes.includes('size-horizontal') && sizes.includes('base-size'), 'shell.toml sets the bar\'s height and the text size')
for (const key of sizes) assert(style.includes('"' + key + '"'), 'the kit reads the size ' + key)
