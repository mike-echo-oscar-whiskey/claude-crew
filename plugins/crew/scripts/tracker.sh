#!/usr/bin/env bash
# Purpose: tracker adapter for the crew pipeline. Backend from the project profile
#          (`tracker: github <owner>/<repo>`). Azure DevOps backend not implemented yet.
# Usage:
#   tracker.sh ensure-labels
#   tracker.sh story create --title T --body-file F                  -> prints issue number
#   tracker.sh task  create --story N --title T --role R --body-file F [--blocked-by "12,13"]
#   tracker.sh bug create --title T --body-file F                    -> prints issue number
#   tracker.sh tech-debt create --title T --body-file F              -> prints issue number
#   tracker.sh claim N                (assign @me, label in-progress, comment claimed-by; warns when the body is off-shape)
#   tracker.sh lint [<n> | --all | --kind story|task|bug|tech-debt] [--quiet]   (read-only conformance report)
#   tracker.sh release N --to in-review|blocked|open|done   (done: lane labels off, item closed, assignee kept)
#   tracker.sh next                   (claimable tasks: open, unassigned, not in-progress/in-review/blocked, blockers closed)
#   tracker.sh status                 (stories with task progress)
#   tracker.sh show N                 (issue + comments)
#   tracker.sh comment N --body-file F
set -euo pipefail
. "$(dirname "$0")/common.sh"
command -v gh >/dev/null || { echo "needs gh (GitHub CLI)" >&2; exit 1; }
command -v jq >/dev/null || { echo "needs jq" >&2; exit 1; }

profile=$(crew_profile_path "${CREW_PROJECT_DIR:-$PWD}")
tracker=$(crew_profile_value "$profile" tracker)
backend=${tracker%% *}; target=${tracker#* }
case "$backend" in
  github) REPO=$target; SIGIL='#' ;;
  azure-devops) echo "tracker backend azure-devops is not implemented yet (profile: $tracker)" >&2; exit 2 ;;
  *) echo "no usable 'tracker:' line in $profile (got: '$tracker')" >&2; exit 2 ;;
esac
GH=(gh --repo "$REPO")

TEMPLATES=${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}/templates
SIZE_CAP=$(crew_profile_value "$profile" size-cap || true); SIZE_CAP=${SIZE_CAP:-15}
# Bounded on purpose: a longer run of digits passes a bare ^[0-9]+$ and then makes `[ -gt ]` fail
# with "integer expected", which silently removes the cap check instead of capping anything.
if [ "$SIZE_CAP" != "-" ] && ! [[ $SIZE_CAP =~ ^[0-9]{1,6}$ ]]; then SIZE_CAP=15; fi
GENERATED=$(crew_profile_value "$profile" generated || true); GENERATED=${GENERATED//,/ }
case "$GENERATED" in -) GENERATED="" ;; esac

# The item kinds, in the order `lint --all` walks them: one `issue list` call each, never a fetch per
# item. A kind is a label, so `lint` judges an item against the template for the kind it carries.
KINDS=(story task bug tech-debt)

ROLES=(product-owner architect frontend-engineer backend-engineer integration-engineer event-sourcing-engineer genai-engineer agentic-ai-engineer multitenancy-engineer commercial-analyst qa-engineer security-engineer cloud-engineer ux-designer privacy-and-compliance technical-writer)

ensure_labels() {
  "${GH[@]}" label create story             --color 0E6B52 --description "Functional story (crew pipeline)" --force >/dev/null
  "${GH[@]}" label create task              --color 1D76DB --description "Implementation task under a story" --force >/dev/null
  # The other two kinds in KINDS, which lint already judges: without these a consumer of the plugin has no
  # label to carry either shape, so `lint --kind tech-debt` names a kind nothing on its board can be. `bug`
  # is minted in GitHub's own colour on purpose — GitHub creates it in every new repository, and `--force`
  # would otherwise repaint a label the project already uses for exactly this.
  "${GH[@]}" label create bug               --color D73A4A --description "Reported defect in behaviour that shipped (crew pipeline)" --force >/dev/null
  "${GH[@]}" label create tech-debt         --color 8D6E63 --description "Debt carried deliberately; its severity is a p1/p2/p3 label" --force >/dev/null
  "${GH[@]}" label create in-progress       --color FBCA04 --description "Claimed by a session" --force >/dev/null
  "${GH[@]}" label create in-review         --color 5319E7 --description "PR open, awaiting merge" --force >/dev/null
  "${GH[@]}" label create blocked           --color B60205 --description "Cannot proceed; see body" --force >/dev/null
  "${GH[@]}" label create needs-refinement  --color D4C5F9 --description "Story not ready for planning" --force >/dev/null
  # Severity is a label, never body text (D8), and each description carries what the label obliges, so a
  # reviewer who never opens the review step still reads what a p2 costs. GitHub caps a label description
  # at 100 characters, which is why these are the obligation's short form; its full text lives once, in
  # the review step. Both hold only for a finding that carries its reproduction.
  "${GH[@]}" label create p1 --color B60205 --description "Blocks: always fixed before the change is offered; a finding needs its reproduction" --force >/dev/null
  "${GH[@]}" label create p2 --color D93F0B --description "Fix in this change if it caused or exposed it; else one line in the PR + its own item" --force >/dev/null
  "${GH[@]}" label create p3 --color FEF2C0 --description "Grouped into a planned task or its own item; never blocks" --force >/dev/null
  for r in "${ROLES[@]}"; do
    "${GH[@]}" label create "role:$r" --color BFD4F2 --description "Owned by the $r persona" --force >/dev/null
  done
  echo "labels ensured on $REPO"
}

issue_number_from_url() { sed -E 's#.*/([0-9]+)$#\1#'; }

# ---- create-time item checks -------------------------------------------------------------------
# A body that fails any check is refused before a single gh call: exit 1, one "refused: <check> —
# <what was found>" line per failing check on stderr, nothing created. The required "## " sections
# are read from the resolved template, so a project that overrides a kind is checked against its
# own shape. One validator per kind, shared by create and (later) lint.

item_template() { # <kind> -> the resolved template (a project override wins)
  local over="${CREW_PROJECT_DIR:-$PWD}/.claude/crew/items/$1.md"
  if [ -f "$over" ]; then echo "$over"; else echo "$TEMPLATES/item-$1.md"; fi
}

template_sections() { # <kind> -> its "## " headings, in template order
  local t; t=$(item_template "$1")
  [ -f "$t" ] || return 0
  sed -nE 's/^(## .+)$/\1/p' "$t"
}

section_of() { # <heading prefix> <headings...> -> the first heading carrying that prefix
  local prefix=$1; shift
  printf '%s\n' "$@" | { grep -m1 "^$prefix" || true; }
}

body_is_text() { # <file> -> false when the body carries a NUL byte
  # grep then calls the file binary: it prints no match line, so H, T and the placeholder list all come
  # back empty and every check that reads the body is skipped rather than failed.
  local all nul
  all=$(wc -c < "$1"); nul=$(tr -d '\000' < "$1" | wc -c)
  [ "$all" = "$nul" ]
}

section_body() { awk -v h="$2" '$0 == h {f = 1; next} /^## /{f = 0} f' "$1"; }
section_has_text() { [ -n "$(section_body "$1" "$2" | tr -d '[:space:]')" ]; }

body_placeholders() { # <file> -> the template stubs still in the body, one per line
  # One awk pass, three states, and no regular expression that pairs backticks — pairing by regex is what
  # made two stray backticks delete every stub between them (#42) and what made a fence's three backticks
  # expose the lines it was quoting (#41).
  #   A FENCE is the one structure only a line can show: three or more backticks opening a line, under at
  # most three spaces of indent — indent at all, since a fence inside a list item is still a fence (#42);
  # no more than three, because that is where CommonMark stops, a fourth space making the line an indented
  # code block whose backticks are content. Accept any indent and two four-space markers pair as a fence
  # and swallow a real stub between them, which is #42 again by the door the bound closes. A fence
  # quotes verbatim material, so nothing between an opener and its closer is scanned at all — that is how
  # a body writes a stub, or a literal `<div>`, and means it. An opener with no closer quotes nothing, so
  # its lines are handed back at the END rather than dropped: one stray fence must not switch the rest of
  # the scan off.
  #   A PARAGRAPH is the span scanner's unit. Lines are joined, because a span and a stub both wrap across
  # a line break and a line-at-a-time scan would read a wrapped `<…>` as unfilled; they are joined no
  # further than the next blank line, because a code span cannot cross a paragraph boundary. That one
  # bound is what tells a span from a STRAY backtick: a lone backtick in prose has no closer in its own
  # paragraph, so it is literal text and the stubs below it are still read (#42).
  #   Inside a paragraph, a run of n backticks opens a span only if a run of exactly n closes it later;
  # an unclosed run is literal. A closed span's content is dropped, which is what keeps a real
  # `List<string>` out of the report — unless the content is NOTHING but `<…>` tokens, which is a stub the
  # template shipped inside backticks rather than content a role wrote, and is unwrapped so the scan sees
  # it. `item-bug.md` writes its role as one such token and `item-task.md` its design path as two side by
  # side, which is why those were the two stubs this scan could never report (#41, #42).
  #   The cost, unchanged in kind and slightly wider in reach: a body meaning a literal backticked
  # `<token>` in prose is refused as a stub, and now also one meaning two of them side by side. Such a
  # body writes them in a fence, where nothing is read, or puts another word beside them in the span.
  awk '
    function stubs_only(s) { return s ~ /^(<[^<>]*>)+$/ }
    function closer(s, from, want,   n, i, k) {   # the start of the next run of exactly `want`, or 0
      n = length(s); i = from
      while (i <= n) {
        if (substr(s, i, 1) != "`") { i++; continue }
        k = 0; while (i + k <= n && substr(s, i + k, 1) == "`") k++
        if (k == want) return i
        i += k
      }
      return 0
    }
    function despan(s,   out, n, i, run, end, body) {
      out = ""; n = length(s); i = 1
      while (i <= n) {
        if (substr(s, i, 1) != "`") { out = out substr(s, i, 1); i++; continue }
        run = 0; while (i + run <= n && substr(s, i + run, 1) == "`") run++
        end = closer(s, i + run, run)
        if (end == 0) { out = out substr(s, i, run); i += run; continue }
        body = substr(s, i + run, end - i - run)
        if (stubs_only(body)) out = out body
        i = end + run
      }
      return out
    }
    function flush() { if (para != "") { print despan(para); para = "" } }
    function take(line) { if (line ~ /^[[:space:]]*$/) flush(); else para = (para == "" ? line : para SEP line) }
    BEGIN { SEP = sprintf("%c", 1) }
    /^ {0,3}```/ { if (f) { f = 0; held = "" } else { f = 1 }; next }
    f     { held = held $0 "\n"; next }
          { take($0) }
    END   { flush(); n = split(held, lines, "\n"); for (i = 1; i <= n; i++) take(lines[i]); flush() }
  ' "$1" \
    | { grep -aoE '<!--|<[^<>[:space:]/][^<>]*>' || true; } \
    | { grep -avE '^<https?:' || true; } | tr '\001' ' ' | sort -u
}

files_hand_written() { # <file> <heading> -> bullets whose path is not a generated: glob
  local n=0 line p glob
  local -a globs=(); read -ra globs <<<"$GENERATED"   # split, never expand: an unquoted $GENERATED
  while IFS= read -r line; do                         # would pathname-expand against the cwd
    p=$(sed -nE 's/^[[:space:]]*-[[:space:]]*`([^`]*)`.*/\1/p' <<<"$line")
    if [ -n "$p" ]; then
      for glob in ${globs[@]+"${globs[@]}"}; do
        # shellcheck disable=SC2053  # the profile's value is a glob on purpose
        if [[ $p == $glob ]]; then continue 2; fi
      done
    fi
    n=$((n + 1))
  done < <(section_body "$1" "$2" | { grep -aE '^[[:space:]]*- ' || true; })
  echo "$n"
}

SECTIONS=()
check_sections() { # <file> <kind> <heading that must stay EMPTY, or ""> [heading exempt from both]
  # The exempt heading is how the create-time rules and lint differ: a story is created with "## Tasks"
  # empty and lives on the board with the checklist the adapter appends, so on the board the section is
  # neither required to be empty nor required to carry text — only to be there.
  local f=$1 kind=$2 empty=$3 exempt=${4:-} sec
  SECTIONS=()
  mapfile -t SECTIONS < <(template_sections "$kind")
  if [ ${#SECTIONS[@]} -eq 0 ]; then
    refuse "no $kind template at $(item_template "$kind") to read the required sections from"
    return 0
  fi
  for sec in "${SECTIONS[@]}"; do
    if ! grep -aqxF "$sec" "$f"; then refuse "section \"$sec\" is missing"; continue; fi
    if [ -n "$exempt" ] && [ "$sec" = "$exempt" ]; then continue; fi
    if [ -n "$empty" ] && [ "$sec" = "$empty" ]; then
      if section_has_text "$f" "$sec"; then refuse "\"$empty\" must be empty: the adapter appends the checklist there"; fi
    elif ! section_has_text "$f" "$sec"; then refuse "section \"$sec\" is empty"; fi
  done
}

check_placeholders() { # <file> -> one refusal per surviving template stub
  local ph line
  ph=$(body_placeholders "$1")
  [ -n "$ph" ] || return 0
  while IFS= read -r line; do refuse "unfilled template placeholder — $line"; done <<<"$ph"
}

REFUSALS=()
refuse() { REFUSALS+=("refused: $1"); }
refuse_non_text() { # <file> -> non-zero, one refusal recorded, when grep would call the body binary
  body_is_text "$1" && return 0
  refuse "the body is not text — it carries a NUL byte, and every check reading it would match nothing"
  return 1
}
verdict() { # 0 when the body conforms; otherwise every failing check on stderr, one per line
  if [ ${#REFUSALS[@]} -eq 0 ]; then return 0; fi
  printf '%s\n' "${REFUSALS[@]}" >&2
  return 1
}

# The one place a task's story number is read, and the one shape that reading may take: the FIRST line,
# whole, or nothing. `next` carried its own grep eight lines from this regex, matching every line that merely
# BEGAN with the reference — so each one contributed, and a body mentioning its story again lower down
# yielded two numbers, handed the row's `printf` an argument too many and broke the record in half (#30).
# One regex in two call sites is how that bug existed; the two hold one function now. The anchors are the
# contract: the line must BE the reference and nothing else, so `Story: #676 · design …` is not one wherever
# it sits. A first line that is not a reference reads as "" — the answer both call sites have always given
# for it, `lint` naming the shape in its refusal and `next` printing `#?` and the row.
story_of_body() { # <task body on stdin> -> its story number, or "" when the first line is not a story reference
  sed -nE "1s/^Story:[[:space:]]*$SIGIL?([0-9]+)[[:space:]]*\$/\\1/p"
}

check_proves() { # <body file> <## Proves heading>
  # A bullet is judged by how it opens, never by what it mentions: "AC <n>" anywhere in the section let a
  # bullet that proves nothing pass by citing the criteria it does not prove. Each top-level bullet opens
  # with "<sigil><n> AC <m>", backticked or bare; a task that proves no criterion says so as the section's
  # only bullet, "none" and a reason — declared, the way "test-free" licenses 0 RED tests.
  local f=$1 h=$2 line rest n=0 nones=0
  while IFS= read -r line; do
    [[ $line =~ ^[-*][[:space:]]+(.*)$ ]] || continue
    rest=${BASH_REMATCH[1]}; n=$((n + 1))
    rest=${rest#\`}
    if [[ $rest =~ ^[Nn][Oo][Nn][Ee]([^[:alnum:]_]|$) ]]; then
      nones=$((nones + 1))
      if [[ ! ${rest:4} =~ [[:alnum:]] ]]; then
        refuse "$h declares \"none\" with no reason: write \"none — <why this task proves no criterion>\""
      fi
      continue
    fi
    if [[ $rest != "$SIGIL"* ]] || [[ ! ${rest#"$SIGIL"} =~ ^[0-9]+[[:space:]]+AC[[:space:]]+[0-9]+ ]]; then
      refuse "$h bullet does not open with a criterion reference (\"$SIGIL<n> AC <m>\"): $line"
    fi
  done < <(section_body "$f" "$h")
  if [ "$n" -eq 0 ]; then
    refuse "$h names no criterion: each bullet opens with \"$SIGIL<n> AC <m>\", or its one bullet is \"none — <reason>\""
  elif [ "$nones" -gt 0 ] && [ "$n" -gt 1 ]; then
    refuse "$h declares \"none\" beside a criterion: a task proves criteria or declares none, as its one bullet"
  fi
}

validate_task_body() { # <assembled body file> <story as given>
  local f=$1 num=${2//[!0-9]/} first key size h="" t="" sec nf nt ph line
  REFUSALS=()

  refuse_non_text "$f" || { verdict; return; }

  first=$(head -1 "$f")
  if [ "$first" != "Story: $SIGIL$num" ]; then
    # ${num:-<n>}: lint reads the number out of the first line itself, so a body with no such line has
    # no number to name — the shape is what the message has to state there.
    refuse "first line must be \"Story: $SIGIL${num:-<n>}\" (the board rolls tasks up by it) — got \"$first\""
  fi
  for key in "Blocked by:" "Role:" "Size:"; do
    if ! grep -aqE "^$key" "$f"; then refuse "the \"$key\" line is missing"; fi
  done

  size=$(grep -am1 '^Size:' "$f" || true)
  if [[ $size =~ ^Size:[[:space:]]*([0-9]{1,6})[[:space:]]+hand-written[[:space:]]+files[[:space:]]*\([[:space:]]*\+[[:space:]]*[0-9]+[[:space:]]+generated\)[^0-9]*([0-9]{1,6})[[:space:]]+RED ]]; then
    h=${BASH_REMATCH[1]}; t=${BASH_REMATCH[2]}
  elif [ -n "$size" ]; then
    refuse "Size: must read \"<H> hand-written files (+ <G> generated) · <T> RED tests · one PR\" — got \"$size\""
  fi
  if [ -n "$h" ]; then
    if ! grep -aqE '^(Split line:|Exception:)' "$f" && { [ "$h" -ge 12 ] || [ "$t" -ge 4 ]; }; then
      refuse "a task of $h files and $t RED tests needs a \"Split line:\" or an \"Exception:\" line"
    fi
    if [ "$SIZE_CAP" != "-" ] && [ "$h" -gt "$SIZE_CAP" ] && ! grep -aqE '^Exception:' "$f"; then
      refuse "Size: $h hand-written files is over size-cap: $SIZE_CAP, and no \"Exception:\" line licenses it"
    fi
  fi

  check_sections "$f" task ""
  local -a sections=("${SECTIONS[@]+"${SECTIONS[@]}"}")

  local files_h tests_h proves_h
  files_h=$(section_of '## Files' "${sections[@]+"${sections[@]}"}")
  tests_h=$(section_of '## Tests' "${sections[@]+"${sections[@]}"}")
  proves_h=$(section_of '## Proves' "${sections[@]+"${sections[@]}"}")

  if [ -n "$files_h" ] && [ -n "$h" ]; then
    nf=$(files_hand_written "$f" "$files_h")
    if [ "$nf" != "$h" ]; then refuse "$files_h lists $nf files, Size: says $h"; fi
  fi
  if [ -n "$tests_h" ] && [ -n "$t" ]; then
    nt=$(section_body "$f" "$tests_h" | { grep -acE '^[[:space:]]*[0-9]+\.' || true; })
    if [ "$t" -eq 0 ]; then
      if ! section_body "$f" "$tests_h" | grep -aqi 'test-free'; then
        refuse "Size: says 0 RED tests, and $tests_h does not declare the task test-free"
      fi
    elif [ "$nt" != "$t" ]; then
      refuse "$tests_h lists $nt numbered tests, Size: says $t"
    fi
  fi
  if [ -n "$proves_h" ]; then check_proves "$f" "$proves_h"; fi

  check_placeholders "$f"
  verdict
}

validate_story_body() { # <body file> [on-board]
  # "on-board": the body as the board holds it, so "## Tasks" carries the adapter's checklist. Without it
  # the create-time rule applies and that section must be empty.
  local f=$1 board=${2:-} last tl n want rows
  REFUSALS=()

  refuse_non_text "$f" || { verdict; return; }

  if [ -n "$board" ]; then check_sections "$f" story "" "## Tasks"
  else check_sections "$f" story "## Tasks"; fi
  local -a sections=("${SECTIONS[@]+"${SECTIONS[@]}"}")
  last=$({ grep -aE '^## ' "$f" || true; } | tail -1)
  if [ -n "$last" ] && [ "$last" != "## Tasks" ]; then
    refuse "\"## Tasks\" must be the last section — got \"$last\""
  fi

  local tl_h ac_h pm_h
  tl_h=$(section_of '## TL;DR' "${sections[@]+"${sections[@]}"}")
  ac_h=$(section_of '## Acceptance' "${sections[@]+"${sections[@]}"}")
  pm_h=$(section_of '## Proof map' "${sections[@]+"${sections[@]}"}")

  if [ -n "$tl_h" ]; then
    tl=$(section_body "$f" "$tl_h" | tr '\n' ' ' | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')
    if [ -n "$tl" ]; then
      if [ ${#tl} -gt 320 ]; then refuse "$tl_h is ${#tl} characters, the limit is 320"; fi
      case "$tl" in *'`'*) refuse "$tl_h carries a code span: it is written in the words a customer would use" ;; esac
      case "$tl" in */*) refuse "$tl_h carries a path: it is written in the words a customer would use" ;; esac
      if [[ $tl =~ (^|[^[:alnum:]])"$SIGIL"[0-9]+ ]]; then refuse "$tl_h references an item by number"; fi
    fi
  fi

  local -a ids=()
  if [ -n "$ac_h" ]; then
    mapfile -t ids < <(section_body "$f" "$ac_h" | sed -nE 's/^[[:space:]]*([0-9]+)\..*/\1/p')
    want=1
    for n in "${ids[@]+"${ids[@]}"}"; do
      if [ "$n" != "$want" ]; then
        refuse "criterion ids must run 1..n with no gap and no duplicate — expected $want, got $n"
        break
      fi
      want=$((want + 1))
    done
  fi
  if [ -n "$pm_h" ]; then
    for n in "${ids[@]+"${ids[@]}"}"; do
      rows=$(section_body "$f" "$pm_h" | { grep -acE "^[[:space:]]*\|[[:space:]]*$n[[:space:]]*\|" || true; })
      if [ "$rows" != 1 ]; then refuse "$pm_h has $rows rows for criterion $n, it needs exactly one"; fi
    done
  fi

  check_placeholders "$f"
  verdict
}

validate_plain_body() { # <kind> <body file> — bug and tech-debt: the checks that need no header contract
  REFUSALS=()
  refuse_non_text "$2" || { verdict; return; }
  check_sections "$2" "$1" ""
  check_placeholders "$2"
  verdict
}

story_create() {
  local title="" body=""
  while [ $# -gt 0 ]; do case "$1" in --title) title=$2; shift 2;; --body-file) body=$2; shift 2;; *) echo "bad arg $1" >&2; exit 1;; esac; done
  [ -n "$title" ] && [ -f "$body" ] || { echo "story create needs --title and --body-file" >&2; exit 1; }
  validate_story_body "$body" || exit 1
  "${GH[@]}" issue create --title "$title" --label story --body-file "$body" | issue_number_from_url
}

plain_create() { # <kind> --title T --body-file F — bug and tech-debt
  # No --role, and the shape is why. A task's role is a flag because the adapter owns that write: it puts
  # `role:<r>` on the item, and `next` and `status` read that label off task rows to say who owns the work.
  # Neither command looks at a bug or a tech-debt item, so the label buys no mechanism there — and the two
  # shapes do not ask for one. `item-tech-debt.md` names no role at all; `item-bug.md` carries its role in
  # the body's own first line, written by the role that wrote the body, where `check_placeholders` refuses
  # it unfilled — but only because `body_placeholders` unwraps a span holding nothing but a stub, since the
  # template writes that role inside backticks. This sentence was false until #41 made it true; the witness
  # is "bug create refuses a body whose role line is still the template's stub", and a simplification of
  # that unwrap takes this reason down with it. A flag would make the adapter write a second copy of a fact
  # the body states, with nothing holding the two equal — the disagreement `validate_plain_body` avoids by
  # having no header contract at all. A board that wants the label adds it with `gh issue edit
  # --add-label`, which skips no check because every check here is on the body.
  local kind=$1 title="" body=""; shift
  while [ $# -gt 0 ]; do case "$1" in --title) title=$2; shift 2;; --body-file) body=$2; shift 2;; *) echo "bad arg $1" >&2; exit 1;; esac; done
  [ -n "$title" ] && [ -f "$body" ] || { echo "$kind create needs --title and --body-file" >&2; exit 1; }
  validate_plain_body "$kind" "$body" || exit 1
  "${GH[@]}" issue create --title "$title" --label "$kind" --body-file "$body" | issue_number_from_url
}

task_create() {
  local story="" title="" role="" body="" blocked=""
  while [ $# -gt 0 ]; do case "$1" in
    --story) story=$2; shift 2;; --title) title=$2; shift 2;; --role) role=$2; shift 2;;
    --body-file) body=$2; shift 2;; --blocked-by) blocked=$2; shift 2;; *) echo "bad arg $1" >&2; exit 1;; esac; done
  [ -n "$story" ] && [ -n "$title" ] && [ -n "$role" ] && [ -f "$body" ] || { echo "task create needs --story --title --role --body-file" >&2; exit 1; }
  local blockers
  case "$blocked" in
    ""|none) blockers="none" ;;
    *) blockers=$(sed -E "s/[[:space:]]*,[[:space:]]*/, $SIGIL/g; s/^/$SIGIL/" <<<"$blocked") ;;
  esac
  local tmp; tmp=$(mktemp)
  { echo "Story: $SIGIL$story"; echo "Blocked by: $blockers"; echo; cat "$body"; } > "$tmp"
  validate_task_body "$tmp" "$story" || { rm -f "$tmp"; exit 1; }
  local n; n=$("${GH[@]}" issue create --title "$title" --label task --label "role:$role" --body-file "$tmp" | issue_number_from_url)
  rm -f "$tmp"
  # append to the story's task checklist
  local sb; sb=$("${GH[@]}" issue view "$story" --json body -q .body)
  if ! grep -q "^## Tasks" <<<"$sb"; then sb="$sb"$'\n\n## Tasks\n'; fi
  sb="$sb"$'\n'"- [ ] #$n ($role) $title"
  "${GH[@]}" issue edit "$story" --body "$sb" >/dev/null
  echo "$n"
}

# ---- lint: the same checks over bodies already in hand ------------------------------------------
# One `issue list --state all --limit $LINT_LIMIT --json number,labels,body` per kind — one invocation per
# kind, no fetch per item — then the create-time validators over each body. `lint` only reads: it never
# edits, comments on or closes anything.
#
# `--limit N` is an exact cap, and `gh` pages the API underneath it to satisfy N: 100 items come back per
# page and it keeps asking until it has N or the kind is exhausted (`gh issue list --repo cli/cli --limit
# 250` comes back with 250). So the cap costs only the pages a board actually fills — nothing on a small
# board — and the limit below holds a runaway one to twenty pages per kind. What the JSON cannot say is
# which of the two ended the fetch: a kind that comes back exactly full may have items the report never
# read, and printing a count for that reads as a clean board (#14). So the count is compared against the
# cap, and a full fetch is named in the closing line and exits 2 — a partial read, not a verdict.
# CREW_LINT_LIMIT lowers the cap, which is how the witness reaches saturation in three items.
LINT_LIMIT=${CREW_LINT_LIMIT:-2000}
# Bounded like SIZE_CAP, and for the same reason: a non-numeric or absurdly long value makes the `-ge`
# below exit 2 with "integer expected", which `if` reads as false — the saturation check would switch
# itself off silently, which is the very failure this block exists to prevent.
if ! [[ $LINT_LIMIT =~ ^[1-9][0-9]{0,5}$ ]]; then LINT_LIMIT=2000; fi

# The same exact cap, over the three fetches `next` and `status` make: open tasks, tasks of every state,
# open stories (#16). They shared nothing before — 200, 500 and 100 — and nothing about a board makes those
# three numbers differ: the cap is a runaway guard, not a tuning knob, and `gh` pages at 100 and stops when
# the label is exhausted, so one generous number costs each call only the pages that label actually fills.
# One limit is therefore one number to reason about, one guard and one seam; which fetch filled is said in
# the warning, so the three remain distinguishable where it matters.
#
# `next` and `status` are NOT reporters, which is the whole difference from `lint`. `lint` earns exit 2
# because a partial read has no verdict to give; these two print rows a lead acts on, and every row printed
# is real and claimable. A full fetch there does not invalidate the output, it only makes it incomplete —
# so stdout and the exit code are left exactly as they were and the warning goes to stderr. `/crew:next`
# parses stdout as a table and `--auto` starts work on its first row; `/crew:status` presents stdout
# unchanged. A non-zero exit neither skill expects would turn "there is more" into "this failed", and
# refuse work that is genuinely claimable — a worse failure than the one being fixed.
# CREW_BOARD_LIMIT lowers the cap, which is how the witness saturates in three canned items.
BOARD_LIMIT=${CREW_BOARD_LIMIT:-2000}
# Bounded for the reason LINT_LIMIT is: a non-numeric value makes the `-ge` exit 2 with "integer expected",
# which `if` reads as false, switching the check off in silence.
if ! [[ $BOARD_LIMIT =~ ^[1-9][0-9]{0,5}$ ]]; then BOARD_LIMIT=2000; fi

board_saturated() { # <count> <what filled> <what it costs the reader> -> one stderr line when the fetch came back full
  [ "$1" -ge "$BOARD_LIMIT" ] || return 0
  echo "warning: the $2 fetch filled its ${BOARD_LIMIT}-item limit, so $3" >&2
}

LINT_QUIET=0; LINT_OK=0; LINT_BAD=0

kind_of_labels() { # <json array of label NAMES> -> the first kind label it carries, or ""
  local k
  for k in "${KINDS[@]}"; do
    if jq -e --arg k "$k" 'index($k)' >/dev/null 2>&1 <<<"$1"; then echo "$k"; return 0; fi
  done
  return 0
}

lint_line() { # <number> <kind> <what is wrong> -> the report's one line for an item
  [ "$LINT_QUIET" = 1 ] && return 0
  printf '%s%-5s %-9s %s\n' "$SIGIL" "$1" "$2" "$3"
}

lint_body() { # <kind> <number> <body file> -> 0 when it conforms, 1 with its line printed when it does not
  local kind=$1 n=$2 f=$3 num line joined=""
  case "$kind" in
    task)  num=$(story_of_body < "$f")
           validate_task_body "$f" "$num" 2>/dev/null || true ;;
    story) validate_story_body "$f" on-board 2>/dev/null || true ;;
    *)     validate_plain_body "$kind" "$f" 2>/dev/null || true ;;
  esac
  [ ${#REFUSALS[@]} -eq 0 ] && return 0
  for line in "${REFUSALS[@]}"; do joined+="${line#refused: }; "; done
  lint_line "$n" "$kind" "${joined%; }"
  return 1
}

lint_rows() { # <kind, or "" to read it off each item's labels> <the json array from gh>
  local kind=$1 row n f k
  while IFS= read -r row; do
    [ -n "$row" ] || continue
    n=$(jq -r '.number // "?"' <<<"$row")
    k=$kind
    [ -n "$k" ] || k=$(kind_of_labels "$(jq -c '[(.labels // [])[].name]' <<<"$row")")
    if [ -z "$k" ]; then
      LINT_BAD=$((LINT_BAD + 1))
      lint_line "$n" "-" "no kind label: one of ${KINDS[*]} is what says which shape to check"
      continue
    fi
    f=$(mktemp); jq -r '.body // ""' <<<"$row" > "$f"
    if lint_body "$k" "$n" "$f"; then LINT_OK=$((LINT_OK + 1)); else LINT_BAD=$((LINT_BAD + 1)); fi
    rm -f "$f"
  done < <(jq -c '.[]' <<<"$2")
}

lint() {
  local one="" k rows count; local -a kinds=() filled=()
  LINT_QUIET=0; LINT_OK=0; LINT_BAD=0
  while [ $# -gt 0 ]; do case "$1" in
    --all)   kinds=("${KINDS[@]}"); shift ;;
    --kind)  [ $# -ge 2 ] || { echo "lint --kind needs one of: ${KINDS[*]}" >&2; exit 1; }
             kinds=("$2"); shift 2 ;;
    --quiet) LINT_QUIET=1; shift ;;
    *)       one=${1#"$SIGIL"}; shift
             [[ $one =~ ^[0-9]+$ ]] || { echo "lint takes [<n> | --all | --kind ${KINDS[*]}] [--quiet]" >&2; exit 1; } ;;
  esac; done
  if [ -n "$one" ] && [ ${#kinds[@]} -gt 0 ]; then
    # One target, named once: a number and a kind are two, and the number used to win in silence.
    echo "lint takes one target, not both: [<n> | --all | --kind ${KINDS[*]}] [--quiet]" >&2; exit 1
  fi
  for k in "${kinds[@]+"${kinds[@]}"}"; do
    case " ${KINDS[*]} " in *" $k "*) ;; *) echo "lint --kind takes one of: ${KINDS[*]} (got '$k')" >&2; exit 1 ;; esac
  done
  if [ -n "$one" ]; then
    lint_rows "" "$("${GH[@]}" issue view "$one" --json number,labels,body | jq -c '[.]')"
  elif [ ${#kinds[@]} -eq 0 ]; then
    echo "lint takes [<n> | --all | --kind ${KINDS[*]}] [--quiet]" >&2; exit 1
  else
    for k in "${kinds[@]}"; do
      rows=$("${GH[@]}" issue list --label "$k" --state all --limit "$LINT_LIMIT" --json number,labels,body)
      count=$(jq 'length' <<<"$rows")
      if [ "$count" -ge "$LINT_LIMIT" ]; then filled+=("$k"); fi
      lint_rows "$k" "$rows"
    done
  fi
  local partial=""
  if [ ${#filled[@]} -gt 0 ]; then
    for k in "${filled[@]}"; do partial+="${partial:+, }$k"; done
    partial=" — the fetch filled its ${LINT_LIMIT}-item limit on: $partial; items of that kind beyond it were not judged"
  fi
  echo "$LINT_OK conforming, $LINT_BAD not$partial"
  # Exit 2 before the verdict, because an incomplete read has no verdict to give: 1 says the items it read
  # do not all conform, and a caller that treats 1 as "the board is known" must not get it from a partial read.
  [ ${#filled[@]} -eq 0 ] || return 2
  [ "$LINT_BAD" -eq 0 ]
}

claim() {
  local n=$1
  local cur; cur=$("${GH[@]}" issue view "$n" --json assignees,labels,state,body -q '{a:[.assignees[].login], l:[.labels[].name], s:.state, b:.body}')
  [ "$(jq -r .s <<<"$cur")" = "OPEN" ] || { echo "#$n is not open" >&2; exit 3; }
  if jq -e '.l | index("in-progress")' <<<"$cur" >/dev/null; then
    echo "#$n is already claimed by $(jq -r '.a | join(",")' <<<"$cur")" >&2; exit 3
  fi
  # D7: an item filed before this shape existed is still claimable. The lint lines come back as warnings
  # and the claim proceeds untouched — refusing here would strand every item on the board and turn a claim
  # into a migration. The lead brings the body to shape in one edit; `claim` never edits it.
  local kind f
  kind=$(kind_of_labels "$(jq -c .l <<<"$cur")")
  if [ -n "$kind" ]; then
    LINT_QUIET=0
    f=$(mktemp); jq -r '.b // ""' <<<"$cur" > "$f"
    lint_body "$kind" "$n" "$f" 2>/dev/null | sed 's/^/warning: /' >&2 || true
    rm -f "$f"
  fi
  "${GH[@]}" issue edit "$n" --add-assignee @me --add-label in-progress --remove-label in-review >/dev/null 2>&1 || "${GH[@]}" issue edit "$n" --add-assignee @me --add-label in-progress >/dev/null
  "${GH[@]}" issue comment "$n" --body "claimed-by: $(hostname) at $(date -Is)${CREW_SESSION:+ (session $CREW_SESSION)}" >/dev/null
  echo "claimed #$n"
}

release() {
  local n=$1 to=""
  shift; while [ $# -gt 0 ]; do case "$1" in --to) to=$2; shift 2;; *) echo "bad arg $1" >&2; exit 1;; esac; done
  case "$to" in
    in-review) "${GH[@]}" issue edit "$n" --remove-label in-progress --add-label in-review >/dev/null ;;
    blocked)   "${GH[@]}" issue edit "$n" --remove-label in-progress --add-label blocked >/dev/null ;;
    open)      "${GH[@]}" issue edit "$n" --remove-label in-progress --remove-assignee @me >/dev/null ;;
    # `done` is the transition that means finished, and it is one act: every lane label off, the item
    # closed, the assignee kept — who did the work is the one thing a closed item should still record.
    # The labels it carries are read first because `gh issue edit --remove-label` fails WHOLE on a label
    # the item does not have (the same reason `claim` keeps a fallback), and a failed edit would leave a
    # closed item wearing `in-progress`, which is the state this transition exists to retire.
    done)
      local lanes; lanes=$("${GH[@]}" issue view "$n" --json labels -q '[.labels[].name]')
      local -a off=(); local l
      for l in in-progress in-review blocked; do
        if jq -e --arg l "$l" 'index($l)' <<<"$lanes" >/dev/null; then off+=(--remove-label "$l"); fi
      done
      if [ ${#off[@]} -gt 0 ]; then "${GH[@]}" issue edit "$n" "${off[@]}" >/dev/null; fi
      "${GH[@]}" issue close "$n" >/dev/null ;;
    *) echo "release needs --to in-review|blocked|open|done" >&2; exit 1 ;;
  esac
  echo "released #$n -> $to"
}

blockers_open() { # prints 1 if any "Blocked by: #a, #b" issue is still open
  local body=$1 any=0
  for b in $(grep -oE '^Blocked by:.*' <<<"$body" | grep -oE '#[0-9]+' | tr -d '#'); do
    [ "$("${GH[@]}" issue view "$b" --json state -q .state)" = "OPEN" ] && any=1
  done
  echo $any
}

next() {
  local rows; rows=$("${GH[@]}" issue list --label task --state open --limit "$BOARD_LIMIT" --json number,title,labels,assignees,body)
  jq -c '.[] | select((.assignees|length)==0) | select([.labels[].name] | (index("in-progress") or index("in-review") or index("blocked")) | not)' <<<"$rows" \
  | while read -r row; do
      n=$(jq -r .number <<<"$row"); body=$(jq -r .body <<<"$row")
      [ "$(blockers_open "$body")" = "0" ] || continue
      role=$(jq -r '[.labels[].name | select(startswith("role:"))][0] // "-"' <<<"$row")
      story=$(story_of_body <<<"$body")
      printf '#%s\t%s\tstory #%s\t%s\n' "$n" "$role" "${story:-?}" "$(jq -r .title <<<"$row")"
    done
  # After the rows, because it qualifies them: the rows above are claimable, there are simply more.
  board_saturated "$(jq 'length' <<<"$rows")" open-task "claimable tasks beyond it are not offered here"
}

status() {
  local tasks stories
  tasks=$("${GH[@]}" issue list --label task --state all --limit "$BOARD_LIMIT" --json number,title,state,labels,assignees,body)
  stories=$("${GH[@]}" issue list --label story --state open --limit "$BOARD_LIMIT" --json number,title,labels)
  jq -r '.[] | "\(.number)\t\(.title)"' <<<"$stories" \
  | while IFS=$'\t' read -r sn st; do
      sub=$(jq -c --arg s "Story: #$sn" '[.[] | select(.body | startswith($s))]' <<<"$tasks")
      total=$(jq 'length' <<<"$sub"); done_=$(jq '[.[] | select(.state=="CLOSED")] | length' <<<"$sub")
      prog=$(jq '[.[] | select([.labels[].name] | index("in-progress"))] | length' <<<"$sub")
      rev=$(jq '[.[] | select([.labels[].name] | index("in-review"))] | length' <<<"$sub")
      blk=$(jq '[.[] | select([.labels[].name] | index("blocked"))] | length' <<<"$sub")
      printf '#%s  %s\n    tasks %s/%s done, %s in progress, %s in review, %s blocked\n' "$sn" "$st" "$done_" "$total" "$prog" "$rev" "$blk"
      jq -r '.[] | "    #\(.number) [\(.state|ascii_downcase)] \([.labels[].name | select(startswith("role:"))][0] // "-") \(.title)\(if (.assignees|length)>0 then " @" + (.assignees[0].login) else "" end)"' <<<"$sub"
    done
  # Two fetches, each able to fill on its own, so each is judged on its own and named for what it costs.
  board_saturated "$(jq 'length' <<<"$tasks")" task-rollup "every story's task counts are a lower bound"
  board_saturated "$(jq 'length' <<<"$stories")" open-story "stories beyond it are absent from this board"
}

# `--comments` replaces the view with the comment stream rather than adding to it, so the title, the
# labels, the state and the whole body need their own read: the item first, its comments after it.
show() { "${GH[@]}" issue view "$1"; printf '\n--- comments ---\n\n'; "${GH[@]}" issue view "$1" --comments; }
comment() { local n=$1; shift; local f=""; while [ $# -gt 0 ]; do case "$1" in --body-file) f=$2; shift 2;; *) exit 1;; esac; done; "${GH[@]}" issue comment "$n" --body-file "$f" >/dev/null; echo "commented on #$n"; }

cmd=${1:-}; shift || true
case "$cmd" in
  ensure-labels) ensure_labels ;;
  story) sub=${1:-}; shift || true; [ "$sub" = create ] && story_create "$@" || { echo "story create ..." >&2; exit 1; } ;;
  task)  sub=${1:-}; shift || true; [ "$sub" = create ] && task_create "$@"  || { echo "task create ..." >&2; exit 1; } ;;
  bug|tech-debt) sub=${1:-}; shift || true; [ "$sub" = create ] && plain_create "$cmd" "$@" || { echo "$cmd create --title T --body-file F" >&2; exit 1; } ;;
  claim) claim "$@" ;;
  lint) lint "$@" ;;
  release) release "$@" ;;
  next) next ;;
  status) status ;;
  show) show "$@" ;;
  comment) comment "$@" ;;
  *) sed -n '2,16p' "$0"; exit 1 ;;
esac
