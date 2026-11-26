.pragma library

// The clipboard history cliphist keeps. `cliphist list` prints one entry per
// line, newest first: the id, a tab, a one-line preview. An image's preview is
// "[[ binary data 144 KiB png 1280x720 ]]". The whole line goes back to
// `cliphist decode` to get the entry itself.

var IMAGE = /^\[\[ binary data (.*) \]\]$/
var COPY = "printf %s \"$1\" | cliphist decode | wl-copy"

function listArgv() { return ["cliphist", "list"] }

// The line is one literal argument; the script never interpolates it.
function copyArgv(line) { return ["sh", "-c", COPY, "sh", String(line)] }

function parse(text) {
  var lines = String(text || "").split("\n"), out = []
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i], tab = line.indexOf("\t")
    if (tab < 0) {
      continue
    }

    var preview = line.slice(tab + 1)
    if (!preview.trim()) {
      continue
    }

    var image = IMAGE.exec(preview)
    out.push({ line: line, text: image ? "Image · " + image[1] : preview, image: !!image })
  }
  return out
}
