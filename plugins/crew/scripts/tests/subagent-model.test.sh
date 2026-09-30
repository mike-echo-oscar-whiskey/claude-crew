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

# ---------------------------------------------------------------------------
# audit: the session's own files are the proof, the lead's dispatch is the claim
# ---------------------------------------------------------------------------
# HOME is redirected at every audit call: this client keeps a session transcript at
# ~/.claude/projects/<slug>/<session-id>.jsonl, so a canned HOME is a canned lead transcript.
home="$tmp/home"
lead_for() { echo "$home/.claude/projects/-w-proj/$1.jsonl"; }

# run <session-dir> <session-id> <agent-id> <model>... -> one canned tasks/<agent-id>.output
run() {
  local dir=$1 sid=$2 id=$3; shift 3
  mkdir -p "$dir/tasks"
  local f="$dir/tasks/$id.output"
  printf '{"type":"user","sessionId":"%s","cwd":"/w/proj","agentId":"%s","isSidechain":true,' "$sid" "$id" > "$f"
  printf '"message":{"role":"user","content":"Role: technical-writer\\nSECRET PROMPT TEXT\\n"}}\n' >> "$f"
  local m; for m in "$@"; do printf '{"type":"assistant","message":{"model":"%s"}}\n' "$m" >> "$f"; done
}

# dispatch <session-id> <tool-use-id> <agent-id> <subagent-type> <description> <model-param|->
# Writes the two entries the client records per Agent call: the tool_use with its input, and the
# tool result whose toolUseResult carries the agent id. Both carry prompt text on purpose — the
# audit must never print it.
dispatch() {
  local t; t=$(lead_for "$1"); mkdir -p "$(dirname "$t")"
  local tu=$2 id=$3 st=$4 desc=$5 mp=$6 inp
  inp=$(jq -nc --arg st "$st" --arg d "$desc" --arg m "$mp" \
    '{description:$d,subagent_type:$st,prompt:"SECRET PROMPT TEXT"} + (if $m=="-" then {} else {model:$m} end)')
  jq -nc --arg tu "$tu" --argjson i "$inp" \
    '{type:"assistant",message:{content:[{type:"tool_use",id:$tu,name:"Agent",input:$i}]}}' >> "$t"
  jq -nc --arg tu "$tu" --arg id "$id" \
    '{type:"user",message:{content:[{type:"tool_result",tool_use_id:$tu}]},toolUseResult:{agentId:$id,description:"SECRET PROMPT TEXT",prompt:"SECRET PROMPT TEXT",isAsync:true,status:"async_launched",resolvedModel:"claude-opus-5"}}' >> "$t"
}

aud() { AUD_OUT=$(HOME="$home" bash "$sut" audit "$1" 2>&1); AUD_RC=$?; AUD_N=$(tr -s ' ' <<<"$AUD_OUT"); }

# audit_case <name> <expected-rc> <expect...> -- <reject...>   (reads AUD_*, set by aud)
audit_case() {
  local name=$1 want=$2; shift 2
  if [ "$AUD_RC" -ne "$want" ]; then fail "$name" "audit exited $AUD_RC, expected $want; output: $AUD_N"; return; fi
  local mode=expect s
  for s in "$@"; do
    if [ "$s" = "--" ]; then mode=reject; continue; fi
    case "$mode:$AUD_N" in
      expect:*"$s"*) ;;
      expect:*) fail "$name" "expected '$s' in table, got: $AUD_N"; return ;;
      reject:*"$s"*) fail "$name" "table must not contain '$s': $AUD_N"; return ;;
    esac
  done
  pass "$name"
}

# 1 — one row per run, with the five columns, and a non-agent output counted rather than dropped.
s1=$tmp/sess1
run "$s1" S1 a1 claude-opus-5 claude-opus-5 claude-opus-5
run "$s1" S1 a2 claude-haiku-4-5-20251001 claude-haiku-4-5-20251001
run "$s1" S1 a3 claude-sonnet-5-5
echo 'a background shell task wrote this' > "$s1/tasks/bq7zz.output"
dispatch S1 tu1 a1 crew:security-engineer "opus · first"  opus
dispatch S1 tu2 a2 crew:scout             "haiku · second" -
dispatch S1 tu3 a3 crew:technical-writer  "sonnet · third" sonnet
aud "$s1"
audit_case "audit prints one row per run with role, declared, actual, calls and size" 0 \
  "ROLE DECLARED ACTUAL CALLS SIZE" \
  "a1 crew:security-engineer opus claude-opus-5 3 " \
  "a2 crew:scout haiku claude-haiku-4-5-20251001 2 " \
  "a3 crew:technical-writer sonnet claude-sonnet-5-5 1 " \
  "3 runs, 3 lines, 0 mismatches" "1 non-agent output skipped" \
  -- "MISMATCH" "SECRET PROMPT TEXT"

# 2 — the declared model is the dispatch's, so an overridden persona is not a mismatch.
# crew:security-engineer's frontmatter says fable; this dispatch said opus and opus ran.
s2=$tmp/sess2
run "$s2" S2 a1 claude-opus-5
dispatch S2 tu1 a1 crew:security-engineer "opus · deliberately moved up" opus
aud "$s2"
audit_case "audit takes the declared model from the dispatch, so an overridden persona is not a mismatch" 0 \
  "a1 crew:security-engineer opus claude-opus-5 1 " "0 mismatches" -- "MISMATCH" "fable"

# 3 — a run that ran on a model its dispatch did not ask for, and a dispatch that contradicts itself.
s3=$tmp/sess3
run "$s3" S3 a1 claude-haiku-4-5-20251001
run "$s3" S3 a2 claude-sonnet-5-5
dispatch S3 tu1 a1 crew:qa-engineer "opus · review" opus
dispatch S3 tu2 a2 crew:architect   "opus · design" sonnet
aud "$s3"
audit_case "audit flags a run that ran on a model its dispatch did not ask for, exits 1, and names a dispatch conflict distinctly" 1 \
  "a1 crew:qa-engineer opus claude-haiku-4-5-20251001 1 " "MISMATCH" \
  "a2 crew:architect opus claude-sonnet-5-5 1 " "DISPATCH-CONFLICT" \
  "2 runs, 2 lines, 2 mismatches, 1 dispatch conflict"

# 4 — no dispatch to be found: declared is ?, the role falls back to the brief's Role: line,
# and an unknown is not a finding.
s4=$tmp/sess4
run "$s4" S4 a1 claude-opus-5
: > "$(lead_for S4)"
aud "$s4"
audit_case "audit prints ? and counts no mismatch when the dispatch cannot be located" 0 \
  "a1 technical-writer ? claude-opus-5 1 " "1 runs, 1 lines, 0 mismatches" -- "MISMATCH"

# 5 — the hook's own fallbacks, on the payload this client really sends.
slug=-w-proj
mkdir -p "$home/.claude/projects/$slug/s9/subagents"
sub="$home/.claude/projects/$slug/s9/subagents/agent-a9.jsonl"
printf '{"type":"user","message":{"role":"user","content":"Role: technical-writer\\n"}}\n' > "$sub"
printf '{"type":"assistant","message":{"model":"claude-sonnet-5-5"}}\n' >> "$sub"
dir="$tmp/log-hookfallback"; mkdir -p "$dir"
payload=$(jq -nc --arg p "$home/.claude/projects/$slug/s9.jsonl" '{session_id:"s9",agent_id:"a9",transcript_path:$p}')
out=$(HOME="$home" CREW_MODEL_LOG_DIR="$dir" bash "$sut" <<<"$payload" 2>/dev/null); rc=$?
line=$(cat "$dir/crew-models.log" 2>/dev/null)
name="a payload with neither agent_type nor agent_transcript_path resolves both from the session's own files"
if [ "$rc" -ne 0 ]; then fail "$name" "hook exited $rc"
elif [ -n "$out" ]; then fail "$name" "hook wrote to stdout: $out"
else case "$line" in
  *"technical-writer declared=sonnet actual=claude-sonnet-5-5"*) pass "$name" ;;
  *) fail "$name" "got: ${line:-<no log written>}" ;;
esac; fi

dir2="$tmp/log-hookrecord"; mkdir -p "$dir2"
payload=$(jq -nc '{session_id:"s10",agent_id:"missing",transcript_path:"/home/x/.claude/projects/-w-proj/s10.jsonl"}')
out=$(HOME="$home" CREW_MODEL_LOG_DIR="$dir2" bash "$sut" <<<"$payload" 2>/dev/null); rc=$?
line=$(cat "$dir2/crew-models.log" 2>/dev/null)
name="an unresolvable payload logs its field names only, writes nothing to stdout and exits 0"
if [ "$rc" -ne 0 ]; then fail "$name" "hook exited $rc"
elif [ -n "$out" ]; then fail "$name" "hook wrote to stdout: $out"
else case "$line" in
  *"fields=session_id,agent_id,transcript_path"*)
    case "$line" in
      *"/home/x/"*|*s10.jsonl*) fail "$name" "the recorded-failure line carries a payload VALUE: $line" ;;
      *) pass "$name" ;;
    esac ;;
  *) fail "$name" "expected 'fields=session_id,agent_id,transcript_path', got: ${line:-<no log written>}" ;;
esac; fi

if [ "$fails" -eq 0 ]; then echo "PASS"; exit 0; fi
echo "FAIL ($fails)"; exit 1
