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
prev=""; bf=""
for a in "$@"; do [ "$prev" = "--body-file" ] && bf=$a; prev=$a; done
case "$*" in
  *"issue create"*)
    [ -n "$bf" ] && cat "$bf" >> "${CREW_GH_BODY:-/dev/null}"
    echo "https://github.com/o/r/issues/99" ;;
  *"issue view"*) echo "## Tasks" ;;
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

ghlog="" ghbody="" out="" rc=0
# run <project-dir> -- <tracker args...>
# The adapter runs *in* the project directory, as a real invocation does: a `generated:` glob has to be
# matched as a pattern, never expanded against whatever that directory happens to hold.
run() {
  local dir=$1; shift; [ "${1:-}" = "--" ] && shift
  ghlog="$tmp/gh.log"; ghbody="$tmp/gh.body"; : > "$ghlog"; : > "$ghbody"
  out=$(cd "$dir" && CREW_PROJECT_DIR="$dir" CREW_GH_LOG="$ghlog" CREW_GH_BODY="$ghbody" \
        PATH="$tmp/bin:$PATH" bash "$sut" "$@" 2>&1)
  rc=$?
}

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

if [ "$fails" -eq 0 ]; then echo "PASS"; exit 0; fi
echo "FAIL ($fails)"; exit 1
