.pragma library

// The terminal Keystroke opens: the one hypr/binds.lua starts.
var TERMINAL = "ghostty"

function inDir(dir) { return [TERMINAL, "--working-directory=" + dir] }
function run(argv) { return [TERMINAL, "-e"].concat(argv) }
