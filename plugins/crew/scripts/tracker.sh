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
  github) REPO=$target ;;
  azure-devops) echo "tracker backend azure-devops is not implemented yet (profile: $tracker)" >&2; exit 2 ;;
  *) echo "no usable 'tracker:' line in $profile (got: '$tracker')" >&2; exit 2 ;;
esac
GH=(gh --repo "$REPO")

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

story_create() {
  local title="" body=""
  while [ $# -gt 0 ]; do case "$1" in --title) title=$2; shift 2;; --body-file) body=$2; shift 2;; *) echo "bad arg $1" >&2; exit 1;; esac; done
  [ -n "$title" ] && [ -f "$body" ] || { echo "story create needs --title and --body-file" >&2; exit 1; }
  "${GH[@]}" issue create --title "$title" --label story --body-file "$body" | issue_number_from_url
}

task_create() {
  local story="" title="" role="" body="" blocked=""
  while [ $# -gt 0 ]; do case "$1" in
    --story) story=$2; shift 2;; --title) title=$2; shift 2;; --role) role=$2; shift 2;;
    --body-file) body=$2; shift 2;; --blocked-by) blocked=$2; shift 2;; *) echo "bad arg $1" >&2; exit 1;; esac; done
  [ -n "$story" ] && [ -n "$title" ] && [ -n "$role" ] && [ -f "$body" ] || { echo "task create needs --story --title --role --body-file" >&2; exit 1; }
  local tmp; tmp=$(mktemp)
  { echo "Story: #$story"; [ -n "$blocked" ] && echo "Blocked by: $(sed -E 's/[[:space:]]*,[[:space:]]*/, #/g; s/^/#/' <<<"$blocked")"; echo; cat "$body"; } > "$tmp"
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
