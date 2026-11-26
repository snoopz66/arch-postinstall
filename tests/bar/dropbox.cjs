// The Dropbox panel's model, and the two places it leaves Omarchy's tree: the status
// helper it runs and the file manager it opens a file in.
const { root, assert, assertEqual, assertDeepEqual, requireFromRoot } = require('./prelude.cjs')
const fs = require('fs')

const dropbox = requireFromRoot('panels/dropbox/Model.js')

assertEqual(dropbox.parseStatus('').statusText, 'Unavailable', 'no output reads as unavailable')
assertEqual(dropbox.parseStatus('{').ok, false, 'output that is not JSON is a failure')
assertDeepEqual(dropbox.parseStatus('{"ok":true,"files":null}').files, [], 'a status without files has none')

assert(dropbox.isSyncing('Syncing 12 files • 3 mins'), 'a sync in progress reads as syncing')
assert(!dropbox.isSyncing('Up to date'), 'an idle daemon does not')

assertDeepEqual(
  dropbox.syncDetails('Syncing 12 files • 3 mins\nDownloading 12 files (1,500.0 KB/sec, 3 mins)'),
  { label: 'Downloading 12 files', detail: '1.5 MB/s · 3 mins', remaining: 12 },
  'a download names its files, speed and time left'
)
assertEqual(dropbox.syncDetails('Syncing…').label, 'Syncing…', 'a sync without a count is just syncing')

assertEqual(dropbox.formatBytes(0), '0 B', 'nothing stored is 0 B')
assertEqual(dropbox.formatBytes(1500), '1.5 KB', 'bytes are counted in thousands')
assertEqual(dropbox.formatBytes(284768745348), '285 GB', 'large sizes lose their decimals')
assertEqual(dropbox.usageText(1500, 2000000000, true), '1.5 KB of 2 GB', 'usage names the quota when it is known')
assertEqual(dropbox.usageText(1500, 0, false), '1.5 KB', 'and only what is stored when it is not')

const now = Date.UTC(2026, 0, 2)
assertEqual(dropbox.relativeTime(now / 1000 - 30, now), 'Just now', 'a file changed seconds ago is new')
assertEqual(dropbox.relativeTime(now / 1000 - 7200, now), '2h ago', 'hours are counted')
assertEqual(dropbox.relativeTime(0, now), 'Unknown time', 'a file without a time says so')
assertEqual(dropbox.fileMeta({ modifiedTs: now / 1000 - 7200, folder: 'Photos' }, now), '2h ago · Photos', 'a row names when and where')

assertEqual(dropbox.fileKind('holiday.JPG'), 'image', 'images are told by extension, whatever its case')
assertEqual(dropbox.fileKind('notes'), 'misc', 'a file without an extension is nothing in particular')

// The seams.
const service = fs.readFileSync(root + '/panels/dropbox/Service.qml', 'utf8')
const panel = fs.readFileSync(root + '/panels/dropbox/Panel.qml', 'utf8')

const helper = service.match(/readonly property string helperPath: (.*)/)
assertEqual(helper && helper[1], 'Quickshell.shellDir + "/panels/dropbox/status.py"', 'the status helper is the one beside the panel')
assert(fs.existsSync(root + '/panels/dropbox/status.py'), 'which exists')
assert(service.includes('Quickshell.execDetached(["nautilus", "--select", String(file.path)])'), 'a file opens selected in Files')
assert(panel.includes('ipcTarget: "dropbox"'), 'the panel answers to its own name')
