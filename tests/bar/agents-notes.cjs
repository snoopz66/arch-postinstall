// From Omarchy's test/shell.d/agents-panel-test.sh, for a panel that signs nobody in.
const { root, assert, assertEqual } = require('./prelude.cjs')
const fs = require('fs')
const panelSource = fs.readFileSync(root + '/panels/agents/Panel.qml', 'utf8')

const signInFunctions = ['supportsSignIn', 'signedOut', 'needsSignIn', 'usageNote'].map(name => {
  const match = panelSource.match(new RegExp('function ' + name + '\\([^]*?\\n  \\}'))
  return match ? match[0] : ''
}).join('\n')
const signIn = new Function('helpDisplayText', 'statusDisplayText', signInFunctions + '\nreturn {needsSignIn, signedOut, usageNote}')(
  text => text, status => status
)
// Signing in is each CLI's own here, so a lapsed sign-in is a note, never a link.
for (const id of ['claude', 'codex', 'agy']) {
  for (const status of ['Sign-in expired', 'Waiting for auth']) {
    assert(!signIn.needsSignIn({providerId: id, usageStatusText: status}), id + ' gets no sign-in link for ' + status)
    assert(signIn.signedOut({providerId: id, usageStatusText: status}), id + ' still counts as signed out for ' + status)
    assertEqual(signIn.usageNote({providerId: id, usageStatusText: status}), status, id + ' still notes ' + status)
  }
}
assertEqual(signIn.usageNote({providerId: 'codex', usageStatusText: 'Waiting for auth', authHelpText: 'Run `codex login` to authenticate.'}),
  'Run `codex login` to authenticate.', 'a missing sign-in says how to sign in')
assertEqual(signIn.usageNote({providerId: 'claude', usageStatusText: 'Limits paused', authHelpText: 'Start Claude Code to refresh it.'}),
  'Start Claude Code to refresh it.', 'paused limits stay on show with a note saying how to refresh them')
assertEqual(signIn.usageNote({providerId: 'claude', usageStatusText: ''}), '', 'current limits carry no note')
assertEqual(signIn.usageNote({providerId: 'claude', usageStatusText: '', limitsStale: true, authHelpText: "Couldn't reach the usage endpoint."}),
  "Couldn't reach the usage endpoint.", 'a failed refresh that kept its limits still says why')

// Local history alone feeds the summary; a section needs a subscription to show.
const mainSource = fs.readFileSync(root + '/panels/agents/Main.qml', 'utf8')
const subscribed = new Function(mainSource.match(/function providerHasSubscription\([^]*?\n  \}/)[0] + '\nreturn providerHasSubscription')()
const historyOnly = { limits: [], accounts: [], balance: null, tierLabel: '', totalPrompts: 1 }
assertEqual(subscribed(historyOnly), false, 'an agent with only local history gets no section')
assertEqual(subscribed({ ...historyOnly, tierLabel: 'X Premium+' }), true, 'a plan earns a section before its limits arrive')
assertEqual(subscribed({ ...historyOnly, limits: [{ label: 'Weekly', percent: 0.04 }] }), true, 'kept limits earn a section')
assertEqual(subscribed({ ...historyOnly, spend: { amount: 1.25, days: [] } }), true, 'spend alone earns a section')

// A reworded collector line would silently fall back to English, so every
// fixed help line the collectors cache must still be one the panel maps.
for (const name of ['claude', 'codex']) {
  const collector = fs.readFileSync(root + '/../../bin/bar-agent-usage-' + name, 'utf8')
  const help = collector.match(/^AUTH_HELP = "([^"]+)"$/m)
  assert(help && panelSource.includes('case ' + JSON.stringify(help[1]) + ':'), name + ' auth help is translated in the panel')
}
