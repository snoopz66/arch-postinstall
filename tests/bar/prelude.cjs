// What upstream's test blocks expect around them: assertions that print TAP lines,
// and files resolved from the shell's directory (config/quickshell).
const path = require('node:path')
const root = process.env.SHELL_DIR || path.join(__dirname, '..', '..', 'config', 'quickshell')

function fail(description, detail) {
  if (detail) console.error(detail)
  console.error(`not ok - ${description}`)
  process.exit(1)
}

function assert(condition, description, detail) {
  if (!condition) fail(description, detail)
}

function assertEqual(actual, expected, description) {
  assert(actual === expected, description, `expected: ${expected}\nactual:   ${actual}`)
}

function assertDeepEqual(actual, expected, description) {
  const actualJson = JSON.stringify(actual)
  const expectedJson = JSON.stringify(expected)
  assert(actualJson === expectedJson, description, `expected: ${expectedJson}\nactual:   ${actualJson}`)
}

function requireFromRoot(relativePath) {
  return require(path.join(root, relativePath))
}

module.exports = { root, fail, pass() {}, assert, assertEqual, assertDeepEqual, requireFromRoot }
