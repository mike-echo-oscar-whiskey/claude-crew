#!/usr/bin/env bash
# Witness for tracker.sh's create-time item checks: canned bodies in, one `refused:` line per
# failing check out, and a stub `gh` that proves nothing reached the board. Run it bare:
#   bash plugins/crew/scripts/tests/tracker.test.sh
# Exits 0 when every case passes, 1 on the first failure, and names the case either way.
set -u

here=$(cd "$(dirname "$0")" && pwd)
sut="$here/../tracker.sh"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
fails=0

pass() { echo "  ok   $1"; }
fail() { echo "  FAIL $1"; echo "       $2"; fails=$((fails + 1)); }

# A stub `gh`, first on PATH: it records every invocation and the body it was handed, and never
# reaches the network. A refusal must leave its log empty.
mkdir -p "$tmp/bin"
cat > "$tmp/bin/gh" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${CREW_GH_LOG:-/dev/null}"
prev=""; bf=""; lbl=""; num=""; lim=""
for a in "$@"; do
  case "$prev" in --body-file) bf=$a ;; --label) lbl=$a ;; --limit) lim=$a ;; view) num=$a ;; esac
  prev=$a
done
case "$*" in
  *"issue create"*)
    [ -n "$bf" ] && cat "$bf" >> "${CREW_GH_BODY:-/dev/null}"
    echo "https://github.com/o/r/issues/99" ;;
  *"issue list"*)
    # `--limit N` is an exact cap in real `gh`: it stops at N and the remainder is never returned. The
    # stub honours it, so a canned array longer than the limit comes back truncated — without that, no
    # case can see the limit the caller passed and a fetch hard-coded to the wrong number stays green.
    f="${CREW_GH_LIST_DIR:-/nonexistent}/$lbl.json"
    if [ -f "$f" ]; then
      if [ -n "$lim" ]; then jq -c ".[0:$lim]" "$f"; else cat "$f"; fi
    else echo '[]'; fi ;;
  *"issue view"*)
    case "$*" in
      *"--json body"*) echo "## Tasks" ;;                 # task create, appending the story checklist
      *"--json labels"*) cat "${CREW_GH_LANES:-/dev/null}" ;;  # release --to done's lane read, -q applied
      *assignees*) cat "${CREW_GH_CLAIM:-/dev/null}" ;;   # claim's one read, with -q already applied
      *--comments*) cat "${CREW_GH_COMMENTS:-/dev/null}" ;;   # show's second read: the comment stream alone
      *) if [ -s "${CREW_GH_VIEW:-/dev/null}" ]; then      # show's first read: the item as a human reads it
           cat "$CREW_GH_VIEW"
         else
           f="${CREW_GH_LIST_DIR:-/nonexistent}/item-$num.json"
           if [ -f "$f" ]; then cat "$f"; else echo '{}'; fi
         fi ;;
    esac ;;
esac
STUB
chmod +x "$tmp/bin/gh"

# profile <name> [extra lines...] -> a project dir carrying a stub crew profile
profile() {
  local d="$tmp/$1"; shift
  mkdir -p "$d/.claude/crew"
  { echo "tracker: github o/r"; printf '%s\n' "$@"; } > "$d/.claude/crew/profile.md"
  echo "$d"
}

# task_body <name> <Size: line> <file bullets> <numbered tests> <seam line> -> path
# Everything the checks count is a parameter, so each case differs in exactly one thing.
task_body() {
  local name=$1 size=$2 nf=$3 nt=$4 seam=$5 f="$tmp/$1.md" i
  {
    echo 'Role: `agentic-ai-engineer` · design: `docs/design/crew-0.6.0-items-and-proof.md` §3'
    echo "$size"
    echo "$seam"
    echo
    echo '## TL;DR'; echo
    echo 'A malformed item can no longer reach the board.'; echo
    echo '## In one paragraph'; echo
    echo 'The adapter checks the assembled body before it creates anything, and lists every failing'
    echo 'check at once so the caller fixes and retries in one turn.'; echo
    echo '## Goal'; echo
    echo 'Validate the assembled body in task_create before the create call.'; echo
    echo '## Proves'; echo
    echo '- `#1 AC 2` — the first-line contract, refused and witnessed'; echo
    echo '## Files'; echo
    for ((i = 1; i <= nf; i++)); do echo "- \`plugins/crew/scripts/f$i.sh\` — what changes there"; done
    echo
    echo '## Tests (RED first)'; echo
    if [ "$nt" -eq 0 ]; then
      echo 'This task is test-free: it changes Markdown only.'
    else
      for ((i = 1; i <= nt; i++)); do echo "$i. **RED** \`case $i\` — the behaviour, and the criterion it proves."; done
    fi
    echo
    echo '## Done when'; echo
    echo '- the witness is run bare and its exit code quoted'
  } > "$f"
  echo "$f"
}

conforming_task() { task_body "$1" 'Size: 2 hand-written files (+ 0 generated) · 1 RED tests · one PR' 2 1 'Split line: n/a — the cap holds with room'; }

# A story body that passes every check.
conforming_story() {
  local f="$tmp/$1.md"
  cat > "$f" <<'EOF'
## TL;DR

Every item on the board has one shape, and a malformed one is refused the moment it is written.

## Why it matters

A task nobody can see is work nobody does.

## Today, in detail

Eighteen of the task bodies do not begin with the line the rollup needs, so the board loses them.

Decision: Kris, 2026-09-30, refuse at create and warn at claim.

## Acceptance criteria

1. Given a body whose first line is wrong, when it is created, then it is refused.
   *Would be proved by: a witness asserting exit 1 and an untouched board.*
2. Given a body with no parseable size line, when it is created, then it is refused.
   *Would be proved by: a witness asserting the named check.*

## Out of scope

- the claim warning and the lint report, which land with their own task

## Proof map

| AC | Task | Proven by | ✓ |
|---|---|---|---|
| 1 | | | |
| 2 | | | |

## Open questions

1. None open.

## Related

The design document for this release.

## Tasks
EOF
  echo "$f"
}

lists="$tmp/lists"; mkdir -p "$lists"      # one canned `gh issue list --json` array per kind label
claimjson="$tmp/claim.json"; : > "$claimjson"
viewfile="$tmp/view.txt"; : > "$viewfile"              # `show`'s canned item view
commentsfile="$tmp/comments.txt"; : > "$commentsfile"  # `show`'s canned comment stream
# A case that wants `show`'s two reads canned points these at those files immediately before its `run`.
# `run` hands them to the stub and then clears them, so a canned view reaches exactly the one invocation
# that asked for it: a case appended after this file's last one cannot inherit it by accident. `lane_labels`
# is the same mechanism for the one lane read `release --to done` makes, and `lint_limit` the same again
# for `lint`'s fetch cap: a case that wants a saturated fetch lowers the cap to the number of items it
# canned, rather than canning two thousand bodies to reach the shipped one. `board_limit` is that seam
# again for the three fetches `next` and `status` make.
show_view="" show_comments="" lane_labels="" lint_limit="" board_limit=""

ghlog="" ghbody="" out="" errfile="" rc=0
# invoke <project-dir> -- <tracker args...> -> one adapter run, each stream on the stream it was written to
# The adapter runs *in* the project directory, as a real invocation does: a `generated:` glob has to be
# matched as a pattern, never expanded against whatever that directory happens to hold.
invoke() {
  local dir=$1; shift; [ "${1:-}" = "--" ] && shift
  (cd "$dir" && CREW_PROJECT_DIR="$dir" CREW_GH_LOG="$ghlog" CREW_GH_BODY="$ghbody" \
   CREW_GH_LIST_DIR="$lists" CREW_GH_CLAIM="$claimjson" \
   CREW_GH_VIEW="$show_view" CREW_GH_COMMENTS="$show_comments" CREW_GH_LANES="$lane_labels" \
   CREW_LINT_LIMIT="$lint_limit" CREW_BOARD_LIMIT="$board_limit" \
   PATH="$tmp/bin:$PATH" bash "$sut" "$@")
}
arm() { ghlog="$tmp/gh.log"; ghbody="$tmp/gh.body"; : > "$ghlog"; : > "$ghbody"; }
disarm() { show_view="" show_comments="" lane_labels="" lint_limit="" board_limit=""; }

# run <project-dir> -- <tracker args...> -> `out` holds both streams, as a terminal interleaves them
run() { arm; out=$(invoke "$@" 2>&1); rc=$?; disarm; }

# run_split <project-dir> -- <tracker args...> -> `out` holds stdout alone, `errfile` the file with stderr
# alone. For a case whose subject *is* the channel: under `run` a line moved from stderr to the stdout a
# skill parses as a table reads identically, so no assertion on `out` can see it move. Only the two cases
# that assert a channel use this; every other case wants what a terminal shows, which is `run`.
run_split() { arm; errfile="$tmp/stderr.txt"; out=$(invoke "$@" 2>"$errfile"); rc=$?; disarm; }

# refused <name> <expected substring>...  -> exit 1, every substring present, no gh call at all
refused() {
  local name=$1 want; shift
  if [ "$rc" -ne 1 ]; then fail "$name" "expected exit 1, got $rc; output: $out"; return; fi
  for want in "$@"; do
    case "$out" in *"$want"*) ;; *) fail "$name" "expected '$want' in the refusal, got: $out"; return ;; esac
  done
  if [ -s "$ghlog" ]; then fail "$name" "gh was called: $(head -1 "$ghlog")"; return; fi
  pass "$name"
}

# created <name> [expected body substring]... -> exit 0, number printed, gh asked to create with the
# kind label the board filters on (`status` and `next` select tasks by `task` and read the role label)
created() {
  local name=$1 want cmd; shift
  if [ "$rc" -ne 0 ]; then fail "$name" "expected exit 0, got $rc; output: $out"; return; fi
  case "$out" in *99*) ;; *) fail "$name" "expected the new number on stdout, got: $out"; return ;; esac
  cmd=$(grep -a -m1 "issue create" "$ghlog")
  if [ -z "$cmd" ]; then fail "$name" "gh was never asked to create"; return; fi
  case "$cmd" in
    *'--label story'*|*'--label task --label role:'*) ;;
    *) fail "$name" "the create command carries no kind label: $cmd"; return ;;
  esac
  for want in "$@"; do
    case "$(cat "$ghbody")" in *"$want"*) ;; *) fail "$name" "expected '$want' in the created body"; return ;; esac
  done
  pass "$name"
}

echo "tracker.sh create-time checks"

p=$(profile plain)
pc=$(profile capped "size-cap: 15")

# 1. AC 2 — the check that retires the eighteen-invisible-tasks class. A caller who writes the
#    sigil into --story (every body says "#5") makes the adapter assemble "Story: ##5", which
#    status() rolls up by startswith and next() greps for; the board loses the task silently.
run "$p" -- task create --story '#5' --title T --role agentic-ai-engineer --body-file "$(conforming_task t1)"
refused "task create refuses a body whose first line is not Story: #n" \
  'refused: first line must be "Story: #5"' 'got "Story: ##5"'

# 2. AC 3 — an estimate is not a size.
run "$p" -- task create --story 5 --title T --role agentic-ai-engineer \
  --body-file "$(task_body t2 'Size: about 25 files' 2 1 'Split line: n/a')"
refused "task create refuses a body with no parseable Size: line" \
  'refused: Size:' 'about 25 files'

# 3. AC 4 — over size-cap without a licence, and the same body with one.
over='Size: 20 hand-written files (+ 0 generated) · 1 RED tests · one PR'
run "$pc" -- task create --story 5 --title T --role agentic-ai-engineer \
  --body-file "$(task_body t3a "$over" 20 1 'Split line: files 13-20 and AC 4 go to the follow-up')"
refused "task create refuses H above size-cap with no Exception: line" \
  'refused: Size: 20 hand-written files is over size-cap: 15'
run "$pc" -- task create --story 5 --title T --role agentic-ai-engineer \
  --body-file "$(task_body t3b "$over" 20 1 'Exception: one mechanical rename — 20 files, no behaviour change; reviewed as one sweep.')"
created "task create accepts the same body with an Exception: line"

# 3b. AC 4 — the cap's boundary: H exactly at size-cap is inside it.
run "$pc" -- task create --story 5 --title T --role agentic-ai-engineer \
  --body-file "$(task_body t3c 'Size: 15 hand-written files (+ 0 generated) · 1 RED tests · one PR' 15 1 'Split line: the fifteen are one mechanical rename')"
created "task create accepts H exactly at size-cap"

# 3c. A size-cap: the profile cannot mean is not a cap at all. An over-long number passes the digits
#     test, then makes `[ -gt ]` fail with "integer expected", and the whole cap check disappears.
pcb=$(profile capped-bogus "size-cap: 99999999999999999999")
run "$pcb" -- task create --story 5 --title T --role agentic-ai-engineer \
  --body-file "$(task_body t3d "$over" 20 1 'Split line: files 13-20 go to the follow-up')"
refused "task create falls back to the default cap when size-cap: is not a small integer" \
  'refused: Size: 20 hand-written files is over size-cap: 15'

# 3d. A body that is not text silently disables every check that reads it: grep calls the file binary,
#     prints no match line, and H, T and the placeholder list all come back empty. Refuse it by name.
nul=$(task_body t3e "$over" 20 1 'Split line: files 13-20 go to the follow-up')
printf 'x\000y\n' >> "$nul"
run "$pc" -- task create --story 5 --title T --role agentic-ai-engineer --body-file "$nul"
refused "task create refuses a body that is not text instead of skipping its checks" \
  'refused: the body is not text'

# 4. AC 3 — the two counting rules: ## Files must agree with H, and T = 0 needs the section to say so.
run "$p" -- task create --story 5 --title T --role agentic-ai-engineer \
  --body-file "$(task_body t4a 'Size: 2 hand-written files (+ 0 generated) · 1 RED tests · one PR' 3 1 'Split line: n/a')"
refused "task create refuses a Files count that disagrees with Size H" \
  'refused: ## Files lists 3 files, Size: says 2'
run "$p" -- task create --story 5 --title T --role agentic-ai-engineer \
  --body-file "$(task_body t4b 'Size: 2 hand-written files (+ 0 generated) · 0 RED tests · one PR' 2 0 'Split line: n/a')"
created "task create accepts Tests: 0 when the section declares the task test-free"

# 4b. The `generated:` value is a glob to match a bullet's path against, never a list to expand in the
#     working directory: the bullet names a generated file that is not on disk, and the one that is on
#     disk is not in the body.
pg=$(profile generated "generated: gen/*.json")
mkdir -p "$pg/gen"; : > "$pg/gen/a.json"
gen=$(task_body t4c 'Size: 1 hand-written files (+ 1 generated) · 1 RED tests · one PR' 1 1 'Split line: n/a')
sed -i '/^- `plugins\/crew\/scripts\/f1.sh`/a - `gen/b.json` — generated, so it must not count toward H' "$gen"
run "$pg" -- task create --story 5 --title T --role agentic-ai-engineer --body-file "$gen"
created "task create matches a generated: glob as a pattern, not against the working directory"

# 4c. D5's seam rule: at 12 hand-written files or 4 RED tests the body has to say where it splits.
run "$p" -- task create --story 5 --title T --role agentic-ai-engineer \
  --body-file "$(task_body t4d 'Size: 13 hand-written files (+ 0 generated) · 1 RED tests · one PR' 13 1 '')"
refused "task create refuses 13 files with neither a Split line: nor an Exception:" \
  'refused: a task of 13 files and 1 RED tests needs a "Split line:" or an "Exception:" line'

# 4d. The placeholder scan joins the body before it strips code spans: a span that wraps a line break
#     around a `<…>` is filled-in prose, and a line-at-a-time scan refuses this conforming body.
span=$(conforming_task t4e)
sed -i 's|^Validate the assembled body in task_create before the create call\.$|Validate the assembled body against `Story:\n<sigil><n>` before the create call.|' "$span"
run "$p" -- task create --story 5 --title T --role agentic-ai-engineer --body-file "$span"
created "task create accepts a code span that wraps a <…> stub across two lines"

# 4e. The required sections come from the resolved template, so a project that overrides a kind is
#     checked against its own shape — here one that calls the goal section "## Aim".
po=$(profile override)
mkdir -p "$po/.claude/crew/items"
sed 's/^## Goal$/## Aim/' "$here/../../templates/item-task.md" > "$po/.claude/crew/items/task.md"
run "$po" -- task create --story 5 --title T --role agentic-ai-engineer --body-file "$(conforming_task t4f)"
refused "task create reads the required sections from the project's own task template" \
  'refused: section "## Aim" is missing'

# 5. AC 5 — a story missing a section and carrying a live placeholder gets one line per check.
s=$(conforming_story s5)
awk '/^## Out of scope$/{skip = 1} /^## Proof map$/{skip = 0} !skip' "$s" \
  | sed 's/^The design document for this release\./<other items, designs and provenance>/' > "$tmp/s5b.md"
run "$p" -- story create --title T --body-file "$tmp/s5b.md"
refused "story create refuses a missing section and a surviving placeholder, one line each" \
  'refused: section "## Out of scope" is missing' \
  'refused: unfilled template placeholder' '<other items, designs and provenance>'

# 5b. AC 5 — the criterion ids run 1..n, and the Proof map carries exactly one row per id. Renumbering
#     the second criterion to 3 breaks both at once, so both lines must come back.
sed 's/^2\. Given/3. Given/' "$(conforming_story s5c)" > "$tmp/s5c-gap.md"
run "$p" -- story create --title T --body-file "$tmp/s5c-gap.md"
refused "story create refuses a gap in the criterion ids and the Proof-map row it leaves missing" \
  'refused: criterion ids must run 1..n with no gap and no duplicate — expected 2, got 3' \
  'refused: ## Proof map has 0 rows for criterion 3, it needs exactly one'

# 6. D5 — the adapter writes the Blocked by: line whether or not the flag is given, so the presence
#    check is uniform and a story's first task is not refused for having no blocker.
run "$p" -- task create --story 5 --title T --role agentic-ai-engineer --body-file "$(conforming_task t6a)"
created "task create without --blocked-by writes Blocked by: none" "Blocked by: none"
run "$p" -- task create --story 5 --title T --role agentic-ai-engineer --blocked-by none --body-file "$(conforming_task t6b)"
created "task create --blocked-by none writes the same line" "Blocked by: none"
run "$p" -- task create --story 5 --title T --role agentic-ai-engineer --blocked-by "12,13" --body-file "$(conforming_task t6c)"
created "task create --blocked-by keeps the references" "Blocked by: #12, #13"

# The conforming bodies must pass untouched, or every refusal above proves nothing.
run "$p" -- task create --story 5 --title T --role agentic-ai-engineer --body-file "$(conforming_task t7)"
created "a conforming task body is created" "Story: #5"
run "$p" -- story create --title T --body-file "$(conforming_story s7)"
created "a conforming story body is created"

echo "tracker.sh lint, the claim warning and the severity labels"

# board_task <name> <Size: line> <files> <tests> <seam> -> the same body as it sits on the board, i.e.
# carrying the two header lines `task create` prepends. lint reads what the board holds, not a draft.
board_task() {
  local f; f=$(task_body "$@")
  { echo 'Story: #1'; echo 'Blocked by: none'; echo; cat "$f"; } > "$f.board"
  echo "$f.board"
}

# list_json <kind> <number>:<body file>... -> the canned `gh issue list --json` array for that label.
# Every item carries `state: "OPEN"`, which only `status` reads — `.state|ascii_downcase` on a missing
# field is a jq error, so an item without one fails a case for the wrong reason.
list_json() {
  local kind=$1 pair n f i=0 filter="["; local -a jqargs=(); shift
  for pair in "$@"; do
    n=${pair%%:*}; f=${pair#*:}; i=$((i + 1))
    jqargs+=(--rawfile "b$i" "$f")
    if [ "$i" -gt 1 ]; then filter+=","; fi
    filter+="{number:$n,state:\"OPEN\",labels:[{name:\"$kind\"}],body:\$b$i}"
  done
  jq -n "${jqargs[@]}" "$filter]" > "$lists/$kind.json"
}

# reported <name> <expected exit> <expected substring>... -> 0 when the exit code and every substring match
reported() {
  local name=$1 exp=$2 want; shift 2
  if [ "$rc" -ne "$exp" ]; then fail "$name" "expected exit $exp, got $rc; output: $out"; return 1; fi
  for want in "$@"; do
    case "$out" in *"$want"*) ;; *) fail "$name" "expected '$want' in the output, got: $out"; return 1 ;; esac
  done
  return 0
}

good=$(board_task L1 'Size: 2 hand-written files (+ 0 generated) · 1 RED tests · one PR' 2 1 'Split line: n/a')
badsize=$(board_task L2 'Size: about 25 files' 2 1 'Split line: n/a')
nogoal=$(board_task L3 'Size: 2 hand-written files (+ 0 generated) · 1 RED tests · one PR' 2 1 'Split line: n/a')
sed -i '/^## Goal$/d' "$nogoal"

# 7. AC 6 — one line per non-conforming item, the closing count, exit 1, and not one write: `lint` is a
#    report. `--quiet` drops the per-item lines and keeps the count, which is what /crew:status shows.
n1="lint names each failing check per item and exits 1"
list_json task "11:$good" "12:$badsize" "13:$nogoal"
run "$p" -- lint --kind task
if reported "$n1" 1 '#12' 'Size:' 'about 25 files' '#13' 'section "## Goal" is missing' '1 conforming, 2 not'; then
  if grep -aqE 'issue (edit|comment|create|close)|label create' "$ghlog"; then
    fail "$n1" "lint wrote to the board: $(grep -aE 'issue (edit|comment|create|close)|label create' "$ghlog" | head -1)"
  else
    run "$p" -- lint --kind task --quiet
    if [ "$rc" -ne 1 ]; then fail "$n1" "--quiet: expected exit 1, got $rc; output: $out"
    elif [ "$out" != "1 conforming, 2 not" ]; then fail "$n1" "--quiet must print the closing line alone, got: $out"
    else pass "$n1"; fi
  fi
fi

# 8. AC 6 — a conforming board prints the count and nothing else, and exits 0: the detector is quiet when
#    there is nothing to report, or nobody runs it unprompted.
n2="lint exits 0 and prints the count when every body conforms"
list_json task "11:$good" "14:$(board_task L4 'Size: 1 hand-written files (+ 0 generated) · 1 RED tests · one PR' 1 1 'Split line: n/a')"
run "$p" -- lint --kind task
if reported "$n2" 0 '2 conforming, 0 not'; then
  if [ "$out" != "2 conforming, 0 not" ]; then fail "$n2" "a conforming board needs no per-item line, got: $out"
  else pass "$n2"; fi
fi

# 9. AC 7, AC 11 — an item filed before this shape existed is still claimable: the lint lines come back as
#    warnings and the assign, the label and the comment all happen. Refusing here would strand every old item.
n3="claim prints the lint lines as warnings and still claims"
jq -n --rawfile b "$nogoal" '{a:[],l:["task"],s:"OPEN",b:$b}' > "$claimjson"
run "$p" -- claim 7
if reported "$n3" 0 'warning:' 'section "## Goal" is missing' 'claimed #7'; then
  if ! grep -aq -- '--add-assignee @me' "$ghlog"; then fail "$n3" "the assign never happened: $(cat "$ghlog")"
  elif ! grep -aq -- '--add-label in-progress' "$ghlog"; then fail "$n3" "the label never happened: $(cat "$ghlog")"
  elif ! grep -aq 'issue comment' "$ghlog"; then fail "$n3" "the claimed-by comment never happened: $(cat "$ghlog")"
  else pass "$n3"; fi
fi

# 10. D8 — severity is a label, and the obligation travels in the label's own description: a reviewer who
#     never opens the review step still reads what a p2 costs. GitHub caps that description at 100
#     characters, so the length is asserted here rather than discovered as a 422 against a real board.
n4="ensure-labels creates p1, p2 and p3"
d1='Blocks: always fixed before the change is offered; a finding needs its reproduction'
d2='Fix in this change if it caused or exposed it; else one line in the PR + its own item'
d3='Grouped into a planned task or its own item; never blocks'
labels_ok=1
check_label() { # <name> <colour> <description>
  local line
  line=$(grep -a -m1 "label create $1 " "$ghlog")
  if [ -z "$line" ]; then fail "$n4" "$1 was never created"; labels_ok=0; return; fi
  case "$line" in *"--color $2"*) ;; *) fail "$n4" "$1 has the wrong colour: $line"; labels_ok=0; return ;; esac
  case "$line" in *"--description $3"*) ;; *) fail "$n4" "$1 must carry its obligation: $line"; labels_ok=0; return ;; esac
  if [ ${#3} -gt 100 ]; then fail "$n4" "$1's description is ${#3} characters, GitHub caps it at 100"; labels_ok=0; fi
}
run "$p" -- ensure-labels
check_label p1 B60205 "$d1"
check_label p2 D93F0B "$d2"
check_label p3 FEF2C0 "$d3"
if [ "$labels_ok" = 1 ]; then pass "$n4"; fi

# 11. AC 11 — the shape a story has ON the board is not the shape it is created with: `task create`
#     appends the checklist under "## Tasks", so lint reading the create-time rule reports every story
#     with a task as broken. Found by running `lint --all` against the real board (#2 came back
#     non-conforming for carrying its own checklist). The create-time rule itself must stay.
n5="lint accepts a story whose ## Tasks the adapter has filled, and create still refuses one"
filled="$tmp/s-filled.md"
{ cat "$(conforming_story s11)"; echo; echo '- [ ] #3 (agentic-ai-engineer) do the thing'; } > "$filled"
list_json story "2:$filled"
run "$p" -- lint --kind story
if reported "$n5" 0 '1 conforming, 0 not'; then
  list_json story "2:$(conforming_story s11b)"
  run "$p" -- lint --kind story
  if ! reported "$n5" 0 '1 conforming, 0 not'; then :
  else
    run "$p" -- story create --title T --body-file "$filled"
    if [ "$rc" -ne 1 ]; then fail "$n5" "create must still refuse a filled ## Tasks, got exit $rc: $out"
    else pass "$n5"; fi
  fi
fi

# bug_body <name> [heading to drop] -> a bug body as the board holds it: every section the bug template
# names, filled, minus the one named. `bug` and `tech-debt` have no header contract, so the sections and
# the placeholder scan are the whole judgement and a dropped heading is the only failing check.
bug_body() {
  local name=$1 drop=${2:-} f="$tmp/$1.md"
  {
    echo 'Role: `agentic-ai-engineer` · design: none · found on the board, 2026-09-30'
    echo
    echo '## TL;DR'; echo
    echo 'Claiming an item filed before the checks existed refuses instead of warning.'; echo
    echo '## In one paragraph'; echo
    echo 'The claim read the body, found it off-shape and exited, which turned every old item into a'
    echo 'migration before any work could start.'; echo
    echo '## Evidence'; echo
    echo 'Claiming that item exits 3 and names no failing check.'; echo
    echo '## Expected'; echo
    echo 'The claim succeeds and the failing checks come back as warnings.'; echo
    echo '## Files'; echo
    echo '- `plugins/crew/scripts/tracker.sh` — the claim warns and still claims'; echo
    echo 'Size: 1 hand-written files (+ 0 generated) · one PR'; echo
    echo '## Tests (RED first)'; echo
    echo '1. **RED** the claim against an off-shape body still assigns, labels and comments.'; echo
    echo '## Done when'; echo
    echo '- the witness is run bare and its exit code quoted'
  } > "$f"
  [ -n "$drop" ] && sed -i "/^$drop\$/d" "$f"
  echo "$f"
}

# 12. D5 — one arm, two callers: a section that is present but blank is refused at create and reported by
#     `lint`, because both read the same `check_sections`. Replacing that arm's condition with `false`
#     left every case above green, which is why this one exists.
n6="a blank section is refused at create and reported by lint"
blankgoal=$(conforming_task L5)
sed -i '/^Validate the assembled body in task_create before the create call\.$/d' "$blankgoal"
boardblank="$blankgoal.board"
{ echo 'Story: #1'; echo 'Blocked by: none'; echo; cat "$blankgoal"; } > "$boardblank"
run "$p" -- task create --story 5 --title T --role agentic-ai-engineer --body-file "$blankgoal"
if reported "$n6" 1 'refused: section "## Goal" is empty'; then
  if [ -s "$ghlog" ]; then fail "$n6" "create reached the board anyway: $(head -1 "$ghlog")"
  else
    list_json task "15:$boardblank"
    run "$p" -- lint --kind task
    if reported "$n6" 1 '#15' 'section "## Goal" is empty' '0 conforming, 1 not'; then pass "$n6"; fi
  fi
fi

# 13. D5, AC 6 — `lint --all` walks four kinds, and the two with no header contract go through
#     `validate_plain_body`. Removing its `check_sections` call left every case above green, so one kind
#     holds the shared arm here: a conforming bug passes, and the same body minus one template heading
#     comes back with that heading named.
n7="lint judges a bug against its own template's sections"
list_json bug "20:$(bug_body B1)"
run "$p" -- lint --kind bug
if reported "$n7" 0 '1 conforming, 0 not'; then
  list_json bug "21:$(bug_body B2 '## Expected')"
  run "$p" -- lint --kind bug
  if reported "$n7" 1 '#21' 'bug' 'section "## Expected" is missing' '0 conforming, 1 not'; then pass "$n7"; fi
fi

# 14. D6 — `lint` takes one target. A number and a kind name two, and the parse used to keep the number
#     and drop the flag without a word, so a caller asking for a kind got one item's verdict instead.
n8="lint refuses a number and --kind together instead of ignoring one"
run "$p" -- lint 7 --kind task
if reported "$n8" 1 'lint takes' 'not both'; then
  if [ -s "$ghlog" ]; then fail "$n8" "the refusal still read the board: $(head -1 "$ghlog")"
  else pass "$n8"; fi
fi

# 15. The one command `/crew:work` step 1 and `/crew:plan` step 1 both open on. `--comments` does not add
#     the comments to the view, it replaces the view with them, so the role label, the `Blocked by` line and
#     `needs-refinement` — the three things those steps ask a lead to judge — were all absent from the
#     output. `show` prints the item first and the comments after it, in one pass a reader scrolls.
n9="show prints the item and its comments, in that order, not the comments alone"
{
  printf 'title:\tfix(tracker): show prints the item, not only its comments\n'
  printf 'state:\tOPEN\n'
  printf 'labels:\tbug, needs-refinement, role:agentic-ai-engineer\n'
  printf 'comments:\t1\n'
  printf -- '--\n'
  printf 'Story: #7\n'
  printf 'Blocked by: none\n\n'
  printf '## TL;DR\n\nThe body a lead has to read before claiming anything.\n'
} > "$viewfile"
{
  printf 'author:\tmike-echo-oscar-whiskey\n'
  printf -- '--\n'
  printf 'claimed-by: hanuman at 2026-10-01T08:12:24+02:00\n'
} > "$commentsfile"
show_view=$viewfile show_comments=$commentsfile
run "$p" -- show 12
if reported "$n9" 0 'title:' 'OPEN' 'needs-refinement' 'role:agentic-ai-engineer' \
     'Story: #7' 'Blocked by: none' '## TL;DR' 'The body a lead has to read' 'claimed-by: hanuman' \
     '--- comments ---'; then
  bline=$(printf '%s\n' "$out" | grep -n 'Story: #7' | head -1 | cut -d: -f1)
  cline=$(printf '%s\n' "$out" | grep -n 'claimed-by: hanuman' | head -1 | cut -d: -f1)
  if [ "${bline:-0}" -ge "${cline:-0}" ]; then
    fail "$n9" "the comments must follow the body: body at line ${bline:-none}, comment at ${cline:-none}"
  elif grep -aqE 'issue (edit|comment|create|close)' "$ghlog"; then
    fail "$n9" "show wrote to the board: $(grep -aE 'issue (edit|comment|create|close)' "$ghlog" | head -1)"
  else pass "$n9"; fi
fi

# 16. The commentless item — the state most freshly filed tasks are in. The second read answers nothing,
#     so the whole output has to be the item plus the separator that says where the comments would have
#     been: a reader who sees the separator with nothing under it knows there are none, rather than
#     wondering whether the command stopped early.
n10="show prints the item and an empty comment stream when the item has no comments"
show_view=$viewfile show_comments=""
run "$p" -- show 12
if reported "$n10" 0 'title:' 'OPEN' 'needs-refinement' 'Story: #7' '## TL;DR' '--- comments ---'; then
  last=$(printf '%s\n' "$out" | grep -v '^[[:space:]]*$' | tail -1)
  if [ "$last" != '--- comments ---' ]; then
    fail "$n10" "the separator must be the last line when there are no comments, got: $last"
  elif printf '%s\n' "$out" | grep -q 'claimed-by: hanuman'; then
    fail "$n10" "a comment from an earlier case leaked into the commentless output"
  elif grep -aqE 'issue (edit|comment|create|close)' "$ghlog"; then
    fail "$n10" "show wrote to the board: $(grep -aE 'issue (edit|comment|create|close)' "$ghlog" | head -1)"
  else pass "$n10"; fi
fi

# 17. The transition the board had no word for. `claim` adds `in-progress`, nothing took it off at the end,
#     and five closed items carried it at once while `status` counted them as work in flight. `--to done`
#     removes every lane label the item carries and closes it in one act, and it KEEPS the assignee: who
#     finished the work is the one thing a closed item should still record. Dropping any one label from the
#     removal, or taking the assignee off, is the accident this case exists to catch.
n11="release --to done removes every lane label, closes the item and keeps the assignee"
lane_labels="$tmp/lanes-all.json"
jq -n '["task","in-progress","in-review","blocked","role:agentic-ai-engineer"]' > "$lane_labels"
run "$p" -- release 13 --to done
if reported "$n11" 0 'released #13 -> done'; then
  edit=$(grep -a -m1 'issue edit' "$ghlog" || true)
  missing=""
  for l in in-progress in-review blocked; do
    case "$edit" in *"--remove-label $l"*) ;; *) missing="$missing $l" ;; esac
  done
  if [ -n "$missing" ]; then fail "$n11" "these lane labels survived the transition:$missing (edit: ${edit:-none})"
  elif ! grep -aq 'issue close 13' "$ghlog"; then fail "$n11" "the item was never closed: $(cat "$ghlog")"
  elif grep -aq -- '--remove-assignee' "$ghlog"; then
    fail "$n11" "the assignee must stay as the record of who did the work: $(grep -a -- '--remove-assignee' "$ghlog" | head -1)"
  else pass "$n11"; fi
fi

# 18. The ordinary finish: an item in review carries one lane label. The transition removes that one and
#     names neither of the other two, because `gh issue edit --remove-label` fails whole on a label the
#     item does not carry — the same reason `claim` keeps a fallback — and a failed edit would leave a
#     closed item wearing its lane label, which is the bug all over again.
n12="release --to done removes only the lane labels the item carries"
lane_labels="$tmp/lanes-review.json"; jq -n '["task","in-review"]' > "$lane_labels"
run "$p" -- release 13 --to done
if reported "$n12" 0 'released #13 -> done'; then
  edit=$(grep -a -m1 'issue edit' "$ghlog" || true)
  if ! grep -aq 'issue close 13' "$ghlog"; then fail "$n12" "the item was never closed: $(cat "$ghlog")"
  elif ! grep -aq -- '--remove-label in-review' <<<"$edit"; then fail "$n12" "in-review survived: ${edit:-none}"
  elif grep -aqE -- '--remove-label (in-progress|blocked)' <<<"$edit"; then
    fail "$n12" "the edit names a label the item does not carry, and GitHub fails it whole: $edit"
  else pass "$n12"; fi
fi

# 19. #14 — `gh issue list --limit N` is an exact cap and gh stops there, so a kind holding more items than
#     the cap comes back full and the remainder is never fetched, never judged and — until this case — never
#     mentioned: the closing line read `3 conforming, 0 not` and the exit said 0, which is exactly what a
#     clean board prints. A fetch that comes back full is the only signal there is, so it is the one the
#     report turns into words and a non-zero exit; a fetch under the cap read the kind whole and says
#     nothing extra, which is the second arm here.
#
#     The first arm cans **four** items against a cap of 3 and asserts `3 conforming`, which is one
#     assertion pinning the cap to both places it is used: the stub truncates to the limit it was handed,
#     so a fetch that passes any other number returns a count the comparison then judges against the
#     cap — four items read whole say `4 conforming` and exit 0, a cap of 500 on the fetch returns four
#     and `4 -ge 3` still saturates but the count is wrong. Only the shipped pairing prints 3 and exits 2.
n13="lint says the limit was hit instead of reporting a partial read as a whole board"
list_json task "31:$good" "32:$good" "33:$good" "34:$good"
lint_limit=3
run "$p" -- lint --kind task
if reported "$n13" 2 '3 conforming, 0 not' 'task' '3-item limit' 'not judged'; then
  if grep -aqE 'issue (edit|comment|create|close)|label create' "$ghlog"; then
    fail "$n13" "lint wrote to the board: $(grep -aE 'issue (edit|comment|create|close)|label create' "$ghlog" | head -1)"
  else
    list_json task "31:$good" "32:$good"
    lint_limit=3
    run "$p" -- lint --kind task
    if [ "$rc" -ne 0 ]; then fail "$n13" "a fetch under the cap read the kind whole: expected exit 0, got $rc; output: $out"
    elif [ "$out" != "2 conforming, 0 not" ]; then fail "$n13" "an unsaturated read must print the count alone, got: $out"
    else pass "$n13"; fi
  fi
fi

# 20. #16 — the same exact cap as #19, in the command a lead reads first. `next` asked for one page of open
#     tasks and offered the claimable ones from whatever came back, so past the cap a task was never
#     offered and nothing looked wrong: silence is the whole symptom. Unlike `lint`, `next` is not a
#     reporter — the rows it printed are real and claimable — so a full fetch keeps exit 0 and the rows,
#     and says on stderr that there are more. Four items against a cap of 3 pins the cap to both places
#     it is used at once: a fetch passing any other number returns a count the comparison then judges
#     against the cap, and #44 appearing proves the limit never reached `gh`.
n14="next says the open-task fetch filled its limit instead of offering a partial board as the whole one"
list_json task "41:$good" "42:$good" "43:$good" "44:$good"
board_limit=3
run "$p" -- next
if reported "$n14" 0 '#41' '#42' '#43' 'open-task fetch filled its 3-item limit' 'not offered'; then
  if printf '%s\n' "$out" | grep -q '#44'; then
    fail "$n14" "the fetch read past the limit it passed, so no case can see that limit: $out"
  elif grep -aqE 'issue (edit|comment|create|close)|label create' "$ghlog"; then
    fail "$n14" "next wrote to the board: $(grep -aE 'issue (edit|comment|create|close)|label create' "$ghlog" | head -1)"
  else
    list_json task "41:$good" "42:$good"
    board_limit=3
    run "$p" -- next
    if [ "$rc" -ne 0 ]; then fail "$n14" "a fetch under the cap read the label whole: expected exit 0, got $rc; output: $out"
    elif printf '%s\n' "$out" | grep -q 'filled its'; then
      fail "$n14" "an unsaturated fetch must add nothing to the rows, got: $out"
    else pass "$n14"; fi
  fi
fi

# 21. #16 — `status` makes two fetches and each can fill on its own, so each is judged on its own and
#     named for what it costs. The rollup filling makes a story read as further from done than it is, and
#     a count that is a lower bound must not print as a count. The story fetch here reads whole, so its
#     line must be absent: a saturation line that fires for the wrong fetch is the same silence inverted.
n15="status says the task rollup filled its limit instead of printing a story as further from done"
list_json task "51:$good" "52:$good" "53:$good" "54:$good"
list_json story "1:$good"
board_limit=3
run "$p" -- status
if reported "$n15" 0 '#1' 'tasks 0/3 done' 'task-rollup fetch filled its 3-item limit' 'lower bound'; then
  if printf '%s\n' "$out" | grep -q 'open-story fetch filled'; then
    fail "$n15" "the story fetch read its label whole and must not be reported as partial: $out"
  elif grep -aqE 'issue (edit|comment|create|close)|label create' "$ghlog"; then
    fail "$n15" "status wrote to the board: $(grep -aE 'issue (edit|comment|create|close)|label create' "$ghlog" | head -1)"
  else
    list_json task "51:$good" "52:$good"; list_json story "1:$good"
    board_limit=3
    run "$p" -- status
    if [ "$rc" -ne 0 ]; then fail "$n15" "two fetches under the cap read both labels whole: expected exit 0, got $rc; output: $out"
    elif printf '%s\n' "$out" | grep -q 'filled its'; then
      fail "$n15" "an unsaturated board must print the rollup alone, got: $out"
    else pass "$n15"; fi
  fi
fi

# 22. #16 — the other half of `status`: the story fetch filling drops a story off the board entirely, which
#     is the one of the three failures a lead cannot even infer from what is printed. The rollup reads
#     whole here, so its line must be absent, and #4 must not appear: the cap has to have reached `gh`.
n16="status says the open-story fetch filled its limit instead of dropping a story off the board"
list_json task "61:$good"
list_json story "1:$good" "2:$good" "3:$good" "4:$good"
board_limit=3
run "$p" -- status
if reported "$n16" 0 '#1' '#2' '#3' 'open-story fetch filled its 3-item limit' 'absent from this board'; then
  if printf '%s\n' "$out" | grep -q '^#4 '; then
    fail "$n16" "the story fetch read past the limit it passed, so no case can see that limit: $out"
  elif printf '%s\n' "$out" | grep -q 'task-rollup fetch filled'; then
    fail "$n16" "the task fetch read its label whole and must not be reported as partial: $out"
  elif grep -aqE 'issue (edit|comment|create|close)|label create' "$ghlog"; then
    fail "$n16" "status wrote to the board: $(grep -aE 'issue (edit|comment|create|close)|label create' "$ghlog" | head -1)"
  else pass "$n16"; fi
fi

# 23. #16 — the one property the whole design rests on, and the one no case above can see: `run` captures
#     `2>&1`, so a warning printed to stdout reads there exactly as a warning printed to stderr does.
#     Both skills parse stdout — `/crew:next --auto` starts work on the first row of the table, and
#     `/crew:status` presents the table unchanged — so a warning on stdout is read as a row, which is why
#     the channel is the fix and not an incidental of it. `run_split` keeps the two apart here: stdout must
#     hold the rows and nothing else, stderr must hold the warning. `status` is asserted as well as `next`
#     because two of the three warnings are its, and the rows it hands the skill are the whole output.
n17="the saturation warning goes to stderr and leaves stdout holding rows alone"
list_json task "71:$good" "72:$good" "73:$good" "74:$good"
board_limit=3
run_split "$p" -- next
err=$(cat "$errfile")
if [ "$rc" -ne 0 ]; then fail "$n17" "expected exit 0 from next, got $rc; stdout: $out"
elif printf '%s\n' "$out" | grep -q 'filled its'; then
  fail "$n17" "the warning reached the stdout --auto reads as its first claimable row: $out"
elif ! printf '%s\n' "$err" | grep -q 'open-task fetch filled its 3-item limit'; then
  fail "$n17" "stderr never carried the warning, so the fetch filled in silence: ${err:-empty}"
elif ! printf '%s\n' "$out" | grep -q '#71'; then
  fail "$n17" "stdout lost the rows the warning only qualifies: ${out:-empty}"
else
  list_json task "81:$good" "82:$good" "83:$good" "84:$good"
  list_json story "1:$good" "2:$good" "3:$good" "4:$good"
  board_limit=3
  run_split "$p" -- status
  err=$(cat "$errfile")
  if [ "$rc" -ne 0 ]; then fail "$n17" "expected exit 0 from status, got $rc; stdout: $out"
  elif printf '%s\n' "$out" | grep -q 'filled its'; then
    fail "$n17" "a status warning reached the stdout the skill presents unchanged: $out"
  elif ! printf '%s\n' "$err" | grep -q 'task-rollup fetch filled its 3-item limit'; then
    fail "$n17" "stderr never carried the rollup warning: ${err:-empty}"
  elif ! printf '%s\n' "$err" | grep -q 'open-story fetch filled its 3-item limit'; then
    fail "$n17" "stderr never carried the story warning: ${err:-empty}"
  else pass "$n17"; fi
fi

# 24. #16 and #14 — the numeric guard under both caps, which nothing else observes because its failure mode
#     is the silence of a healthy board. A non-numeric limit reaches `[ 4 -ge abc ]`, which exits 2 with
#     "integer expression expected": `|| return 0` in `board_saturated` and `if` in `lint` both read that
#     as "not saturated", so the saturation check switches itself off, and the fetch asks `gh` for
#     `--limit abc` as well. What the fallback is therefore asserted by is the number that reached `gh` and
#     a stderr with nothing on it — a complete read, judged against a cap that is still 2000.
#
#     One case, both guards: `BOARD_LIMIT` through `next` and `LINT_LIMIT` through `lint`. The two are
#     separate copies of the same three lines, each read by only its own commands, so a case touching one
#     command would leave the other copy exactly as unobserved as it was.
n18="a non-numeric fetch limit falls back to the shipped 2000 instead of switching the check off"
list_json task "91:$good" "92:$good" "93:$good" "94:$good"
board_limit=abc
run_split "$p" -- next
err=$(cat "$errfile")
if ! grep -aq -e '--limit 2000' "$ghlog"; then
  fail "$n18" "the open-task fetch passed the unusable limit straight to gh: $(head -1 "$ghlog")"
elif [ "$rc" -ne 0 ]; then fail "$n18" "expected exit 0 from next, got $rc; stdout: ${out:-empty}"
elif [ -n "$err" ]; then
  fail "$n18" "the comparison ran against a non-number: $err"
elif ! printf '%s\n' "$out" | grep -q '#94'; then
  fail "$n18" "the default cap did not govern the fetch, so the board came back short: ${out:-empty}"
elif printf '%s\n' "$out" | grep -q 'filled its'; then
  fail "$n18" "four items under a cap of 2000 is not a filled fetch: $out"
else
  list_json task "91:$good" "92:$good" "93:$good"
  lint_limit=abc
  run_split "$p" -- lint --kind task
  err=$(cat "$errfile")
  if ! grep -aq -e '--limit 2000' "$ghlog"; then
    fail "$n18" "the lint fetch passed the unusable limit straight to gh: $(head -1 "$ghlog")"
  elif [ "$rc" -ne 0 ]; then fail "$n18" "expected exit 0 from lint, got $rc; stdout: ${out:-empty}"
  elif [ -n "$err" ]; then
    fail "$n18" "the lint comparison ran against a non-number: $err"
  elif [ "$out" != "3 conforming, 0 not" ]; then
    fail "$n18" "a complete read under the default cap must print the count alone, got: ${out:-empty}"
  else pass "$n18"; fi
fi

if [ "$fails" -eq 0 ]; then echo "PASS"; exit 0; fi
echo "FAIL ($fails)"; exit 1
