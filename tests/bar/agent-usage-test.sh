#!/usr/bin/env bash
# The usage collectors behind the agents panel (bin/bar-agent-usage-*), on a scratch
# machine: no sign-ins, no agent CLIs, and nowhere for a request to go.
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

export HOME=$tmp/home
export XDG_CONFIG_HOME=$HOME/.config XDG_DATA_HOME=$HOME/.local/share XDG_STATE_HOME=$HOME/.local/state
export XDG_CACHE_HOME=$HOME/.cache XDG_RUNTIME_DIR=$HOME/.run
mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME" "$XDG_CACHE_HOME" "$XDG_RUNTIME_DIR" "$tmp/tools"

# Nothing of the developer's own may point a collector at a real sign-in.
while IFS= read -r name; do
  if [[ $name == *_API_KEY || $name =~ ^(AGY_|ANTHROPIC_|CLAUDE_|CLOUD_CODE_|CODEX_|GEMINI_|GOOGLE_|OPENAI_) ]]; then
    unset "$name"
  fi
done < <(compgen -e)
export http_proxy=http://127.0.0.1:9 https_proxy=http://127.0.0.1:9 HTTP_PROXY=http://127.0.0.1:9 HTTPS_PROXY=http://127.0.0.1:9

stamp=$(date -u +%Y-%m-%dT%H:%M:%S.000Z)

# Only the tools the collectors, the updater and this test need: no agent CLI is on this PATH.
for tool in python3 bash env jq rg sqlite3 mkdir mktemp mv rm cat find dirname realpath; do
  if command -v "$tool" >/dev/null; then
    ln -s "$(command -v "$tool")" "$tmp/tools/$tool"
  fi
done
export PATH=$tmp/tools PYTHONDONTWRITEBYTECODE=1
export BAR_AGENTS_DIR=$root/config/quickshell/panels/agents

# One Claude Code reply today, 7 tokens in.
mkdir -p "$HOME/.claude/projects/project"
cat >"$HOME/.claude/projects/project/s1.jsonl" <<JSONL
{"type":"user","uuid":"s1-prompt-0","sessionId":"s1","timestamp":"$stamp","message":{"role":"user","content":"go"}}
{"type":"assistant","sessionId":"s1","timestamp":"$stamp","requestId":"s1-req-0","message":{"id":"s1-msg-0","role":"assistant","model":"claude-opus-5-5","usage":{"input_tokens":7,"output_tokens":0}}}
JSONL

record=$("$root/bin/bar-agent-usage-claude") || fail "the Claude collector runs without a sign-in"
[[ $(jq -r '.id' <<<"$record") == claude ]] || fail "the Claude collector prints its record"
[[ $(jq -r '.todayTotalTokens' <<<"$record") == 7 ]] || fail "the Claude collector counts today's transcript tokens"
[[ $(jq -r '.limits | length' <<<"$record") == 0 ]] || fail "the Claude collector has no limits without a sign-in"
echo "ok - the Claude collector counts transcripts and has no limits without a sign-in"

for agent in codex agy; do
  record=$("$root/bin/bar-agent-usage-$agent") || fail "the $agent collector runs without its CLI"
  [[ $(jq -r '.id' <<<"$record") == "$agent" ]] || fail "the $agent collector prints its record"
  [[ $(jq -r '.limits | length' <<<"$record") == 0 ]] || fail "the $agent collector has no limits without a sign-in"
done
echo "ok - the Codex and Gemini collectors print a record without their CLI"

"$root/bin/bar-agent-usage-update" || fail "the updater runs every collector"
for agent in claude codex agy; do
  jq -e --arg id "$agent" '.id == $id' "$XDG_STATE_HOME/bar/agents/usage/$agent.json" >/dev/null || fail "the updater writes $agent's record"
done
echo "ok - the updater writes each record where the panel watches"

if left=$(find "$HOME" -iname '*omarchy*' -print -quit) && [[ -n $left ]]; then
  fail "nothing is kept under an Omarchy directory ($left)"
fi
[[ -d $XDG_CACHE_HOME/bar/agent-usage ]] || fail "the collectors cache under ~/.cache/bar"
echo "ok - state and cache are kept under bar/"
