#!/usr/bin/env bash
# Witness for tracker.sh's create-time item checks: canned bodies in, one `refused:` line per
# failing check out, and a stub `gh` that proves nothing reached the board. Run it bare:
#   bash tests/tracker.test.sh
# Exits 0 when every case passes, 1 on the first failure, and names the case either way.
set -u

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/.." && pwd)
crew="$root/plugins/crew"
sut="$crew/scripts/tracker.sh"
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
  case "$a" in number=*) num=${a#number=} ;; esac       # `api graphql -F number=N`, as `conformed` reads
  prev=$a
done
case "$*" in
  *"api graphql"*)
    # One canned GraphQL response per issue number; a number with none answers as the API does when the
    # call fails — an error on stderr and a non-zero exit — which is how a case reaches "cannot decide".
    f="${CREW_GH_LIST_DIR:-/nonexistent}/gql-$num.json"
    if [ -f "$f" ]; then cat "$f"; else echo "GraphQL: Could not resolve to an Issue with the number of $num." >&2; exit 1; fi ;;
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

# refused_q <name> <expected substring>...  -> exit 1, every substring present, no gh call at all, and
# nothing printed when the run conforms: several bodies then stand under one case name and the caller
# passes once, at the end. `refused` is this plus the pass line, which is what a one-body case wants.
refused_q() {
  local name=$1 want; shift
  if [ "$rc" -ne 1 ]; then fail "$name" "expected exit 1, got $rc; output: $out"; return 1; fi
  for want in "$@"; do
    case "$out" in *"$want"*) ;; *) fail "$name" "expected '$want' in the refusal, got: $out"; return 1 ;; esac
  done
  if [ -s "$ghlog" ]; then fail "$name" "gh was called: $(head -1 "$ghlog")"; return 1; fi
  return 0
}

# refused <name> <expected substring>... -> the same judgement, with the case's pass line
refused() { refused_q "$@" && pass "$1"; }

# created_q <name> [expected body substring]... -> exit 0, number printed, gh asked to create with the
# kind label the board filters on (`status` and `next` select tasks by `task` and read the role label).
# Silent on success, for the reason `refused_q` is.
created_q() {
  local name=$1 want cmd; shift
  if [ "$rc" -ne 0 ]; then fail "$name" "expected exit 0, got $rc; output: $out"; return 1; fi
  case "$out" in *99*) ;; *) fail "$name" "expected the new number on stdout, got: $out"; return 1 ;; esac
  cmd=$(grep -a -m1 "issue create" "$ghlog")
  if [ -z "$cmd" ]; then fail "$name" "gh was never asked to create"; return 1; fi
  case "$cmd" in
    *'--label story'*|*'--label task --label role:'*) ;;
    *) fail "$name" "the create command carries no kind label: $cmd"; return 1 ;;
  esac
  for want in "$@"; do
    case "$(cat "$ghbody")" in *"$want"*) ;; *) fail "$name" "expected '$want' in the created body"; return 1 ;; esac
  done
  return 0
}

# created <name> [expected body substring]... -> the same judgement, with the case's pass line
created() { created_q "$@" && pass "$1"; }

echo "tracker.sh create-time checks"

p=$(profile plain)
pc=$(profile capped "size-cap: 15")

# 1. AC 2 — the check that retires the eighteen-invisible-tasks class. A caller who writes the
#    sigil into --story (every body says "#5") makes the adapter assemble "Story: ##5", which
#    status() rolls up by startswith and next() greps for; the board loses the task silently.
run "$p" -- task create --story '#5' --title T --role agentic-ai-engineer --body-file "$(conforming_task t1)"
refused "task create refuses a body whose first line is not Story: #n" \
  'refused: first line must be "Story: #5"' 'got "Story: ##5"'

# 1b. A body file that opens with the header — what a lead gets by filing the template's own lines
#     back — made the stored body carry Story:/Blocked by: twice, and every reader took the first copy.
hdr="$tmp/t1b-header.md"; { echo 'Story: #5'; echo 'Blocked by: #3'; echo; cat "$(conforming_task t1b)"; } > "$hdr"
run "$p" -- task create --story 5 --title T --role agentic-ai-engineer --body-file "$hdr"
refused "task create refuses a body file that carries its own Story: and Blocked by: lines" \
  'refused: exactly one "Story:" line' 'a --body-file carries no header' '--story' '--blocked-by'

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

# 3e. AC 3 — the ceiling switched off is not the checks switched off. `size-cap: -` licenses any count and
#     nothing else: a body that states no size, one whose size cannot be read as a number, and one whose
#     number disagrees with its own `## Files` list are each still refused. The nearest case above covers a
#     cap the profile cannot *mean*, which falls back to 15 and leaves the comparison running — a different
#     branch. The last arm is what makes this case about the ceiling rather than about any profile: twenty
#     files, which the default cap refuses, are accepted here, so a `-` that reached the comparison instead
#     of disabling it would fail the case rather than collect three refusals for free.
n_capoff="the size checks hold with the ceiling switched off"
pco=$(profile capped-off "size-cap: -")
capoff_ok=1
run "$pco" -- task create --story 5 --title T --role agentic-ai-engineer \
  --body-file "$(task_body t3f '' 2 1 'Split line: n/a')"
refused_q "$n_capoff" 'refused: the "Size:" line is missing' || capoff_ok=0
run "$pco" -- task create --story 5 --title T --role agentic-ai-engineer \
  --body-file "$(task_body t3g 'Size: roughly a dozen' 2 1 'Split line: n/a')"
refused_q "$n_capoff" 'refused: Size: must read' 'got "Size: roughly a dozen"' || capoff_ok=0
run "$pco" -- task create --story 5 --title T --role agentic-ai-engineer \
  --body-file "$(task_body t3h 'Size: 2 hand-written files (+ 0 generated) · 1 RED tests · one PR' 3 1 'Split line: n/a')"
refused_q "$n_capoff" 'refused: ## Files lists 3 files, Size: says 2' || capoff_ok=0
run "$pco" -- task create --story 5 --title T --role agentic-ai-engineer \
  --body-file "$(task_body t3i "$over" 20 1 'Split line: files 13-20 go to the follow-up')"
created_q "$n_capoff" || capoff_ok=0
if [ "$capoff_ok" = 1 ]; then pass "$n_capoff"; fi

# 3f. AC 4 — the licence is a sentence, not a flag: the over-cap body is accepted *and* the reason it was
#     accepted for is in the stored body, where the next reader of the item finds it. The arm above asserts
#     only that such a body is created, which an adapter dropping the line would pass just as well.
n_exc="an accepted Exception: body keeps its reason in the stored body"
exc='Exception: one mechanical rename — 20 files, no behaviour change; reviewed as one sweep.'
run "$pc" -- task create --story 5 --title T --role agentic-ai-engineer \
  --body-file "$(task_body t3j "$over" 20 1 "$exc")"
created "$n_exc" "$exc"

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
sed 's/^## Goal$/## Aim/' "$crew/templates/item-task.md" > "$po/.claude/crew/items/task.md"
run "$po" -- task create --story 5 --title T --role agentic-ai-engineer --body-file "$(conforming_task t4f)"
refused "task create reads the required sections from the project's own task template" \
  'refused: section "## Aim" is missing'

# 4f. AC 10 — the fallback when a profile declares no `generated:` paths at all: there is nothing to
#     exclude, so every bullet in `## Files` counts toward H. This is the body 4b accepts under
#     `generated: gen/*.json` — one hand-written bullet, one generated — and the only difference here is the
#     absent profile key, so a default that quietly excluded anything would let this body through while 4b
#     stayed green. The premise is asserted first: a case that silently stopped testing the absent key
#     because `profile` grew a default would otherwise keep passing.
n_nogen="with no generated: paths declared, every file in ## Files counts toward the size"
png=$(profile no-generated)
ng=$(task_body t4g 'Size: 1 hand-written files (+ 1 generated) · 1 RED tests · one PR' 1 1 'Split line: n/a')
sed -i '/^- `plugins\/crew\/scripts\/f1.sh`/a - `gen/b.json` — generated, and no profile key says so' "$ng"
if grep -q '^generated:' "$png/.claude/crew/profile.md"; then
  fail "$n_nogen" "the profile declares generated: paths, so this case is asserting the other branch"
else
  run "$png" -- task create --story 5 --title T --role agentic-ai-engineer --body-file "$ng"
  refused "$n_nogen" 'refused: ## Files lists 2 files, Size: says 1'
fi

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

# 6b. AC 5 — the other half of the criterion: what the board ends up holding. The adapter owns two writes
#     and no more — the two header lines it prepends to the task, and the one checklist line it appends to
#     the story — so the submitted body has to come back out of the stored one, byte for byte, once those
#     two lines and their blank are taken off. A write that reformatted, re-ordered or dropped a section
#     would leave every refusal above intact and still lose the body a role wrote, and a second checklist
#     line would make the story's rollup count the task twice.
n_stored="a stored body keeps every section it was submitted with, and the adapter's two writes are correct"
src=$(conforming_task t8)
run "$p" -- task create --story 5 --title 'the stored body' --role agentic-ai-engineer \
  --blocked-by "12,13" --body-file "$src"
if created_q "$n_stored"; then
  rest="$tmp/stored-rest.md"; tail -n +4 "$ghbody" > "$rest"
  missing=""
  while IFS= read -r sec; do
    grep -aqxF "$sec" "$ghbody" || missing="$missing $sec"
  done < <(grep -aE '^## ' "$src")
  ticks=$(grep -ac -- '^- \[ \] #99 (agentic-ai-engineer) the stored body$' "$ghlog" || true)
  if [ "$(sed -n 1p "$ghbody")" != 'Story: #5' ]; then
    fail "$n_stored" "the first stored line must be the rollup line, got: $(sed -n 1p "$ghbody")"
  elif [ "$(sed -n 2p "$ghbody")" != 'Blocked by: #12, #13' ]; then
    fail "$n_stored" "the second stored line must carry the blockers, got: $(sed -n 2p "$ghbody")"
  elif [ -n "$(sed -n 3p "$ghbody")" ]; then
    fail "$n_stored" "a blank line separates the two header lines from the body, got: $(sed -n 3p "$ghbody")"
  elif [ -n "$missing" ]; then
    fail "$n_stored" "these submitted sections are not in the stored body:$missing"
  elif ! diff -q "$src" "$rest" >/dev/null; then
    fail "$n_stored" "under those two lines the stored body is not the submitted one: $(diff "$src" "$rest" | head -4 | tr '\n' ' ')"
  elif ! grep -aq 'issue edit 5 --body' "$ghlog"; then
    fail "$n_stored" "the story's checklist was never written: $(cat "$ghlog")"
  elif [ "$ticks" != 1 ]; then
    fail "$n_stored" "the story gets exactly one checklist line for the new task, got $ticks"
  else pass "$n_stored"; fi
fi

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

# 8b. The eleven bodies already on a board with the header twice: lint reports them by the same rule
#     create refuses with, so create and lint cannot disagree about what a header is.
n2b="lint reports a stored body that carries the Story: and Blocked by: header twice"
dup="$tmp/dup.board"; { echo 'Story: #1'; echo 'Blocked by: none'; echo; cat "$good"; } > "$dup"
list_json task "11:$good" "15:$dup"
run "$p" -- lint --kind task
reported "$n2b" 1 '#15' 'exactly one "Story:" line' 'exactly one "Blocked by:" line' '1 conforming, 1 not' && pass "$n2b"

# 9. AC 7, AC 11 — an item filed before this shape existed is still claimable, and the four clauses an
#    upgrading project is owed are each asserted by name: the claim succeeds, the failing checks come back
#    as warnings, nothing on the board is rewritten, and only a body written after the upgrade is refused.
#    The third is the one a passing claim hides: the claim's own assign, label and comment must happen while
#    no edit carries a `--body`, which is how an upgrade that "fixed" the body on the way through would be
#    caught. The fourth is the same off-shape body offered to `task create`, which must refuse it — without
#    that arm, a claim that warned and a create that also only warned would read identically here.
#    Refusing at claim would strand every item already on the board.
n3="claiming an item filed before the upgrade warns, succeeds, edits nothing and refuses only newer bodies"
jq -n --rawfile b "$nogoal" '{a:[],l:["task"],s:"OPEN",b:$b}' > "$claimjson"
run "$p" -- claim 7
if reported "$n3" 0 'warning:' 'section "## Goal" is missing' 'claimed #7'; then
  if ! grep -aq -- '--add-assignee @me' "$ghlog"; then fail "$n3" "the assign never happened: $(cat "$ghlog")"
  elif ! grep -aq -- '--add-label in-progress' "$ghlog"; then fail "$n3" "the label never happened: $(cat "$ghlog")"
  elif ! grep -aq 'issue comment' "$ghlog"; then fail "$n3" "the claimed-by comment never happened: $(cat "$ghlog")"
  elif grep -aqE 'issue edit [0-9]+ .*--body' "$ghlog"; then
    fail "$n3" "the claim rewrote the body on the board: $(grep -aE 'issue edit [0-9]+ .*--body' "$ghlog" | head -1)"
  else
    olddraft=$(conforming_task C9); sed -i '/^## Goal$/d' "$olddraft"
    run "$p" -- task create --story 5 --title T --role agentic-ai-engineer --body-file "$olddraft"
    refused "$n3" 'refused: section "## Goal" is missing'
  fi
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

# 25. AC 5, #21 — `bug create`, the first of the two kinds the adapter could not create at all, so for half
#     the kinds there was no creation to refuse at and a lead reached for `gh issue create` instead. The
#     shape carries no header contract — `validate_plain_body` is the whole judgement — so a missing section
#     is the refusal to assert, by name, with nothing reaching the board.
run "$p" -- bug create --title 'the probe' --body-file "$(bug_body C1 '## Evidence')"
refused "bug create refuses a body missing a required section" \
  'refused: section "## Evidence" is missing'

# 26. AC 5, #21 — the same for `tech-debt`, which needs its own case rather than sharing case 25's: the two
#     templates name different sections, so a body conforming for one kind is refused for every section of
#     the other, and one case over both would pass on an arm that read the wrong template.
#
# tech_debt_body <name> [heading to drop] -> a tech-debt body carrying every section its template names,
# filled, minus the one named. Shaped like `bug_body`, and for the same reason: the sections and the
# placeholder scan are the whole judgement, so a dropped heading is the only failing check.
tech_debt_body() {
  local name=$1 drop=${2:-} f="$tmp/$1.md"
  {
    echo 'Found in: the witness for criterion 5 · pre-existing since the adapter was written'
    echo
    echo '## TL;DR'; echo
    echo 'Two of the four item kinds cannot be created through the adapter, so their bodies are never'
    echo 'checked and an item conforms only if whoever filed it was careful.'; echo
    echo '## In one paragraph'; echo
    echo 'The dispatch has an arm per kind for two of the four, and the validator written for the other'
    echo 'two is never reached from anywhere.'; echo
    echo '## Cost'; echo
    echo 'Every bug item on this board was filed with raw gh, so none of them was judged against its own'
    echo 'shape before it landed.'; echo
    echo '## Way out'; echo
    echo 'Give the two kinds the create arm the other two already have.'; echo
    echo '## Trigger'; echo
    echo 'The next item filed for either kind.'
  } > "$f"
  [ -n "$drop" ] && sed -i "/^$drop\$/d" "$f"
  echo "$f"
}
run "$p" -- tech-debt create --title 'the probe' --body-file "$(tech_debt_body C2 '## Trigger')"
refused "tech-debt create refuses a body missing a required section" \
  'refused: section "## Trigger" is missing'

# 27. AC 5, #21 — the conforming half of both arms: exit 0, the number on stdout, the kind label on the
#     create call, and the submitted body stored as it was handed in. Neither kind has a header the adapter
#     writes, so there is nothing to subtract from the stored body and a section from the middle of each is
#     what proves it survived. The kind label is asserted here and not through `created_q`, whose label test
#     is a family of patterns: a create that applied `task` to a bug would satisfy that test and lose the
#     label `lint --kind` and the board's own filters read the shape off.
n_plain="bug create and tech-debt create store a conforming body under the kind label"
plain_ok=1
plain_created() { # <case name> <kind label> <expected body substring>
  local name=$1 kind=$2 want=$3 cmd
  if [ "$rc" -ne 0 ]; then fail "$name" "expected exit 0 from $kind create, got $rc; output: $out"; return 1; fi
  case "$out" in *99*) ;; *) fail "$name" "expected the new number on stdout, got: $out"; return 1 ;; esac
  cmd=$(grep -a -m1 "issue create" "$ghlog")
  if [ -z "$cmd" ]; then fail "$name" "gh was never asked to create a $kind"; return 1; fi
  case "$cmd" in *"--label $kind"*) ;; *) fail "$name" "the create command carries no $kind label: $cmd"; return 1 ;; esac
  case "$(cat "$ghbody")" in *"$want"*) ;; *) fail "$name" "expected '$want' in the created $kind body"; return 1 ;; esac
  return 0
}
run "$p" -- bug create --title 'the probe' --body-file "$(bug_body C3)"
plain_created "$n_plain" bug 'The claim succeeds and the failing checks come back as warnings.' || plain_ok=0
run "$p" -- tech-debt create --title 'the probe' --body-file "$(tech_debt_body C4)"
plain_created "$n_plain" tech-debt 'Give the two kinds the create arm the other two already have.' || plain_ok=0
if [ "$plain_ok" = 1 ]; then pass "$n_plain"; fi

# 28. #21 — `KINDS` judges four kinds and `ensure-labels` minted two of their labels, so `lint --kind
#     tech-debt` named a kind nothing on a fresh board could carry. `bug` exists on this board only because
#     GitHub creates it in every new repository; a consumer of the plugin would have neither. Colour,
#     description and `--force` are asserted because that is how every other label here is minted, and
#     GitHub caps a description at 100 characters — a 422 against a real board otherwise.
n_kinds="ensure-labels mints the bug and tech-debt kind labels"
dbug='Reported defect in behaviour that shipped (crew pipeline)'
ddebt='Debt carried deliberately; its severity is a p1/p2/p3 label'
kinds_ok=1
check_kind_label() { # <name> <colour> <description>
  local line
  line=$(grep -a -m1 "label create $1 " "$ghlog")
  if [ -z "$line" ]; then fail "$n_kinds" "$1 was never created"; kinds_ok=0; return; fi
  case "$line" in *"--color $2"*) ;; *) fail "$n_kinds" "$1 has the wrong colour: $line"; kinds_ok=0; return ;; esac
  case "$line" in *"--description $3"*) ;; *) fail "$n_kinds" "$1 carries the wrong description: $line"; kinds_ok=0; return ;; esac
  case "$line" in *--force*) ;; *) fail "$n_kinds" "$1 is not minted with --force, so a re-run fails: $line"; kinds_ok=0; return ;; esac
  if [ ${#3} -gt 100 ]; then fail "$n_kinds" "$1's description is ${#3} characters, GitHub caps it at 100"; kinds_ok=0; fi
}
run "$p" -- ensure-labels
check_kind_label bug D73A4A "$dbug"
check_kind_label tech-debt 8D6E63 "$ddebt"
if [ "$kinds_ok" = 1 ]; then pass "$n_kinds"; fi

# 29. AC 5 — the clause of the criterion that belongs to `task` alone: `## Proves` is the only line tying a
#     task to the criteria it closes, and a section that names the story but no criterion leaves the story's
#     Proof map unfillable while every other check passes. `tracker.sh:226` has refused it since the
#     validator was written and nothing asserted it, so a rewrite that dropped the `AC <n>` test — or an
#     `## Proves` heading renamed out from under `section_of` — would have been invisible. The section still
#     carries text, so the refusal to assert is the missing reference, not an empty section.
noac=$(conforming_task C5)
sed -i 's|^- `#1 AC 2` — the first-line contract, refused and witnessed$|- `#1` — the first-line contract, refused and witnessed|' "$noac"
run "$p" -- task create --story 5 --title T --role agentic-ai-engineer --body-file "$noac"
refused "task create refuses a ## Proves that names no criterion" \
  'refused: ## Proves bullet does not open with a criterion reference ("#<n> AC <m>"): - `#1` — the first-line'

# 29a. The Proves check reads each bullet's opening, not the section's text. `AC <n>` anywhere in the
#      section was enough, so a bullet that names no criterion but mentions one in prose passed — the live
#      case is a task whose one bullet says it proves none of a story's criteria and cites them while saying
#      so. A bullet now opens with the reference, backticked or bare; a task that proves nothing declares it
#      as the section's one bullet, `none` and a reason, the way `test-free` licenses 0 RED tests.
# proves_task <name> <bullet lines...> -> a conforming task whose ## Proves holds exactly these lines
proves_task() {
  local f; f=$(conforming_task "$1"); shift
  printf '%s\n' "$@" > "$tmp/proves.lines"
  awk -v lf="$tmp/proves.lines" '
    $0 == "## Proves" {print; print ""; while ((getline l < lf) > 0) print l; print ""; skip = 1; next}
    skip && /^## / {skip = 0}
    !skip' "$f" > "$f.new" && mv "$f.new" "$f"
  echo "$f"
}
nprose="task create refuses a ## Proves bullet that mentions a criterion without opening with one"
pr=$(proves_task C5a '- the republish the story already covers, which `#1 AC 10` and `#1 AC 11` prove elsewhere')
run "$p" -- task create --story 5 --title T --role agentic-ai-engineer --body-file "$pr"
refused "$nprose" 'refused: ## Proves bullet does not open with a criterion reference ("#<n> AC <m>"): - the republish'
nmixed="task create refuses a prose bullet beside a real criterion reference"
pm=$(proves_task C5b '- `#1 AC 2` — the first-line contract' '- see also AC 3, which the next task proves')
run "$p" -- task create --story 5 --title T --role agentic-ai-engineer --body-file "$pm"
refused "$nmixed" 'refused: ## Proves bullet does not open with a criterion reference ("#<n> AC <m>"): - see also AC 3'
nbare="task create accepts a criterion reference without backticks, and several bullets"
pb=$(proves_task C5c '- #1 AC 2 — the first-line contract' '- `#1 AC 3`, `#1 AC 4` — the size line')
run "$p" -- task create --story 5 --title T --role agentic-ai-engineer --body-file "$pb"
created "$nbare" '- #1 AC 2 — the first-line contract'
nnone="task create accepts a declared none with a reason, in the shape a live preparatory task uses"
pn=$(proves_task C5d '- none of `#1 AC 1–12` — this task prepares the next one, which proves AC 10 and AC 11.')
run "$p" -- task create --story 5 --title T --role agentic-ai-engineer --body-file "$pn"
created "$nnone" '- none of `#1 AC 1–12`'
nbarenone="task create refuses a none that gives no reason"
pnr=$(proves_task C5e '- none')
run "$p" -- task create --story 5 --title T --role agentic-ai-engineer --body-file "$pnr"
refused "$nbarenone" 'refused: ## Proves declares "none" with no reason'
nnoneplus="task create refuses a none beside a criterion reference"
pnp=$(proves_task C5f '- `#1 AC 2` — the first-line contract' '- none — the rest is preparation')
run "$p" -- task create --story 5 --title T --role agentic-ai-engineer --body-file "$pnp"
refused "$nnoneplus" 'refused: ## Proves declares "none" beside a criterion'
nnobullet="task create refuses a ## Proves of prose with no bullet"
pnb=$(proves_task C5g 'This task proves #1 AC 2, as the story says.')
run "$p" -- task create --story 5 --title T --role agentic-ai-engineer --body-file "$pnb"
refused "$nnobullet" 'refused: ## Proves names no criterion'

# 30. AC 5 — "one malformed body per check and per kind", for the placeholder check over a task. Case 5
#     asserts it for `story` and the two kinds reach it down different paths: in `validate_task_body` the
#     `check_placeholders` call is the last line before the verdict, after every count, so a `return` or an
#     early `verdict` reached by any of those counts would skip the scan with every case above still green.
#     The stub left unfilled here is the one `item-task.md` writes into each `## Files` bullet, which is the
#     body a role stopped filling in halfway rather than one invented for the case.
tph=$(conforming_task C6)
sed -i 's|^- `plugins/crew/scripts/f1.sh` — what changes there$|- `plugins/crew/scripts/f1.sh` — <what changes there>|' "$tph"
run "$p" -- task create --story 5 --title T --role agentic-ai-engineer --body-file "$tph"
refused "task create refuses a surviving template placeholder" \
  'refused: unfilled template placeholder — <what changes there>'

# 31. AC 5 — and for the two kinds that reach the scan through `validate_plain_body`, whose own
#     `check_placeholders` call is a second copy of the line: breaking it leaves cases 25 to 27, 29 and 30
#     green, so the task case above says nothing about these two. One case over both kinds, each left
#     holding the stub its own template writes — the two templates name different sections, so a single arm
#     would prove only the kind it happened to read. The tech-debt stub spans two lines on purpose: the scan
#     joins the body before it strips code spans, and a stub that wraps has to be refused whole.
n_plainph="bug create and tech-debt create refuse a surviving template placeholder"
plainph_ok=1
bph=$(bug_body C7)
sed -i 's|^The claim succeeds and the failing checks come back as warnings\.$|<The behaviour in one sentence, stated so a test can assert it.>|' "$bph"
run "$p" -- bug create --title 'the probe' --body-file "$bph"
refused_q "$n_plainph" \
  'refused: unfilled template placeholder — <The behaviour in one sentence, stated so a test can assert it.>' || plainph_ok=0
dph=$(tech_debt_body C8)
sed -i 's|^The next item filed for either kind\.$|<The event that turns this into a story: "the next change to X", "before the first paying customer",\n"when the second caller appears". A debt item with no trigger is never picked up.>|' "$dph"
run "$p" -- tech-debt create --title 'the probe' --body-file "$dph"
refused_q "$n_plainph" 'refused: unfilled template placeholder' \
  '<The event that turns this into a story' 'A debt item with no trigger is never picked up.>' || plainph_ok=0
if [ "$plainph_ok" = 1 ]; then pass "$n_plainph"; fi

# 32. #30 — `next` read a task's story with an unanchored `grep -oE '^Story: #[0-9]+'`, so EVERY matching
#     line in the body contributed a number: a body carrying `Story: #1` as its first line and
#     `Story: #676 · design …` lower down handed the `printf` one argument too many and the record broke
#     across two lines. Appended rather than placed beside the other `next` cases so no comment block above
#     is renumbered for it. Two arms, because the parse answers two questions and only one of them is the
#     bug: the first line names the story, or nothing does. Line counting is the assertion a substring test
#     cannot make — a broken row carries every substring an intact one does, on two lines — and the anchored
#     `^#1<tab>-<tab>story #1<tab>` proves the fields are in one record with a title still behind them.
#     Role reads `-` and the title `null` because `list_json` cans neither, which is what every `next` case
#     above already runs against.
n_story="next reads a task's story from the first line only, so a body naming it twice prints one whole row"
twice=$(board_task L9 'Size: 2 hand-written files (+ 0 generated) · 1 RED tests · one PR' 2 1 'Split line: n/a')
sed -i '3i Story: #676 · design `docs/design/crew-0.6.0-items-and-proof.md` §3' "$twice"
list_json task "1:$twice"
run "$p" -- next
if [ "$rc" -ne 0 ]; then fail "$n_story" "expected exit 0 from next, got $rc; output: ${out:-empty}"
elif [ "$(printf '%s\n' "$out" | wc -l)" -ne 1 ]; then
  fail "$n_story" "the row broke across lines: $(printf '%s' "$out" | tr '\n' '|')"
elif ! printf '%s\n' "$out" | grep -q $'^#1\t-\tstory #1\t'; then
  fail "$n_story" "the row is not the whole record its first line's story names: $out"
elif printf '%s\n' "$out" | grep -q '676'; then
  fail "$n_story" "a story line below the first contributed a second number: $out"
else
  # The preserved half: a body whose first line is not a story reference contributes nothing, and the row
  # still prints — `story #?`, never the number a deeper line happens to mention. `task_body` opens on
  # `Role:`, so the first line is a non-reference by construction rather than by deletion.
  nostory=$(task_body L10 'Size: 2 hand-written files (+ 0 generated) · 1 RED tests · one PR' 2 1 'Split line: n/a')
  sed -i '2i Story: #676 · design `docs/design/crew-0.6.0-items-and-proof.md` §3' "$nostory"
  list_json task "2:$nostory"
  run "$p" -- next
  if [ "$rc" -ne 0 ]; then fail "$n_story" "expected exit 0 from next, got $rc; output: ${out:-empty}"
  elif [ "$(printf '%s\n' "$out" | wc -l)" -ne 1 ]; then
    fail "$n_story" "a task with no story reference on its first line lost its row: $(printf '%s' "$out" | tr '\n' '|')"
  elif ! printf '%s\n' "$out" | grep -q $'^#2\t-\tstory #?\t'; then
    fail "$n_story" "a first line that is not a story reference must read as #?, got: $out"
  else pass "$n_story"; fi
fi

# 33. #41 — the stub that names an owner. `item-bug.md` writes its role inside a code span, and the scan
#     strips code spans before it looks for stubs, so the one stub a reader uses to find who filed the bug
#     was the one stub that could never be reported — while `plain_create`'s comment and the 0.7.0
#     changelog both said it was. Case 31 cannot see this: the stub it leaves is ordinary prose, outside
#     any span, so it survives the strip the role does not. Only the role is left unfilled here, design
#     and found filled, so the body is conforming on every other check and the refusal has one cause.
nrole="bug create refuses a body whose role line is still the template's stub"
rph=$(bug_body C9)
sed -i '1s|`agentic-ai-engineer`|`<crew role>`|' "$rph"
run "$p" -- bug create --title 'the probe' --body-file "$rph"
refused "$nrole" 'refused: unfilled template placeholder — <crew role>'

# 34. #41 — the other half of the same line, and the reason the fix is not "stop stripping code spans":
#     a scan that read every backticked `<…>` — or every span — as a stub would refuse every conforming
#     bug, so the unwrap is deliberately narrow and this case is what holds it narrow. Case 27 already
#     witnesses that a filled role passes; what only this body can see is each restriction on the unwrap:
#     the inner class forbids `<` and `>`, and nothing may trail the stub inside the span. `<div> plus
#     prose` is a span the unwrap must NOT open — trailing prose makes it content — and the
#     `Option<Refusal>` span AFTER it is load-bearing, not decoration: it ends in `>` before a backtick,
#     so an inner class widened to `<.*>` matches greedily across both spans, the strip then mis-pairs the
#     two backticks left inside, and `<div>` and `<Refusal>` are reported as stubs. Either widening
#     therefore refuses this conforming body; neither is visible with one span alone.
nspan="bug create accepts spans whose angle brackets are prose rather than stubs"
sph=$(bug_body C10)
sed -i 's|^Claiming that item exits 3 and names no failing check\.$|Claiming that item exits 3 and names no failing check. A span holding `<div> plus prose` is prose, and so is the `Option<Refusal>` the refusal reaches the caller as.|' "$sph"
run "$p" -- bug create --title 'the probe' --body-file "$sph"
plain_created "$nspan" bug '`<div> plus prose`' && pass "$nspan"

# 35. #41 — the second defect in the same function, hit while filing that report. The strip pairs backticks
#     blindly over the joined body, so a fence's three mis-pair: the first two cancel, the third pairs with
#     the next backtick in the text, and the span strip then removes the fence's opening and exposes the
#     text the fence was protecting. A bug report that quotes a template line verbatim — the one thing an
#     Evidence section is for — is therefore refused for containing it, and the only way to file this very
#     report was to indent the block instead of fencing it.
#     The BLANK LINE inside the quoted block is this case's teeth (#42). The lone backtick above the fence
#     was what held the case up while the strip paired backticks by regular expression; under the scanner
#     that replaced it a one-paragraph block needs no fence handling at all — the opener's three backticks
#     find the closer's three in the same paragraph and the whole block is dropped as one long span, so the
#     case would pass with the fence arm deleted and prove nothing. A span cannot cross a blank line, so
#     with the block in two paragraphs and no fence arm the opener is a stray run, `<crew role>` is a span
#     holding nothing but a stub, and all three quoted stubs are reported. The lone backtick stays, as
#     prose that must remain prose; it is no longer what holds this case up.
nfence="body_placeholders does not expose a stub quoted inside a fenced block"
fph=$(bug_body C11)
sed -i 's|^Claiming that item exits 3 and names no failing check\.$|Claiming that item exits 3 and names no failing check. One lone ` backtick stands in this sentence, and the template line it was filed from reads, blank line and all:\n\n```\nRole: `<crew role>` · design: <none, or the doc>\n\nfound <where and when>\n```|' "$fph"
run "$p" -- bug create --title 'the probe' --body-file "$fph"
plain_created "$nfence" bug 'Role: `<crew role>` · design: <none, or the doc>' && pass "$nfence"

# 36. #41 — the other half of the fence handling, and the defect this commit exists to close reached
#     through a second door: an opener whose closer the author forgot. The awk pass is line-at-a-time, so
#     a fence it never sees closed would swallow every remaining line — one stray ``` and the rest of the
#     body is never scanned at all, which accepts a body whose role line is still a stub. The END arm hands
#     those held lines back instead, so the stub after the unclosed opener is reported and the body is
#     refused. Case 35 cannot see this: its fence closes, and a closed fence takes the `held = ""` arm.
nheld="body_placeholders still reports a stub below a fence whose closer is missing"
uph=$(bug_body C12)
sed -i 's|^Claiming that item exits 3 and names no failing check\.$|Claiming that item exits 3 and names no failing check, and the report quotes the block whose closer its author forgot:\n\n```\nthe quoted line, under which the closer never came\n\n<an unfilled stub the fence never closed over>|' "$uph"
run "$p" -- bug create --title 'the probe' --body-file "$uph"
refused "$nheld" 'refused: unfilled template placeholder — <an unfilled stub the fence never closed over>'

# 37. #42 — the hole #41 left open, and the reason the strip stopped being a regular expression: two stray
#     backticks in ordinary prose paired with each other, and everything between them — an unfilled stub
#     included — was deleted before the scan looked. The body here is conforming on every other check and
#     carries one stub, in its own paragraph, between two lone backticks in two other paragraphs. A span
#     cannot cross a blank line, so neither lone backtick opens one and the stub between them is read.
#     Case 35's lone backtick cannot see this: there the fence arm removes the material that mis-paired
#     with it, so the deletion lands on prose and the body is accepted either way.
nstray="body_placeholders reports a stub standing between two stray backticks in prose"
yph=$(bug_body C13)
sed -i 's|^Claiming that item exits 3 and names no failing check\.$|Claiming that item exits 3 and names no failing check.\n\nA lone ` backtick stands in this sentence.\n\n<an unfilled stub between the two>\n\nAnother lone ` stands in this one.|' "$yph"
run "$p" -- bug create --title 'the probe' --body-file "$yph"
refused "$nstray" 'refused: unfilled template placeholder — <an unfilled stub between the two>'

# 38. #42 — the same class as case 35 one indent in. A fence is how a body quotes a stub verbatim, and a
#     fence inside a list item is still a fence: matching the opener at column 0 only left an indented one
#     as three ordinary backticks, which mis-paired and exposed the very lines the author fenced.
#     The BLANK LINE inside the quoted block is this case's teeth, and the whole reason the block is two
#     paragraphs rather than one. Without it the opener's three backticks find the closer's three in the
#     same paragraph, the span scanner swallows the block as one long span, and the body is accepted with
#     no fence handling at all — the case would witness nothing. A span cannot cross a blank line, so with
#     the fence arm gone the opener is a stray run, `<crew role>` is a span holding nothing but a stub, and
#     all three quoted stubs are reported. The lone backtick in the sentence above is prose, and is here to
#     show it stays prose; it is not what holds this case up.
nindent="body_placeholders does not expose a stub quoted inside an indented fence"
iph=$(bug_body C14)
sed -i 's|^Claiming that item exits 3 and names no failing check\.$|Claiming that item exits 3 and names no failing check. One lone ` backtick stands in this sentence, and the list item below quotes the template line it was filed from:\n\n- quoted verbatim, blank line and all:\n\n  ```\n  Role: `<crew role>` · design: <none, or the doc>\n\n  found <where and when>\n  ```|' "$iph"
run "$p" -- bug create --title 'the probe' --body-file "$iph"
plain_created "$nindent" bug 'Role: `<crew role>` · design: <none, or the doc>' && pass "$nindent"

# 39. #42 — the unwrap #41 shipped opened a span holding exactly one stub, and `item-task.md` writes its
#     design path as two stubs side by side inside one span, so the one line a task body cites its design
#     on was a line the scan could not report either. The unwrap now opens a span holding nothing but
#     stubs, however many, and both tokens are named. Case 33 cannot see this: its span holds one stub, so
#     it passes with the count still fixed at one.
ntwo="body_placeholders reports a span holding two stubs and nothing else"
tph=$(bug_body C15)
sed -i 's|^Claiming that item exits 3 and names no failing check\.$|Claiming that item exits 3 and names no failing check, and the design it was filed against still reads `<profile:designs><slug>` as the template ships it.|' "$tph"
run "$p" -- bug create --title 'the probe' --body-file "$tph"
refused "$ntwo" 'refused: unfilled template placeholder — <profile:designs>' \
  'refused: unfilled template placeholder — <slug>'

# 40. #42 — the length half of the pairing rule, which cases 37 to 39 cannot see: a run of n backticks is
#     closed by a run of exactly n, never by the first run that follows. A double span is how a body quotes
#     a backtick — `` ``Role: <crew role>`` `` is the only way to write that line without the inner span
#     being read — so a stray single backtick ahead of one is ordinary prose: it finds no single run after
#     it and stays literal. Ignore the length and it pairs with the first backtick of the double span
#     instead, which deletes the stub standing between them and accepts the body, which is #42 again by a
#     third door. The paragraph holds no single backtick after the stray on purpose: with one there the
#     equal-length rule pairs with it and this case would witness nothing.
nrun="body_placeholders pairs a backtick run only with a run of its own length"
rrph=$(bug_body C16)
sed -i 's|^Claiming that item exits 3 and names no failing check\.$|Claiming that item exits 3 and names no failing check.\n\nA lone ` backtick stands in this sentence, the stub <an unfilled stub past the stray> stands after it, and the template line reads ``Role: <crew role>`` where only a double span can hold it.|' "$rrph"
run "$p" -- bug create --title 'the probe' --body-file "$rrph"
refused "$nrun" 'refused: unfilled template placeholder — <an unfilled stub past the stray>'

# 41. #42 — the cost of letting the fence opener accept any indentation. Case 38 needs an indented fence to
#     stay a fence, and the rule that bought it matched `[[:space:]]*`, which is wider than a fence is:
#     CommonMark stops a fence opener at three spaces, because at four the line is an indented code block
#     and its backticks are content. So two four-space markers — the shape a body reaches for when it wants
#     to SHOW a fence rather than open one — paired as a fence, and every line between them, an unfilled
#     stub included, was never scanned. Bounding the indent at three spaces reads those markers as the text
#     they are, and the stub below them is reported. Case 38's two-space fence is inside the bound and is
#     unaffected; a leading tab falls out for free, since a tab is four columns and matches no space.
nwide="body_placeholders reports a stub between two markers indented past a fence's three spaces"
wph=$(bug_body C17)
sed -i 's|^Claiming that item exits 3 and names no failing check\.$|Claiming that item exits 3 and names no failing check, and the lines it quotes are indented four spaces rather than fenced:\n\n    ```\n\nunder which the report still reads:\n\n<an unfilled stub between two four-space markers>\n\n    ```|' "$wph"
run "$p" -- bug create --title 'the probe' --body-file "$wph"
refused "$nwide" 'refused: unfilled template placeholder — <an unfilled stub between two four-space markers>'

# 42. #42 — the index advance that resumes the scan after a closed span, which no case above could see. A
#     closed span ends at a run of its own length, so the scan resumes past the WHOLE closing run, not one
#     character into it: leave a backtick of that run in play and it opens a span of its own, which then
#     closes on the next single backtick in the paragraph and deletes everything between — the stub
#     included. The paragraph is a double span, then a stub, then a single span, so the leftover backtick
#     has a partner to pair with. Case 40 cannot see it: its double span is last in the paragraph, so a
#     leftover backtick finds no closer and stays literal, and the stub above it is reported either way.
nadv="body_placeholders resumes the scan past the whole closing run of a span"
aph=$(bug_body C18)
sed -i 's|^Claiming that item exits 3 and names no failing check\.$|Claiming that item exits 3 and names no failing check. The template line reads ``Role: <crew role>`` where only a double span can hold it, the stub <an unfilled stub past the double span> stands after it, and `the filled role` closes the sentence.|' "$aph"
run "$p" -- bug create --title 'the probe' --body-file "$aph"
refused "$nadv" 'refused: unfilled template placeholder — <an unfilled stub past the double span>'

# 43. #42 — the identity of the character that joins a paragraph's lines, which every case above leaves
#     free. Joining with a space would read naturally, and that is exactly what breaks: the outer grep
#     refuses whitespace right after `<`, so a stub that wraps immediately after its opening bracket would
#     stop being read as one and the body would be accepted. A control character outside the body's own
#     alphabet joins the lines, the match sees it as an ordinary character, and the final `tr` turns it back
#     into the space a reader wants. Hence the refusal here names `< slug>`, line break and all.
nsep="body_placeholders reports a stub that wraps immediately after its opening angle bracket"
sepph=$(bug_body C19)
sed -i 's|^Claiming that item exits 3 and names no failing check\.$|Claiming that item exits 3 and names no failing check, and the design path it cites is still the template own <\nslug> token, wrapped across the line break where it was typed.|' "$sepph"
run "$p" -- bug create --title 'the probe' --body-file "$sepph"
refused "$nsep" 'refused: unfilled template placeholder — < slug>'

echo "tracker.sh conformed: has the story been conformed since its last edit?"

# gql <n> <kind> <createdAt> <lastEditedAt or null> <updatedAt> <body file> [<comment createdAt> <comment body>]...
# -> the canned GraphQL answer for one issue. `updatedAt` is canned LATER than everything else on purpose:
#    GitHub moves it on a comment, a label and a close (seen on vonk-platform #737: updatedAt 06:39:45,
#    lastEditedAt 06:19:44), and the marker comment itself moves it, so a helper reading it would never
#    report a story as conformed. Every case below would go red on that mistake.
gql() {
  local n=$1 kind=$2 created=$3 edited=$4 updated=$5 bf=$6; shift 6
  local comments='[]'
  while [ $# -ge 2 ]; do
    comments=$(jq -c --arg c "$1" --arg b "$2" '. + [{createdAt: $c, body: $b}]' <<<"$comments"); shift 2
  done
  jq -n --argjson n "$n" --arg k "$kind" --arg c "$created" --arg u "$updated" --arg e "$edited" \
        --rawfile b "$bf" --argjson cm "$comments" \
    '{data: {repository: {issue: {number: $n, createdAt: $c, updatedAt: $u,
      lastEditedAt: (if $e == "null" then null else $e end), body: $b,
      labels: {nodes: [{name: $k}]}, comments: {nodes: $cm}}}}}' > "$lists/gql-$n.json"
}
cstory="$tmp/cstory.md"; printf '## TL;DR\n\nA story.\n\n## Tasks\n\n- [ ] #71 (architect) one\n- [x] #72 (architect) two\n' > "$cstory"
ctask="$tmp/ctask.md"; printf 'Story: #70\nBlocked by: none\n\n## TL;DR\n\nA task.\n' > "$ctask"
cloose="$tmp/cloose.md"; printf 'Blocked by: none\n\n## TL;DR\n\nA task with no story line.\n' > "$cloose"
cmark='crew:conform 2026-10-02T09:00:00Z 57224763
Conformed #70, #71, #72; declined: none.'
cleanup_gql() { rm -f "$lists"/gql-*.json; }
wrote_board() { grep -aqE 'issue (edit|comment|create|close)|label create' "$ghlog"; }

# 44. Decision 4 — a marker newer than every body edit, the story's and each listed task's, is conformed;
#     asked from a task, the helper resolves the story off the task's first line.
nc1="conformed answers 0 for a story whose marker is newer than every body edit, asked from a task"
gql 70 story 2026-10-01T08:00:00Z 2026-10-02T08:00:00Z 2026-10-02T11:00:00Z "$cstory" \
    2026-10-02T07:00:00Z 'an older remark' 2026-10-02T09:00:05Z "$cmark"
gql 71 task  2026-10-01T08:10:00Z 2026-10-02T08:30:00Z 2026-10-02T11:00:00Z "$ctask"
gql 72 task  2026-10-01T08:20:00Z null                 2026-10-02T11:00:00Z "$ctask"
p=$(profile conformed)
run "$p" -- conformed 71
if reported "$nc1" 0 'story #70 conformed'; then
  if wrote_board; then fail "$nc1" "conformed wrote to the board: $(cat "$ghlog")"; else pass "$nc1"; fi
fi

# 45. The exact line `/crew:work` prints, when one listed task's body moved after the marker.
nc2="conformed answers 1 with the one line work prints when a task body was edited after the marker"
gql 72 task 2026-10-01T08:20:00Z 2026-10-02T10:00:00Z 2026-10-02T11:00:00Z "$ctask"
run "$p" -- conformed 70
reported "$nc2" 1 'story #70 not conformed since its last edit — /crew:conform #70 before work if you want it' && pass "$nc2"

# 46. A story never conformed: no marker among its comments is the same answer, not a different one.
nc3="conformed answers 1 for a story that carries no marker at all"
gql 70 story 2026-10-01T08:00:00Z null 2026-10-02T11:00:00Z "$cstory" 2026-10-02T07:00:00Z 'crew:conformed is not the marker'
gql 72 task  2026-10-01T08:20:00Z null 2026-10-02T11:00:00Z "$ctask"
run "$p" -- conformed 70
reported "$nc3" 1 'story #70 not conformed since its last edit' && pass "$nc3"

# 47. Decision 4 — a lookup that cannot decide says so in its one line and exits 2: a listed task the API
#     will not answer for, and a task whose first line names no story. Neither is reported as unconformed.
nc4="conformed answers 2, in one line, when a listed task cannot be read"
rm -f "$lists/gql-72.json"
run "$p" -- conformed 70
if reported "$nc4" 2 'conform state of #70 not checked'; then
  if [ "$(printf '%s\n' "$out" | grep -c .)" -ne 1 ]; then fail "$nc4" "expected one line, got: $out"; else pass "$nc4"; fi
fi
nc5="conformed answers 2 for a task whose first line names no story, instead of guessing one"
gql 73 task 2026-10-01T08:20:00Z null 2026-10-02T11:00:00Z "$cloose"
run "$p" -- conformed 73
reported "$nc5" 2 'conform state of #73 not checked' 'names no story' && pass "$nc5"
nc6="conformed refuses a target that is not one item number"
run "$p" -- conformed --all
reported "$nc6" 1 'conformed takes one item number' && pass "$nc6"
cleanup_gql

# 48. 0.9.1 — a count that disagrees names its cause. A `## Files` bullet that does not OPEN with a backticked
#     path cannot match a generated: glob, so it counts as hand-written; the refusal says which bullets those
#     are instead of leaving "27 files, Size: says 22" to be reverse-engineered. The check itself is unchanged.
n48="a Files count that disagrees names the bullets that open with no backticked path"
pg48=$(profile generated48 "generated: gen/*.json")
b48=$(task_body t48 'Size: 1 hand-written files (+ 1 generated) · 1 RED tests · one PR' 1 1 'Split line: n/a')
sed -i '/^- `plugins\/crew\/scripts\/f1.sh`/a - generated: `gen/b.json` — the path does not open the bullet' "$b48"
run "$pg48" -- task create --story 5 --title T --role agentic-ai-engineer --body-file "$b48"
refused "$n48" 'refused: ## Files lists 2 files, Size: says 1' \
  '1 bullet opens with no backticked path' '- generated: `gen/b.json`'

# 49. 0.9.1 — the RED count's refusal says the rule it counts by: every numbered entry is a RED test, so a
#     deliberate non-RED witness goes unnumbered or under Done when. The count stays as strict as before.
n49="a Tests count that disagrees says every numbered entry counts as a RED test"
run "$p" -- task create --story 5 --title T --role agentic-ai-engineer \
  --body-file "$(task_body t49 'Size: 2 hand-written files (+ 0 generated) · 1 RED tests · one PR' 2 2 'Split line: n/a')"
refused "$n49" 'refused: ## Tests (RED first) lists 2 numbered tests, Size: says 1' \
  'every numbered entry under ## Tests (RED first) is counted as a RED test' 'unnumbered or under ## Done when'

# 50. The profile reader strips a trailing "# comment", so `generated: a/*.json  # guessed by /crew:init —
#     verify` yields the glob alone and none of the comment's words becomes a glob.
n50="crew_profile_value strips a trailing comment from the generated: line"
pc50=$(profile comment50 'generated: gen/*.json, apps/*/package-lock.json  # guessed by /crew:init — verify')
got50=$(. "$crew/scripts/common.sh"; crew_profile_value "$pc50/.claude/crew/profile.md" generated)
if [ "$got50" = 'gen/*.json, apps/*/package-lock.json' ]; then pass "$n50"; else fail "$n50" "got '$got50'"; fi

# 51-55. 0.9.1 — `preserved <old> <new>`, read-only: every fragment of the old body (a sentence, a clause
#     ending in ; or :, a list item, a paragraph) that is not found verbatim, whitespace-normalised, in the
#     new body, one per line, then a closing count. A moved section is not a loss — the case a unified diff
#     gets wrong, showing the whole section as removed — and a shortened sentence or a dropped bullet is.
old51="$tmp/pres-old.md"; cat > "$old51" <<'EOF'
## Problem

The board loses tasks. Nobody sees them; nobody does them.

## Why

A task nobody can see is work nobody does.

## Likely files

- `a.sh`, `b.sh` — both change
- `c.md` — the doc
EOF
moved51="$tmp/pres-moved.md"; cat > "$moved51" <<'EOF'
## Why

A task nobody can see
is work nobody does.

## Problem

The board loses tasks.   Nobody sees them; nobody does them.

## Likely files

- `a.sh`, `b.sh` — both change
- `c.md` — the doc
EOF
n51="preserved follows a moved section and a reflowed line: nothing lost, exit 0"
run "$p" -- preserved "$old51" "$moved51"
if reported "$n51" 0 '0 not found'; then
  if [ "$(printf '%s\n' "$out" | grep -c .)" -ne 1 ]; then fail "$n51" "expected the closing line alone, got: $out"
  elif wrote_board; then fail "$n51" "preserved wrote to the board: $(cat "$ghlog")"
  else pass "$n51"; fi
fi
lost52="$tmp/pres-lost.md"
sed -e 's/^A task nobody can see is work nobody does\.$/Unseen work is not done./' -e '/^- `c\.md`/d' "$old51" > "$lost52"
n52="preserved lists a paraphrased sentence and a dropped bullet, and exits 1"
run "$p" -- preserved "$old51" "$lost52"
if reported "$n52" 1 'A task nobody can see is work nobody does.' '`c.md` — the doc' '2 not found'; then
  case "$out" in *'The board loses tasks.'*) fail "$n52" "a kept sentence was listed as lost: $out" ;; *) pass "$n52" ;; esac
fi
# A fragment keeps the punctuation that ends it, so the ";" that became "." is listed too: it is a changed
# character, and the approval has to see it.
n53="preserved lists a clause cut from a sentence that is otherwise kept"
sed 's/ Nobody sees them; nobody does them\./ Nobody sees them./' "$old51" > "$tmp/pres-clause.md"
run "$p" -- preserved "$old51" "$tmp/pres-clause.md"
reported "$n53" 1 'Nobody sees them;' 'nobody does them.' '2 not found' && pass "$n53"
n54="preserved refuses an unreadable file with exit 2 rather than reporting it as all lost"
run "$p" -- preserved "$old51" "$tmp/does-not-exist.md"
reported "$n54" 2 'preserved' && pass "$n54"
n55="preserved counts a renamed heading as not found, so the rename must be a listed edit"
sed 's/^## Likely files$/## Files/' "$old51" > "$tmp/pres-head.md"
run "$p" -- preserved "$old51" "$tmp/pres-head.md"
reported "$n55" 1 '## Likely files' '1 not found' && pass "$n55"

if [ "$fails" -eq 0 ]; then echo "PASS"; exit 0; fi
echo "FAIL ($fails)"; exit 1
