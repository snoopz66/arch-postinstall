// The parts of Omarchy's agents panel that run Omarchy's own commands are off here.
// A Panel.qml brought in again from upstream must keep them off.
const { root, assert, assertEqual, assertDeepEqual } = require('./prelude.cjs')
const source = require('fs').readFileSync(root + '/panels/agents/Panel.qml', 'utf8')

function property(name) {
  const match = source.match(new RegExp('readonly property \\w+ ' + name + ': (.*)'))
  return match ? match[1] : null
}

function body(name) {
  return source.match(new RegExp('function ' + name + '\\([^]*?\\n  \\}'))[0]
}

assertEqual(property('signOutProviders'), '[]', 'deleting a line signs nothing out')
assertEqual(property('blankSlate'), 'false', 'the panel never becomes the set-up picker')
assertEqual(property('addButtonShown'), 'false', 'there is no add or instructions button')
assertEqual(property('makes'), 'false', 'there are no starters or make icons')

const supportsSignIn = new Function(body('supportsSignIn') + '\nreturn supportsSignIn')()
assertEqual(supportsSignIn({ providerId: 'claude' }), false, 'no agent is signed in from the panel')

const defaultIdFor = new Function(body('defaultIdFor') + '\nreturn defaultIdFor')()
assertEqual(defaultIdFor({ providerId: 'claude' }), '', 'no line can be made the default')

// What a line's terminal button runs: the agent's own CLI in the terminal.
const ran = []
const runLine = new Function('harnessFor', 'Util', 'Quickshell', 'root', body('runLine') + '\nreturn runLine')(
  line => ({ claude: 'claude' })[line.providerId] || '',
  { execArgv: argv => ran.push(argv) },
  { env: name => (name === 'TERMINAL' ? 'footerm' : '') },
  { close() {} }
)
runLine({ providerId: 'claude' })
runLine({ providerId: 'unknown' })
assertDeepEqual(ran, [['footerm', '-e', 'claude']], 'a terminal button starts the CLI in $TERMINAL, and only for an agent with one')

assert(!/checkProcess\.running = true\n\s+nowMs/.test(source), 'opening the panel does not ask Omarchy which agents are signed in')
assert(!source.includes('root.launchAgent()'), 'the bar icon does not start an Omarchy agent')
