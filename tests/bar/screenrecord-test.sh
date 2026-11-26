#!/usr/bin/env bash
# screenrecord against a fake recorder: a process that runs until interrupted.
set -euo pipefail

script=$1
tmp=$(mktemp -d)
trap 'pkill -f "$tmp/bin/gpu-screen-recorder" 2>/dev/null || true; rm -rf "$tmp"' EXIT

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

mkdir "$tmp/bin" "$tmp/home" "$tmp/run"
cat >"$tmp/bin/gpu-screen-recorder" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$FAKE/recorder-args"
trap 'exit 0' INT
while :; do sleep 0.1; done
STUB
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >>"$FAKE/notes"\n' >"$tmp/bin/notify-send"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >>"$FAKE/ipc"\n' >"$tmp/bin/qs"
chmod +x "$tmp"/bin/*
export FAKE=$tmp HOME=$tmp/home XDG_RUNTIME_DIR=$tmp/run PATH=$tmp/bin:$PATH

if "$script" status; then
  fail "nothing is recording at first"
fi
echo "ok - nothing is recording at first"

"$script" start
sleep 0.3
"$script" status || fail "start begins a recording"
grep -q -- "-o $HOME/Videos/Recordings/.*\.mp4" "$tmp/recorder-args" || fail "the recording goes to ~/Videos/Recordings"
grep -qx "ipc call indicators refresh" "$tmp/ipc" || fail "the bar is told a recording began"
echo "ok - start begins a recording into ~/Videos/Recordings"

first=$(<"$tmp/run/screenrecord.pid")
"$script" start
[[ $(<"$tmp/run/screenrecord.pid") == "$first" ]] || fail "a second start leaves the running recording alone"
echo "ok - a second start leaves the running recording alone"

"$script" stop
if "$script" status; then
  fail "stop ends the recording"
fi
if kill -0 "$first" 2>/dev/null; then
  fail "stop waits for the recorder to finish the file"
fi
grep -q "Recording saved" "$tmp/notes" || fail "stop says where the file went"
[[ $(grep -cx "ipc call indicators refresh" "$tmp/ipc") == 2 ]] || fail "the bar is told the recording ended"
echo "ok - stop ends the recording and says where the file went"

"$script" toggle
sleep 0.3
"$script" status || fail "toggle starts when idle"
"$script" toggle
if "$script" status; then
  fail "toggle stops when recording"
fi
echo "ok - toggle starts and stops"
