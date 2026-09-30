#!/usr/bin/env bash
# Which model a subagent actually ran on, beside the model its dispatch asked for, so a silent
# downgrade (a 429 fallback, a wrong override, an edited persona) is visible instead of absorbed.
#
# Usage: subagent-model.sh                  hook mode, payload JSON on stdin (appends one log line)
#        subagent-model.sh path             print the current project's log path
#        subagent-model.sh tail [n]         print the last n lines of that log (default 10)
#        subagent-model.sh audit [dir]      the PROOF: walk a session's own files and compare
#
# `audit` is the proof and the hook is best-effort. The hook sees only what the client puts in its
# SubagentStop payload; `audit` reads the files the session itself wrote, so it needs nothing from
# the payload at all.
#
# The hook must never fail a subagent: no `set -e`, every path exits 0, nothing on stdout.
# CREW_MODEL_LOG_DIR overrides the log directory (the witness uses it).
set -u

log_name=crew-models.log

# slug_for <absolute-path> -> Claude Code's project-directory slug for that path
slug_for() { echo "$1" | sed 's|/|-|g'; }

# --- CLIENT LAYOUT -----------------------------------------------------------------------------
# The functions in this block are the only places that know where Claude Code puts things. None of
# it is a published contract: it is one client's on-disk layout, depended on deliberately because
# the SubagentStop payload does not carry what this script needs. When a release moves these
# files, this block is the whole fix.
#
#   session transcript   $HOME/.claude/projects/<slug>/<session-id>.jsonl
#   subagent transcript  $HOME/.claude/projects/<slug>/<session-id>/subagents/agent-<agent-id>.jsonl
#   session scratch      /tmp/claude-<uid>/<slug>/<session-id>/{scratchpad,tasks}
#
# `tasks/<agent-id>.output` is a symlink into the subagents directory above, and on the session
# that motivated this script the two lived under DIFFERENT session ids: the hook logged under the
# id its payload carried while the tasks directory sat under an older one. The subagents path is
# therefore tried first — it is keyed by the session id the payload actually gives.

# lead_transcript_for <session-id> <cwd> -> the parent session's JSONL, or "" when absent
lead_transcript_for() {
  local f="${HOME:-}/.claude/projects/$(slug_for "$2")/$1.jsonl"
  [ -r "$f" ] && echo "$f"
  return 0
}

# subagent_transcript_for <session-id> <slug> <agent-id> -> the run's own JSONL, or ""
subagent_transcript_for() {
  local f="${HOME:-}/.claude/projects/$2/$1/subagents/agent-$3.jsonl"
  [ -r "$f" ] && { echo "$f"; return 0; }
  f="/tmp/claude-$(id -u)/$2/$1/tasks/$3.output"
  [ -r "$f" ] && echo "$f"
  return 0
}

# log_dir_for <session-id> <project-slug> -> the session-local directory to log into
log_dir_for() {
  if [ -n "${CREW_MODEL_LOG_DIR:-}" ]; then echo "$CREW_MODEL_LOG_DIR"; return 0; fi
  local base="/tmp/claude-$(id -u)/$2/$1"
  if [ -d "$base/scratchpad" ]; then echo "$base/scratchpad"
  elif [ -d "$base/tasks" ]; then echo "$base/tasks"
  else echo "$base/scratchpad"
  fi
}

# session_dir_for_pwd -> the newest session directory of this project that has a tasks directory
# Given no argument, `audit` has to guess which session to walk; an explicit argument is exact.
session_dir_for_pwd() {
  local slug; slug=$(slug_for "$PWD")
  ls -1dt "/tmp/claude-$(id -u)/$slug"/*/tasks 2>/dev/null | head -1 | sed 's|/tasks$||'
}
# -----------------------------------------------------------------------------------------------

# declared_model_for <agent-type> -> the persona's frontmatter model:, or "-"
# agent_type arrives plugin-scoped ("crew:qa-engineer"); a non-crew agent has no persona here.
# This is the LAST resort: a dispatch that named a model has already answered the question.
declared_model_for() {
  local name=${1##*:} root
  root=$(cd "$(dirname "$0")/.." 2>/dev/null && pwd) || return 0
  local persona="$root/agents/$name.md"
  [ -f "$persona" ] || { echo "-"; return 0; }
  local m
  m=$(sed -n '/^---$/,/^---$/p' "$persona" | grep -E '^model:' | head -1 | sed -E 's/^model:[[:space:]]*//; s/[[:space:]]+$//')
  echo "${m:--}"
}

# role_from_transcript <transcript> -> the brief's own first "Role: <name>" line, or "-"
# Every crew brief starts with one, so it answers for a payload that carries no agent_type.
role_from_transcript() {
  [ -n "${1:-}" ] && [ -r "$1" ] || { echo "-"; return 0; }
  local r
  r=$(grep -o 'Role: `\{0,1\}[a-z][a-z0-9-]\{2,40\}' "$1" 2>/dev/null | head -1 | sed 's/^Role: `\{0,1\}//')
  echo "${r:--}"
}

# model_lines_of <transcript> -> one model id per assistant message (duplicates kept, for a count)
# Only the model field of a message object counts. A bare grep for '"model":"' also matches the
# same text quoted inside a prompt — which every brief about this script contains.
model_lines_of() {
  [ -n "${1:-}" ] && [ -r "$1" ] || return 0
  jq -Rr 'fromjson? | select(type=="object") | select((.message|type)=="object") | (.message.model // empty)' \
    "$1" 2>/dev/null | grep -v '^<'
  return 0
}

# actual_models_for <transcript> -> comma-joined distinct model ids, or "-"
actual_models_for() {
  local m
  m=$(model_lines_of "${1:-}" | sort -u | paste -sd, -)
  echo "${m:--}"
}

# model_matches <declared> <actual-id> -> 0 when the id satisfies the declared value
# A tier alias matches the id it dispatches to (fable -> claude-fable-5-1); an explicit id matches
# itself and any longer dated form of itself. A "/effort" suffix and a "[1m]" context marker are
# not part of the model's identity.
model_matches() {
  local d=${1%%/*} a=${2%%\[*}
  d=${d%%\[*}
  case "$d" in
    fable|opus|sonnet|haiku)
      case "$a" in "$d"|"claude-$d"|"claude-$d-"*) return 0 ;; *) return 1 ;; esac ;;
  esac
  [ "$d" = "$a" ] && return 0
  case "$a" in "$d"-*) return 0 ;; esac
  case "$d" in "$a"-*) return 0 ;; esac
  return 1
}

# judgeable <declared> -> 0 when the declared value says something a comparison can use
judgeable() { case "${1:-}" in ""|-|\?|inherit) return 1 ;; esac; return 0; }

# mismatch_for <declared> <comma-joined-actual> -> "MISMATCH" or ""
mismatch_for() {
  judgeable "$1" || return 0
  [ "$2" = "-" ] && return 0
  local one actual
  IFS=, read -ra actual <<<"$2"
  for one in "${actual[@]}"; do
    model_matches "$1" "$one" || { echo MISMATCH; return 0; }
  done
}

# model_token <word> -> the word when it names a model, else ""
# Operating-model rule 2 makes every Agent description start with the model it dispatches on, and
# that prefix is the claim the user actually sees, so it outranks everything else.
model_token() {
  case "${1%%/*}" in
    fable|opus|sonnet|haiku) echo "${1%%/*}" ;;
    claude-*) echo "$1" ;;
  esac
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

  # Fallback for a payload carrying no agent_transcript_path — the common case on the session this
  # script was measured on: resolve the run's own transcript from its agent id.
  if [ -z "$transcript" ] && [ -n "$sid" ] && [ -n "$agent_id" ]; then
    transcript=$(subagent_transcript_for "$sid" "$slug" "$agent_id")
  fi

  # Fallback for a payload carrying no agent_type: the brief's own Role: line.
  local role=${agent_type:-}
  [ -n "$role" ] || role=$(role_from_transcript "$transcript")

  local declared actual flag dir
  declared=$(declared_model_for "$role")
  actual=$(actual_models_for "$transcript")
  flag=$(mismatch_for "$declared" "$actual")
  dir=$(log_dir_for "${sid:-unknown}" "$slug")

  mkdir -p "$dir" 2>/dev/null || return 0

  # Recorded failure: when the payload named no agent type, or the transcript could not be resolved
  # at all, name the payload's own top-level FIELDS so the next diagnosis is a read rather than a
  # guess. Names only, never a value — a transcript path is a path, and a prompt is not for a log.
  # Once per log file, because a payload shape is a property of the client, not of the run that hit
  # it, and repeating it 600 times is the noise this script exists to remove.
  local fields=
  if { [ -z "$transcript" ] || [ -z "${agent_type:-}" ]; } \
     && ! grep -q ' fields=' "$dir/$log_name" 2>/dev/null; then
    fields=$(jq -r 'if type=="object" then (keys_unsorted | join(",")) else empty end' <<<"$input" 2>/dev/null)
  fi

  printf '%s %s declared=%s actual=%s%s%s\n' \
    "$(date -Is)" "${role:--}" "$declared" "$actual" "${flag:+ $flag}" "${fields:+ fields=$fields}" \
    >> "$dir/$log_name" 2>/dev/null

  return 0
}

# --- audit ------------------------------------------------------------------------------------

# dispatch_index <lead-transcript> -> TSV: agent-id, subagent_type, description token, model param
# Reads ONLY dispatch metadata. The same transcript holds user prompts and file contents; nothing
# but these four fields is ever emitted, and none of them is free text the user wrote.
dispatch_index() {
  jq -Rr '
    fromjson? | select(type=="object") | . as $e
    | ( try ($e.message.content[]
            | select((type=="object") and .type=="tool_use" and .name=="Agent")
            | "U\t" + (.id // "-")
              + "\t" + (.input.subagent_type // "-")
              + "\t" + (((.input.description // "-") | split(" ")[0]) // "-")
              + "\t" + (.input.model // "-")) catch empty ),
      ( try (select($e.toolUseResult.agentId != null)
            | "R\t" + (($e.message.content[0].tool_use_id) // "-")
              + "\t" + $e.toolUseResult.agentId) catch empty )
  ' "$1" 2>/dev/null |
  awk -F'\t' '
    $1=="U" { st[$2]=$3; dt[$2]=$4; mp[$2]=$5 }
    $1=="R" && $2 in st { printf "%s\t%s\t%s\t%s\n", $3, st[$2], dt[$2], mp[$2] }'
}

# is_agent_output <file> -> 0 when the file is a subagent transcript
# A session's tasks directory also holds the output of backgrounded shell commands; those are not
# runs, so they are counted in the closing line rather than reported as unresolved runs.
# The first line of a real transcript is the whole brief and runs to tens of kilobytes, so this
# reads the head of it for the two keys the client writes first rather than parsing it.
is_agent_output() {
  head -c 1024 "$1" 2>/dev/null | grep -qm1 '"isSidechain":true\|"agentId":"'
}

run_audit() {
  command -v jq >/dev/null 2>&1 || { echo "audit needs jq" >&2; return 2; }
  local dir=${1:-}
  [ -n "$dir" ] || dir=$(session_dir_for_pwd)
  if [ -z "$dir" ] || [ ! -d "$dir/tasks" ]; then
    echo "no subagent runs found${dir:+ under $dir}"
    return 0
  fi

  local work; work=$(mktemp -d) || return 2

  local f id first sid cwd lead
  for f in "$dir"/tasks/*.output; do
    [ -r "$f" ] || continue
    is_agent_output "$f" || { echo "$f" >> "$work/skipped"; continue; }
    id=$(basename "$f" .output)
    first=$(head -1 "$f")
    sid=$(jq -Rr 'fromjson? | .sessionId // empty' <<<"$first" 2>/dev/null)
    cwd=$(jq -Rr 'fromjson? | .cwd // empty' <<<"$first" 2>/dev/null)
    printf '%s\t%s\n' "$id" "$f" >> "$work/runs"
    [ -n "$sid" ] && [ -n "$cwd" ] && printf '%s\t%s\n' "$sid" "$cwd" >> "$work/leads"
  done
  if [ ! -f "$work/runs" ]; then
    echo "no subagent runs under $dir/tasks"; rm -rf "$work"; return 0
  fi

  # One pass per distinct lead transcript, never per run: the transcript is tens of megabytes.
  : > "$work/dispatch"
  if [ -f "$work/leads" ]; then
    while IFS=$'\t' read -r sid cwd; do
      lead=$(lead_transcript_for "$sid" "$cwd")
      [ -n "$lead" ] && dispatch_index "$lead" >> "$work/dispatch"
    done < <(sort -u "$work/leads")
  fi

  echo "$dir/tasks"
  printf '%-18s %-28s %-10s %-34s %5s %9s  %s\n' RUN ROLE DECLARED ACTUAL CALLS SIZE FLAG

  local runs=0 lines=0 mismatches=0 conflicts=0
  local path role token param declared actual calls size flag d_tok d_par hit m
  while IFS=$'\t' read -r id path; do
    runs=$((runs + 1))
    hit=$(awk -F'\t' -v i="$id" '$1==i {printf "%s\t%s\t%s", $2, $3, $4; exit}' "$work/dispatch")
    role=- token=- param=-
    [ -n "$hit" ] && IFS=$'\t' read -r role token param <<<"$hit"

    d_tok=$(model_token "${token:--}")
    d_par=$(model_token "${param:--}")
    flag=
    if [ -n "$d_tok" ] && [ -n "$d_par" ] && ! model_matches "$d_tok" "$d_par"; then
      flag=DISPATCH-CONFLICT; conflicts=$((conflicts + 1))
    fi

    # Precedence: the description's model token (the claim the user saw), then the dispatch's
    # explicit model, then the persona's default. A run whose dispatch is nowhere declares nothing,
    # and an unknown is not a finding.
    if [ -n "$d_tok" ]; then declared=$d_tok
    elif [ -n "$d_par" ]; then declared=$d_par
    elif [ "$role" != "-" ]; then declared=$(declared_model_for "$role")
    else declared="?"
    fi
    [ "$declared" = "-" ] && declared="?"

    [ "$role" = "-" ] && role=$(role_from_transcript "$path")
    actual=$(actual_models_for "$path")
    calls=$(model_lines_of "$path" | grep -c .)
    size=$(stat -Lc%s "$path" 2>/dev/null || echo 0)

    m=$(mismatch_for "$declared" "$actual")
    if [ -n "$m" ]; then
      mismatches=$((mismatches + 1))
      flag=${flag:+$flag }MISMATCH
    elif [ "$actual" = "-" ]; then
      flag=${flag:+$flag }unresolved
    fi

    printf '%-18s %-28s %-10s %-34s %5s %9s  %s\n' \
      "$id" "$role" "$declared" "$actual" "$calls" "$size" "$flag"
    lines=$((lines + 1))
  done < <(sort "$work/runs")

  local skipped=0
  [ -f "$work/skipped" ] && skipped=$(grep -c . "$work/skipped")
  printf '%d runs, %d lines, %d mismatch%s, %d dispatch conflict%s' \
    "$runs" "$lines" "$mismatches" "$([ "$mismatches" -eq 1 ] || echo es)" \
    "$conflicts" "$([ "$conflicts" -eq 1 ] || echo s)"
  [ "$skipped" -gt 0 ] && printf ', %d non-agent output%s skipped' "$skipped" "$([ "$skipped" -eq 1 ] || echo s)"
  echo

  rm -rf "$work"
  [ "$mismatches" -gt 0 ] && return 1
  [ "$conflicts" -gt 0 ] && return 1
  [ "$lines" -lt "$runs" ] && return 1
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
  audit) run_audit "${2:-}"; exit $? ;;
  hook) run_hook || true ;;
  *) echo "usage: subagent-model.sh [hook|path|tail [n]|audit [session-dir]]" >&2; exit 1 ;;
esac
exit 0
