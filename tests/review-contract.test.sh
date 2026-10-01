#!/usr/bin/env bash
# Witness for the reviewer-isolation contract: the review step, the work step and the three review
# personas are read as files in this tree, and every sentence the contract rests on is asserted
# present by name — the forbidden brief items, the reproduction rule, the severity obligations, the
# `## Questions` section, the before-review file count and the one-round ceiling, which is also
# asserted by its absence: no file the plugin ships may permit a second round. Run it bare:
#   bash tests/review-contract.test.sh
# Exits 0 when every case passes, 1 when any sentence is missing, and names the case either way.
set -u

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/.." && pwd)
crew="$root/plugins/crew"
fails=0

pass() { echo "  ok   $1"; }
fail() { echo "  FAIL $1"; echo "       $2"; fails=$((fails + 1)); }

# resolve <path> — an absolute path as given, anything else relative to plugins/crew.
resolve() { case $1 in /*) echo "$1" ;; *) echo "$crew/$1" ;; esac; }

# needs <file-relative-to-plugins/crew-or-absolute> <literal> <label>
needs() {
  local rel=$1 lit=$2 label=$3
  local f; f=$(resolve "$rel")
  if [ ! -f "$f" ]; then fail "$label" "$rel is not there"; return; fi
  if grep -qF -- "$lit" "$f"; then pass "$label"; else fail "$label" "$rel does not state: $lit"; fi
}

# needs_re <file-relative-to-plugins/crew-or-absolute> <extended-regex> <label>
needs_re() {
  local rel=$1 re=$2 label=$3
  local f; f=$(resolve "$rel")
  if [ ! -f "$f" ]; then fail "$label" "$rel is not there"; return; fi
  if grep -qE -- "$re" "$f"; then pass "$label"; else fail "$label" "$rel does not match: $re"; fi
}

# lacks_re <extended-regex> <label>
# The absence half of the ceiling: every markdown file the plugin ships, and the README beside it,
# searched for a sentence that would permit a second round. Zero matches is a non-zero exit from
# grep, so this check stands alone and is judged on the hits themselves rather than on an exit code.
lacks_re() {
  local re=$1 label=$2
  local hits
  hits=$(find "$crew" "$readme" -type f -name '*.md' -exec grep -nEi -- "$re" {} +)
  if [ -z "$hits" ]; then pass "$label"; else fail "$label" "a second round is permitted by: $hits"; fi
}

review=skills/review/SKILL.md
work=skills/work/SKILL.md
operating=templates/operating-model.md
readme="$root/README.md"  # the repository's own README, beside the payload rather than inside it
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

# #18: the verification rule covers any command a lead reports, with all four specifics by name.
needs "$operating" "runs bare and alone" "$operating states the verification rule for any command a lead reports"
needs "$operating" "nothing chained after it" "$operating forbids a chain after the command being judged"
needs "$operating" "exit non-zero on zero matches" "$operating keeps an absence or count check out of a chain"
needs "$operating" "written against text you have read" "$operating requires a pattern written from the file, not from memory"
needs "$operating" '^{commit}' "$operating resolves a git object comparison to ^{commit}"

# #26 / AC2: the severity obligations, in every place that files a finding. The reproduction rule
# above says when a finding stands; these three say what standing obliges, and a reworded obligation
# in any one of the five files fails here instead of passing unnoticed.
for f in "$review" "$work" $personas; do
  needs_re "$f" 'a `p1` is always fixed before th(e|is) change is offered' \
    "$f states that a p1 blocks and is fixed before the change is offered"
  needs_re "$f" 'a `p2` is fixed (in this change|here) (only )?when this change caused it or made it reachable' \
    "$f fixes here a p2 this change caused or made reachable"
  needs_re "$f" 'a pre-existing `p2` the diff merely sits beside is[^.]*(deferred to|costs) one line in[^.]*its own item in the tracker' \
    "$f defers a pre-existing p2 to one line in the change set's description and its own item"
done

# #26 / AC3: one round of agent review is the ceiling, in the review step and in the README, and no
# sentence anywhere permits a second.
needs "$review" "One round of agent review is the ceiling" \
  "$review states that one round of agent review is the ceiling"
needs "$review" "a contested finding goes to the user" \
  "$review sends a contested finding to the user"
needs "$review" "never to a second in-session pass by readers who have taken a position" \
  "$review refuses a second in-session pass by readers who have taken a position"
needs "$review" "a net under the human review, never a substitute for it" \
  "$review calls the agent review a net under the human's own"
needs "$readme" "one round is the ceiling" \
  "the README states that one round is the ceiling"
needs "$readme" "a contested finding goes to you rather than to a second pass in the same session" \
  "the README sends a contested finding to the human rather than to a second pass"
needs "$readme" "An agent review is a net under your own, never a substitute for it" \
  "the README calls the agent review a net under the human's own"
lacks_re '(second|another) (in-session |agent )?(round|pass)[^.]{0,60} (may|can|is allowed|is permitted|if needed|when needed)|(may|can|is allowed to|is permitted to)[^.]{0,40} (second|another) (in-session )?(round|pass)' \
  "no sentence the plugin ships permits a second in-session round"

if [ "$fails" -eq 0 ]; then echo "PASS"; exit 0; fi
echo "FAIL ($fails)"; exit 1
