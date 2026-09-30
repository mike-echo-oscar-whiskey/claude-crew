#!/usr/bin/env bash
# Witness for the reviewer-isolation contract: the review step, the work step and the three review
# personas are read as files in this tree, and every sentence the contract rests on is asserted
# present by name — the forbidden brief items, the reproduction rule, the `## Questions` section and
# the before-review file count. Run it bare:
#   bash plugins/crew/scripts/tests/review-contract.test.sh
# Exits 0 when every case passes, 1 when any sentence is missing, and names the case either way.
set -u

here=$(cd "$(dirname "$0")" && pwd)
crew=$(cd "$here/../.." && pwd)
fails=0

pass() { echo "  ok   $1"; }
fail() { echo "  FAIL $1"; echo "       $2"; fails=$((fails + 1)); }

# needs <file-relative-to-plugins/crew> <literal> <label>
needs() {
  local rel=$1 lit=$2 label=$3
  local f="$crew/$rel"
  if [ ! -f "$f" ]; then fail "$label" "$rel is not there"; return; fi
  if grep -qF -- "$lit" "$f"; then pass "$label"; else fail "$label" "$rel does not state: $lit"; fi
}

# needs_re <file-relative-to-plugins/crew> <extended-regex> <label>
needs_re() {
  local rel=$1 re=$2 label=$3
  local f="$crew/$rel"
  if [ ! -f "$f" ]; then fail "$label" "$rel is not there"; return; fi
  if grep -qE -- "$re" "$f"; then pass "$label"; else fail "$label" "$rel does not match: $re"; fi
}

review=skills/review/SKILL.md
work=skills/work/SKILL.md
personas="agents/architect.md agents/qa-engineer.md agents/security-engineer.md"

echo "review-contract.sh"

# D14: both steps forbid the account of the work by name, and say the list is a prohibition.
for f in "$review" "$work"; do
  needs "$f" "implementer's report" "$f forbids the implementer's report by name"
  needs "$f" "summary or narrative of what changed" "$f forbids the lead's own summary or narrative by name"
  needs "$f" "earlier round's findings" "$f forbids an earlier round's findings by name"
  needs "$f" "prohibition, not a default" "$f says the list is a prohibition, not a default"
done

# D16: the reproduction rule, in one disjunction, in both steps and all three review personas.
for f in "$review" "$work" $personas; do
  needs "$f" "names the command whose output shows it or quotes the line" \
    "$f states the reproduction rule as a command-or-quoted-line disjunction"
done

# F1: the output contract of each review persona permits the section the Findings line requires.
for f in $personas; do
  needs_re "$f" '^## Questions +—' "$f permits ## Questions as a top-level section"
  needs "$f" '## Open questions' "$f keeps ## Open questions distinct"
done

# D11, third check moment: the before-review file count, its `generated:` removal and its over-cap branch.
needs "$work" 'git diff --name-only' "$work counts the committed diff before any reviewer is briefed"
needs "$work" '`generated:` globs removed' "$work removes the generated paths from that count"
needs "$work" 'Over the cap with no `Exception:`' "$work states the over-cap branch instead of opening the review"

if [ "$fails" -eq 0 ]; then echo "PASS"; exit 0; fi
echo "FAIL ($fails)"; exit 1
