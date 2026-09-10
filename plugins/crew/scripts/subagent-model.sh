#!/usr/bin/env bash
# SubagentStop hook: proves which model a subagent actually ran on and logs it beside the
# model its persona declares, so a silent downgrade (a 429 fallback, a wrong override, an
# edited persona) is visible instead of absorbed.
#
# Usage: subagent-model.sh            hook mode, payload JSON on stdin (appends one log line)
#        subagent-model.sh path       print the current project's log path
#        subagent-model.sh tail [n]   print the last n lines of that log (default 10)
#
# The hook must never fail a subagent: no `set -e`, every path exits 0, nothing on stdout.
# CREW_MODEL_LOG_DIR overrides the log directory (the witness uses it).
set -u

log_name=crew-models.log

# slug_for <absolute-path> -> Claude Code's project-directory slug for that path
slug_for() { echo "$1" | sed 's|/|-|g'; }

# log_dir_for <session-id> <project-slug> -> the session-local directory to log into
log_dir_for() {
  if [ -n "${CREW_MODEL_LOG_DIR:-}" ]; then echo "$CREW_MODEL_LOG_DIR"; return 0; fi
  local base="/tmp/claude-$(id -u)/$2/$1"
  if [ -d "$base/scratchpad" ]; then echo "$base/scratchpad"
  elif [ -d "$base/tasks" ]; then echo "$base/tasks"
  else echo "$base/scratchpad"
  fi
}

# declared_model_for <agent-type> -> the persona's frontmatter model:, or "-"
# agent_type arrives plugin-scoped ("crew:qa-engineer"); a non-crew agent has no persona here.
declared_model_for() {
  local name=${1##*:} root
  root=$(cd "$(dirname "$0")/.." 2>/dev/null && pwd) || return 0
  local persona="$root/agents/$name.md"
  [ -f "$persona" ] || { echo "-"; return 0; }
  local m
  m=$(sed -n '/^---$/,/^---$/p' "$persona" | grep -E '^model:' | head -1 | sed -E 's/^model:[[:space:]]*//; s/[[:space:]]+$//')
  echo "${m:--}"
}

# actual_models_for <transcript> -> comma-joined distinct model ids, or "-"
actual_models_for() {
  [ -n "$1" ] && [ -r "$1" ] || { echo "-"; return 0; }
  local m
  m=$(grep -o '"model":"[^"]*"' "$1" | sed 's/.*:"//; s/"$//' | grep -v '^<' | sort -u | paste -sd, -)
  echo "${m:--}"
}

# mismatch_for <declared-alias> <comma-joined-actual> -> "MISMATCH" or ""
# A tier alias matches the id it dispatches to: fable -> claude-fable-5-1, haiku ->
# claude-haiku-4-5-20251001. Anything not a tier alias (inherit, "-") is not judged.
mismatch_for() {
  case "$1" in fable|opus|sonnet|haiku) ;; *) return 0 ;; esac
  [ "$2" = "-" ] && return 0
  local one actual
  IFS=, read -ra actual <<<"$2"
  for one in "${actual[@]}"; do
    case "$one" in "$1"|"claude-$1"|"claude-$1-"*) ;; *) echo MISMATCH; return 0 ;; esac
  done
}

run_hook() {
  command -v jq >/dev/null 2>&1 || return 0
  local input; input=$(cat) || return 0
  [ -n "$input" ] || return 0

  local sid agent_type agent_id transcript parent_transcript cwd
  sid=$(jq -r '.session_id // empty' <<<"$input" 2>/dev/null)
  agent_type=$(jq -r '.agent_type // empty' <<<"$input" 2>/dev/null)
  agent_id=$(jq -r '.agent_id // empty' <<<"$input" 2>/dev/null)
  transcript=$(jq -r '.agent_transcript_path // empty' <<<"$input" 2>/dev/null)
  parent_transcript=$(jq -r '.transcript_path // empty' <<<"$input" 2>/dev/null)
  cwd=$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null)

  local slug=
  # The parent transcript lives at ~/.claude/projects/<slug>/<session>.jsonl, so its parent
  # directory names the slug exactly; cwd is the fallback when the field is absent.
  [ -n "$parent_transcript" ] && slug=$(basename "$(dirname "$parent_transcript")")
  [ -n "$slug" ] || slug=$(slug_for "${cwd:-$PWD}")

  # Fallback for a client whose payload carries no agent_transcript_path (verified present in
  # Claude Code 2.1.263): derive it from the session's tasks directory.
  if [ -z "$transcript" ] && [ -n "$sid" ] && [ -n "$agent_id" ]; then
    local derived="/tmp/claude-$(id -u)/$slug/$sid/tasks/$agent_id.output"
    [ -r "$derived" ] && transcript=$derived
  fi

  local declared actual flag dir
  declared=$(declared_model_for "${agent_type:-}")
  actual=$(actual_models_for "$transcript")
  flag=$(mismatch_for "$declared" "$actual")
  dir=$(log_dir_for "${sid:-unknown}" "$slug")

  mkdir -p "$dir" 2>/dev/null || return 0
  printf '%s %s declared=%s actual=%s%s\n' \
    "$(date -Is)" "${agent_type:--}" "$declared" "$actual" "${flag:+ $flag}" \
    >> "$dir/$log_name" 2>/dev/null

  return 0
}

# Newest crew-models.log across this project's sessions (the lead's session is the newest writer).
current_log() {
  local slug; slug=$(slug_for "$PWD")
  [ -n "${CREW_MODEL_LOG_DIR:-}" ] && { echo "$CREW_MODEL_LOG_DIR/$log_name"; return 0; }
  ls -1t "/tmp/claude-$(id -u)/$slug"/*/scratchpad/"$log_name" \
          "/tmp/claude-$(id -u)/$slug"/*/tasks/"$log_name" 2>/dev/null | head -1
}

case "${1:-hook}" in
  path) current_log ;;
  tail) f=$(current_log)
        if [ -n "$f" ] && [ -r "$f" ]; then echo "$f"; tail -n "${2:-10}" "$f"
        else echo "no crew model log for this project yet"; fi ;;
  hook) run_hook || true ;;
  *) echo "usage: subagent-model.sh [hook|path|tail [n]]" >&2; exit 1 ;;
esac
exit 0
