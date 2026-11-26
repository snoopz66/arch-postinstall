#!/usr/bin/env bash
# The Dropbox panel's status helper in a scratch home, with a fake dropbox-cli: what it
# reports for a linked account, an unlinked one and a machine without the CLI.
set -euo pipefail

helper=$1
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fail() {
  [[ -z ${2:-} ]] || printf '%s\n' "$2" >&2
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

home=$tmp/home
box=$home/Dropbox
mkdir -p "$tmp/bin" "$tmp/nocli" "$home/.dropbox" "$box/Photos" "$box/.dropbox.cache"

cat >"$tmp/bin/dropbox-cli" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$CALLS"
[[ $1 == "status" ]] && echo "Up to date"
STUB
chmod +x "$tmp/bin/dropbox-cli"
# python3 alone, so the CLI is missing however this machine is set up
ln -s "$(command -v python3)" "$tmp/nocli/python3"

status() {
  HOME=$home CALLS=$tmp/calls PATH=$tmp/bin:$PATH python3 "$helper" "$@"
}

field() {
  jq -r "$1" <<<"$out"
}

printf '{"personal": {"path": "%s", "subscription_type": "Basic"}}' "$box" >"$home/.dropbox/info.json"
printf '%0100d' 0 >"$box/old.txt"
printf '%0200d' 0 >"$box/Photos/new.jpg"
printf '%0400d' 0 >"$box/.dropbox.cache/staged"
touch -d '2026-01-01' "$box/old.txt"
touch -d '2026-02-01' "$box/Photos/new.jpg"

out=$(status 25)
[[ $(field '[.installed, .running, .authenticated] | join(" ")') == "true true true" ]] ||
  fail "a linked account with the daemon up is installed, running and signed in" "$out"
[[ $(field .statusText) == "Up to date" ]] || fail "the status is the daemon's own" "$out"
[[ $(field .usedBytes) == 300 ]] || fail "what is stored leaves out Dropbox's own cache" "$out"
[[ $(field '[.quotaKnown, .quotaBytes] | join(" ")') == "true 2000000000" ]] || fail "the quota follows the plan" "$out"
[[ $(field '[.files[] | .name + ":" + .folder] | join(" ")') == "new.jpg:Photos old.txt:/" ]] ||
  fail "recent files come newest first, each with its folder" "$out"
echo "ok - a linked account reports its status, usage and recent files"

out=$(status 1)
[[ $(field '.files | length') == 1 && $(field '.files[0].name') == "new.jpg" ]] || fail "the list stops at the number asked for" "$out"
out=$(status 25 --status-only)
[[ $(field '[.statusOnly, .usedBytes, (.files | length)] | join(" ")') == "true 0 0" ]] || fail "a status-only read skips the scan" "$out"
echo "ok - the recent files are capped, and skipped for a status-only read"

# Unlinked: asking the daemon for its status would void the link Log in opened.
rm "$home/.dropbox/info.json"
: >"$tmp/calls"
out=$(status 25)
[[ $(field '[.installed, .running, .authenticated] | join(" ")') == "true false false" ]] ||
  fail "an unlinked account is installed but not signed in" "$out"
[[ ! -s $tmp/calls ]] || fail "an unlinked daemon is not asked for its status" "$(<"$tmp/calls")"
echo "ok - an unlinked account is not asked for its status"

out=$(HOME=$home PATH=$tmp/nocli python3 "$helper" 25)
[[ $(field '[.installed, .statusText] | join(" ")') == "false Not installed" ]] || fail "without dropbox-cli it reads as not installed" "$out"
echo "ok - without dropbox-cli it reads as not installed"
