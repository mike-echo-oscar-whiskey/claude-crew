#!/usr/bin/env bash
# Witness for subagent-model.sh: canned SubagentStop payloads + canned transcripts in, one
# asserted log line out. Run it bare:  bash plugins/crew/scripts/tests/subagent-model.test.sh
# Exits 0 when every case passes, 1 on the first failure, and names the case either way.
set -u

here=$(cd "$(dirname "$0")" && pwd)
sut="$here/../subagent-model.sh"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
fails=0

pass() { echo "  ok   $1"; }
fail() { echo "  FAIL $1"; echo "       $2"; fails=$((fails + 1)); }

# transcript <name> <model-id>... -> path to a canned subagent JSONL
transcript() {
  local f="$tmp/$1.jsonl"; shift
  : > "$f"
  local m; for m in "$@"; do printf '{"type":"assistant","message":{"model":"%s"}}\n' "$m" >> "$f"; done
  echo "$f"
}

# run_case <name> <payload-json> <expected-substring> [reject-substring]
run_case() {
  local name=$1 payload=$2 expect=$3 reject=${4:-}
  local dir="$tmp/log-$name"; mkdir -p "$dir"
  local out rc
  out=$(CREW_MODEL_LOG_DIR="$dir" bash "$sut" <<<"$payload" 2>/dev/null); rc=$?
  if [ "$rc" -ne 0 ]; then fail "$name" "hook exited $rc, must always be 0"; return; fi
  if [ -n "$out" ]; then fail "$name" "hook wrote to stdout: $out"; return; fi
  local line; line=$(cat "$dir/crew-models.log" 2>/dev/null)
  case "$line" in
    *"$expect"*) ;;
    *) fail "$name" "expected '$expect' in log line, got: ${line:-<no log written>}"; return ;;
  esac
  if [ -n "$reject" ]; then
    case "$line" in *"$reject"*) fail "$name" "log line must not contain '$reject': $line"; return ;; esac
  fi
  pass "$name"
}

echo "subagent-model.sh"

# A pinned persona that ran on its pin: declared and actual agree, no flag.
t=$(transcript match claude-fable-5-1 claude-fable-5-1)
run_case "pinned role on its own model logs declared=fable actual=claude-fable-5-1" \
  "$(jq -nc --arg t "$t" '{session_id:"s1",agent_type:"crew:security-engineer",agent_id:"a1",agent_transcript_path:$t,transcript_path:"/home/x/.claude/projects/-p/s1.jsonl"}')" \
  "crew:security-engineer declared=fable actual=claude-fable-5-1" "MISMATCH"

# The case the whole feature exists for: a fable-pinned verdict role (security-engineer; QA moved to opus in 0.5.6) that really ran on sonnet.
t=$(transcript drift claude-sonnet-5)
run_case "pinned role that ran on another model is flagged MISMATCH" \
  "$(jq -nc --arg t "$t" '{session_id:"s2",agent_type:"crew:security-engineer",agent_id:"a2",agent_transcript_path:$t,transcript_path:"/home/x/.claude/projects/-p/s2.jsonl"}')" \
  "declared=fable actual=claude-sonnet-5 MISMATCH"

# A dated model id still satisfies its tier alias.
t=$(transcript dated claude-haiku-4-5-20251001)
run_case "dated model id matches its tier alias" \
  "$(jq -nc --arg t "$t" '{session_id:"s3",agent_type:"crew:scout",agent_id:"a3",agent_transcript_path:$t,transcript_path:"/home/x/.claude/projects/-p/s3.jsonl"}')" \
  "crew:scout declared=haiku actual=claude-haiku-4-5-20251001" "MISMATCH"

# A model change mid-run is recorded in full and flagged.
t=$(transcript switched claude-fable-5-1 claude-opus-5)
run_case "a model change mid-run lists both and flags" \
  "$(jq -nc --arg t "$t" '{session_id:"s4",agent_type:"crew:architect",agent_id:"a4",agent_transcript_path:$t,transcript_path:"/home/x/.claude/projects/-p/s4.jsonl"}')" \
  "declared=fable actual=claude-fable-5-1,claude-opus-5 MISMATCH"

# Synthetic assistant messages are noise, not a model.
t=$(transcript synthetic "<synthetic>" claude-opus-5)
run_case "synthetic messages are not counted as a model" \
  "$(jq -nc --arg t "$t" '{session_id:"s5",agent_type:"crew:backend-engineer",agent_id:"a5",agent_transcript_path:$t,transcript_path:"/home/x/.claude/projects/-p/s5.jsonl"}')" \
  "declared=opus actual=claude-opus-5" "MISMATCH"

# A non-crew agent has no persona to declare a model, so nothing is judged.
t=$(transcript foreign claude-sonnet-5)
run_case "an agent with no crew persona logs declared=- and is not judged" \
  "$(jq -nc --arg t "$t" '{session_id:"s6",agent_type:"Explore",agent_id:"a6",agent_transcript_path:$t,transcript_path:"/home/x/.claude/projects/-p/s6.jsonl"}')" \
  "Explore declared=- actual=claude-sonnet-5" "MISMATCH"

# Fallback: a payload without agent_transcript_path derives it from the session's tasks dir.
slug="-crew-witness-$$"
fallback_dir="/tmp/claude-$(id -u)/$slug/s7/tasks"
mkdir -p "$fallback_dir"
printf '{"message":{"model":"claude-opus-5"}}\n' > "$fallback_dir/a7.output"
run_case "a payload without agent_transcript_path falls back to the tasks dir" \
  "$(jq -nc --arg p "/home/x/.claude/projects/$slug/s7.jsonl" '{session_id:"s7",agent_type:"crew:backend-engineer",agent_id:"a7",transcript_path:$p}')" \
  "declared=opus actual=claude-opus-5" "MISMATCH"
rm -rf "/tmp/claude-$(id -u)/$slug"

# An unreadable transcript is recorded as unknown, never as a failure.
run_case "a missing transcript logs actual=- without failing" \
  "$(jq -nc '{session_id:"s8",agent_type:"crew:scout",agent_id:"a8",agent_transcript_path:"/nonexistent/nope.jsonl",transcript_path:"/home/x/.claude/projects/-p/s8.jsonl"}')" \
  "crew:scout declared=haiku actual=-" "MISMATCH"

# The hook must survive anything the client hands it.
for junk in "" "not json at all" "{}"; do
  out=$(CREW_MODEL_LOG_DIR="$tmp/junk" bash "$sut" <<<"$junk" 2>/dev/null); rc=$?
  if [ "$rc" -ne 0 ]; then fail "junk payload '${junk:0:12}' exits 0" "exited $rc"
  elif [ -n "$out" ]; then fail "junk payload '${junk:0:12}' is silent" "stdout: $out"
  else pass "junk payload '${junk:0:12}' exits 0 and stays silent"; fi
done

if [ "$fails" -eq 0 ]; then echo "PASS"; exit 0; fi
echo "FAIL ($fails)"; exit 1
