#!/usr/bin/env bash
# Purpose: tracker adapter for the crew pipeline. Backend from the project profile
#          (`tracker: github <owner>/<repo>`). Azure DevOps backend not implemented yet.
# Usage:
#   tracker.sh ensure-labels
#   tracker.sh story create --title T --body-file F                  -> prints issue number
#   tracker.sh task  create --story N --title T --role R --body-file F [--blocked-by "12,13"]
#   tracker.sh claim N                (assign @me, label in-progress, comment claimed-by)
#   tracker.sh release N --to in-review|blocked|open
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
if [ "$SIZE_CAP" != "-" ] && ! [[ $SIZE_CAP =~ ^[0-9]+$ ]]; then SIZE_CAP=15; fi
GENERATED=$(crew_profile_value "$profile" generated || true); GENERATED=${GENERATED//,/ }
case "$GENERATED" in -) GENERATED="" ;; esac

ROLES=(product-owner architect frontend-engineer backend-engineer integration-engineer event-sourcing-engineer genai-engineer agentic-ai-engineer multitenancy-engineer commercial-analyst qa-engineer security-engineer cloud-engineer ux-designer privacy-and-compliance technical-writer)

ensure_labels() {
  "${GH[@]}" label create story             --color 0E6B52 --description "Functional story (crew pipeline)" --force >/dev/null
  "${GH[@]}" label create task              --color 1D76DB --description "Implementation task under a story" --force >/dev/null
  "${GH[@]}" label create in-progress       --color FBCA04 --description "Claimed by a session" --force >/dev/null
  "${GH[@]}" label create in-review         --color 5319E7 --description "PR open, awaiting merge" --force >/dev/null
  "${GH[@]}" label create blocked           --color B60205 --description "Cannot proceed; see body" --force >/dev/null
  "${GH[@]}" label create needs-refinement  --color D4C5F9 --description "Story not ready for planning" --force >/dev/null
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

section_body() { awk -v h="$2" '$0 == h {f = 1; next} /^## /{f = 0} f' "$1"; }
section_has_text() { [ -n "$(section_body "$1" "$2" | tr -d '[:space:]')" ]; }

body_placeholders() { # <file> -> the template stubs still in the body, one per line
  # The body is joined into one line first: a code span and a stub both wrap across line breaks,
  # so a line-at-a-time scan reports a wrapped `<…>` inside backticks as unfilled.
  tr '\n' '\001' < "$1" | sed -E 's/`[^`]*`//g' \
    | { grep -oE '<!--|<[^<>[:space:]/][^<>]*>' || true; } \
    | { grep -vE '^<https?:' || true; } | tr '\001' ' ' | sort -u
}

files_hand_written() { # <file> <heading> -> bullets whose path is not a generated: glob
  local n=0 line p glob
  while IFS= read -r line; do
    p=$(sed -nE 's/^[[:space:]]*-[[:space:]]*`([^`]*)`.*/\1/p' <<<"$line")
    if [ -n "$GENERATED" ] && [ -n "$p" ]; then
      for glob in $GENERATED; do
        # shellcheck disable=SC2053  # the profile's value is a glob on purpose
        if [[ $p == $glob ]]; then continue 2; fi
      done
    fi
    n=$((n + 1))
  done < <(section_body "$1" "$2" | { grep -E '^[[:space:]]*- ' || true; })
  echo "$n"
}

REFUSALS=()
refuse() { REFUSALS+=("refused: $1"); }
verdict() { # 0 when the body conforms; otherwise every failing check on stderr, one per line
  if [ ${#REFUSALS[@]} -eq 0 ]; then return 0; fi
  printf '%s\n' "${REFUSALS[@]}" >&2
  return 1
}

validate_task_body() { # <assembled body file> <story as given>
  local f=$1 num=${2//[!0-9]/} first key size h="" t="" sec nf nt ph line
  REFUSALS=()

  first=$(head -1 "$f")
  if [ "$first" != "Story: $SIGIL$num" ]; then
    refuse "first line must be \"Story: $SIGIL$num\" (the board rolls tasks up by it) — got \"$first\""
  fi
  for key in "Blocked by:" "Role:" "Size:"; do
    if ! grep -qE "^$key" "$f"; then refuse "the \"$key\" line is missing"; fi
  done

  size=$(grep -m1 '^Size:' "$f" || true)
  if [[ $size =~ ^Size:[[:space:]]*([0-9]+)[[:space:]]+hand-written[[:space:]]+files[[:space:]]*\([[:space:]]*\+[[:space:]]*[0-9]+[[:space:]]+generated\)[^0-9]*([0-9]+)[[:space:]]+RED ]]; then
    h=${BASH_REMATCH[1]}; t=${BASH_REMATCH[2]}
  elif [ -n "$size" ]; then
    refuse "Size: must read \"<H> hand-written files (+ <G> generated) · <T> RED tests · one PR\" — got \"$size\""
  fi
  if [ -n "$h" ]; then
    if ! grep -qE '^(Split line:|Exception:)' "$f" && { [ "$h" -ge 12 ] || [ "$t" -ge 4 ]; }; then
      refuse "a task of $h files and $t RED tests needs a \"Split line:\" or an \"Exception:\" line"
    fi
    if [ "$SIZE_CAP" != "-" ] && [ "$h" -gt "$SIZE_CAP" ] && ! grep -qE '^Exception:' "$f"; then
      refuse "Size: $h hand-written files is over size-cap: $SIZE_CAP, and no \"Exception:\" line licenses it"
    fi
  fi

  local -a sections=()
  mapfile -t sections < <(template_sections task)
  if [ ${#sections[@]} -eq 0 ]; then
    refuse "no task template at $(item_template task) to read the required sections from"
  fi
  for sec in "${sections[@]}"; do
    if ! grep -qxF "$sec" "$f"; then refuse "section \"$sec\" is missing"
    elif ! section_has_text "$f" "$sec"; then refuse "section \"$sec\" is empty"; fi
  done

  local files_h tests_h proves_h
  files_h=$(section_of '## Files' "${sections[@]+"${sections[@]}"}")
  tests_h=$(section_of '## Tests' "${sections[@]+"${sections[@]}"}")
  proves_h=$(section_of '## Proves' "${sections[@]+"${sections[@]}"}")

  if [ -n "$files_h" ] && [ -n "$h" ]; then
    nf=$(files_hand_written "$f" "$files_h")
    if [ "$nf" != "$h" ]; then refuse "$files_h lists $nf files, Size: says $h"; fi
  fi
  if [ -n "$tests_h" ] && [ -n "$t" ]; then
    nt=$(section_body "$f" "$tests_h" | { grep -cE '^[[:space:]]*[0-9]+\.' || true; })
    if [ "$t" -eq 0 ]; then
      if ! section_body "$f" "$tests_h" | grep -qi 'test-free'; then
        refuse "Size: says 0 RED tests, and $tests_h does not declare the task test-free"
      fi
    elif [ "$nt" != "$t" ]; then
      refuse "$tests_h lists $nt numbered tests, Size: says $t"
    fi
  fi
  if [ -n "$proves_h" ] && ! section_body "$f" "$proves_h" | grep -qE 'AC[[:space:]]+[0-9]+'; then
    refuse "$proves_h names no criterion: it needs at least one \"AC <n>\" reference"
  fi

  ph=$(body_placeholders "$f")
  if [ -n "$ph" ]; then
    while IFS= read -r line; do refuse "unfilled template placeholder — $line"; done <<<"$ph"
  fi
  verdict
}

validate_story_body() { # <body file>
  local f=$1 sec last tl n want rows ph line
  REFUSALS=()

  local -a sections=()
  mapfile -t sections < <(template_sections story)
  if [ ${#sections[@]} -eq 0 ]; then
    refuse "no story template at $(item_template story) to read the required sections from"
  fi
  for sec in "${sections[@]}"; do
    if ! grep -qxF "$sec" "$f"; then refuse "section \"$sec\" is missing"; continue; fi
    if [ "$sec" = "## Tasks" ]; then
      if section_has_text "$f" "$sec"; then refuse "\"## Tasks\" must be empty: the adapter appends the checklist there"; fi
    elif ! section_has_text "$f" "$sec"; then refuse "section \"$sec\" is empty"; fi
  done
  last=$({ grep -E '^## ' "$f" || true; } | tail -1)
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
      rows=$(section_body "$f" "$pm_h" | { grep -cE "^[[:space:]]*\|[[:space:]]*$n[[:space:]]*\|" || true; })
      if [ "$rows" != 1 ]; then refuse "$pm_h has $rows rows for criterion $n, it needs exactly one"; fi
    done
  fi

  ph=$(body_placeholders "$f")
  if [ -n "$ph" ]; then
    while IFS= read -r line; do refuse "unfilled template placeholder — $line"; done <<<"$ph"
  fi
  verdict
}

story_create() {
  local title="" body=""
  while [ $# -gt 0 ]; do case "$1" in --title) title=$2; shift 2;; --body-file) body=$2; shift 2;; *) echo "bad arg $1" >&2; exit 1;; esac; done
  [ -n "$title" ] && [ -f "$body" ] || { echo "story create needs --title and --body-file" >&2; exit 1; }
  validate_story_body "$body" || exit 1
  "${GH[@]}" issue create --title "$title" --label story --body-file "$body" | issue_number_from_url
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

claim() {
  local n=$1
  local cur; cur=$("${GH[@]}" issue view "$n" --json assignees,labels,state -q '{a:[.assignees[].login], l:[.labels[].name], s:.state}')
  [ "$(jq -r .s <<<"$cur")" = "OPEN" ] || { echo "#$n is not open" >&2; exit 3; }
  if jq -e '.l | index("in-progress")' <<<"$cur" >/dev/null; then
    echo "#$n is already claimed by $(jq -r '.a | join(",")' <<<"$cur")" >&2; exit 3
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
    *) echo "release needs --to in-review|blocked|open" >&2; exit 1 ;;
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
  "${GH[@]}" issue list --label task --state open --limit 200 --json number,title,labels,assignees,body \
  | jq -c '.[] | select((.assignees|length)==0) | select([.labels[].name] | (index("in-progress") or index("in-review") or index("blocked")) | not)' \
  | while read -r row; do
      n=$(jq -r .number <<<"$row"); body=$(jq -r .body <<<"$row")
      [ "$(blockers_open "$body")" = "0" ] || continue
      role=$(jq -r '[.labels[].name | select(startswith("role:"))][0] // "-"' <<<"$row")
      story=$(grep -oE '^Story: #[0-9]+' <<<"$body" | grep -oE '[0-9]+' || true)
      printf '#%s\t%s\tstory #%s\t%s\n' "$n" "$role" "${story:-?}" "$(jq -r .title <<<"$row")"
    done
}

status() {
  local tasks; tasks=$("${GH[@]}" issue list --label task --state all --limit 500 --json number,title,state,labels,assignees,body)
  "${GH[@]}" issue list --label story --state open --limit 100 --json number,title,labels \
  | jq -r '.[] | "\(.number)\t\(.title)"' \
  | while IFS=$'\t' read -r sn st; do
      sub=$(jq -c --arg s "Story: #$sn" '[.[] | select(.body | startswith($s))]' <<<"$tasks")
      total=$(jq 'length' <<<"$sub"); done_=$(jq '[.[] | select(.state=="CLOSED")] | length' <<<"$sub")
      prog=$(jq '[.[] | select([.labels[].name] | index("in-progress"))] | length' <<<"$sub")
      rev=$(jq '[.[] | select([.labels[].name] | index("in-review"))] | length' <<<"$sub")
      blk=$(jq '[.[] | select([.labels[].name] | index("blocked"))] | length' <<<"$sub")
      printf '#%s  %s\n    tasks %s/%s done, %s in progress, %s in review, %s blocked\n' "$sn" "$st" "$done_" "$total" "$prog" "$rev" "$blk"
      jq -r '.[] | "    #\(.number) [\(.state|ascii_downcase)] \([.labels[].name | select(startswith("role:"))][0] // "-") \(.title)\(if (.assignees|length)>0 then " @" + (.assignees[0].login) else "" end)"' <<<"$sub"
    done
}

show() { "${GH[@]}" issue view "$1" --comments; }
comment() { local n=$1; shift; local f=""; while [ $# -gt 0 ]; do case "$1" in --body-file) f=$2; shift 2;; *) exit 1;; esac; done; "${GH[@]}" issue comment "$n" --body-file "$f" >/dev/null; echo "commented on #$n"; }

cmd=${1:-}; shift || true
case "$cmd" in
  ensure-labels) ensure_labels ;;
  story) sub=${1:-}; shift || true; [ "$sub" = create ] && story_create "$@" || { echo "story create ..." >&2; exit 1; } ;;
  task)  sub=${1:-}; shift || true; [ "$sub" = create ] && task_create "$@"  || { echo "task create ..." >&2; exit 1; } ;;
  claim) claim "$@" ;;
  release) release "$@" ;;
  next) next ;;
  status) status ;;
  show) show "$@" ;;
  comment) comment "$@" ;;
  *) sed -n '2,14p' "$0"; exit 1 ;;
esac
