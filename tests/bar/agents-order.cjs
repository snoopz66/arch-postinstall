// From Omarchy's test/shell.d/agents-panel-test.sh.
const { root, fail, pass, assert, assertEqual, assertDeepEqual, requireFromRoot } = require('./prelude.cjs')
const path = require('node:path')

const fs = require('fs')
const source = fs.readFileSync(root + '/panels/agents/Main.qml', 'utf8')
const functions = ['accountLines', 'lineId', 'orderedProviders', 'moveProvider'].map(name => source.match(new RegExp('function ' + name + '\\([^]*?\\n  \\}'))[0]).join('\n')
let providerOrder = ['codex', 'kimi', 'claude', 'hidden']
let panelProviders = [{providerId: 'claude'}, {providerId: 'codex'}, {providerId: 'kimi'}, {providerId: 'grok'}]
let saved = ''
const orderFile = {setText: text => { saved = text }}
eval(functions)
const split = accountLines([{
  providerId: 'claude', accountName: 'main@example.com',
  accounts: [{id: 'main', email: 'main@example.com', plan: 'Max 20x'}, {id: 'side', email: '', plan: 'Pro'}]
}])
assertDeepEqual(split.map(p => p.accountName), ['main@example.com', ''], 'each split account line carries only its own email')
panelProviders = orderedProviders(panelProviders)
assertDeepEqual(panelProviders.map(p => p.providerId), ['codex', 'kimi', 'claude', 'grok'], 'saved order keeps its agents in place and puts new ones last')
moveProvider('grok', 0)
assertDeepEqual(JSON.parse(saved), ['grok', 'codex', 'kimi', 'claude', 'hidden'], 'moving an agent saves the order and retains hidden ids')


// Each account is a line of its own: its lines take the place saved for the
// agent until one is moved, and then that line moves alone.
providerOrder = ['codex', 'claude']
panelProviders = orderedProviders([{providerId: 'claude', lineId: 'claude/main'}, {providerId: 'claude', lineId: 'claude/work'}, {providerId: 'codex'}])
assertDeepEqual(panelProviders.map(lineId), ['codex', 'claude/main', 'claude/work'], 'account lines keep the place saved for their agent')
moveProvider('claude/work', 0)
assertDeepEqual(JSON.parse(saved).slice(0, 3), ['claude/work', 'codex', 'claude/main'], 'an account line moves on its own')
