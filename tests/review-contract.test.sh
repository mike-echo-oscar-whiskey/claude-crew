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

# lacks_blocking_on_toothless <label>
# The absence half of the calibration, written the way the ceiling's absence check above is written:
# every markdown file the plugin ships, and the README beside it, searched for a sentence that would
# block a change on a check that cannot fail. The shipped sentences state that rule as a refusal
# ("never blocks"), and the refusal sits in the same clause as the verb, so each file is first split
# into clauses on `.`, `;` and `:` — a clause that names a toothless check and an obligation to block,
# and does not refuse it, is a hit. Splitting first is what gives this teeth: a blocking clause added
# beside a refusing one is judged on its own rather than excused by its neighbour. Zero hits is a
# non-zero exit from grep, so this check stands alone and is judged on the hits themselves.
lacks_blocking_on_toothless() {
  local label=$1
  local hits="" f clause
  while IFS= read -r f; do
    clause=$(tr '\n' ' ' <"$f" | sed 's/\([.;:]\) /\1\n/g' \
      | grep -Ei -- 'cannot fail|could not fail|toothless' \
      | grep -Ei -- 'blocks|p1|fixed before th(e|is) change is offered|sends? the change back|requests? changes' \
      | grep -Eiv -- 'never')
    [ -n "$clause" ] && hits="$hits${f#"$root/"}: $clause"$'\n'
  done < <(find "$crew" "$readme" -type f -name '*.md')
  if [ -z "$hits" ]; then pass "$label"; else fail "$label" "a toothless check blocks a change by: $hits"; fi
}

review=skills/review/SKILL.md
work=skills/work/SKILL.md
operating=templates/operating-model.md
profile=templates/profile.md
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

# #43 / AC2: what the blocking severity is reserved for, and the route for a finding whose subject is
# a check rather than the code. Not a loop: the five sentences are deliberately not copies of one
# another, each written in its own file's voice, so each half is asserted against that file's own
# words — a shared tolerant regex here would pass on a sentence that no longer carries the rule.
needs "$review" "What the blocking severity is *for* bounds what may block: harm a person can meet" \
  "$review reserves the blocking severity for harm a person can meet"
needs "$review" "is one severity down and never blocks the change" \
  "$review sends a check that cannot fail on correct code one severity down"
needs "$work" "The blocking severity is reserved for harm a person can meet" \
  "$work reserves the blocking severity for harm a person can meet"
needs "$work" "is rated one severity lower and never sends the change back" \
  "$work sends a check that cannot fail on correct code one severity down"
needs agents/architect.md "Reserve the blocking rating for harm a person can meet" \
  "agents/architect.md reserves the blocking rating for harm a person can meet"
needs agents/architect.md 'over code that is correct, is a `p2` and never blocks,' \
  "agents/architect.md sends a check that cannot fail on correct code one severity down"
needs agents/qa-engineer.md "the blocking rating is for harm a person can meet" \
  "agents/qa-engineer.md reserves the blocking rating for harm a person can meet"
needs agents/qa-engineer.md "is one severity below the anchor's rating and never blocks the change" \
  "agents/qa-engineer.md sends a survived mutant over correct code one severity down"
needs agents/security-engineer.md "The blocking rating answers harm a person can meet" \
  "agents/security-engineer.md reserves the blocking rating for harm a person can meet"
needs agents/security-engineer.md 'is a `p2` that never blocks this change' \
  "agents/security-engineer.md sends a check that cannot fail on correct code one severity down"
# The one phrase the five share, asserted on its own because the absence check below searches for it:
# a file that reworded it would keep its own two cases green while dropping out of the sweep.
for f in "$review" "$work" $personas; do
  needs "$f" "cannot fail for the reason it" \
    "$f names the check by what it cannot do, in the words the absence sweep searches for"
done
lacks_blocking_on_toothless \
  "no sentence the plugin ships blocks a change on a toothless check"

# #40 / AC2: the route the reproduction rule leads to. The disjunction above says when a finding
# stands; this asserts what a claim without one becomes — a question marked *believed* rather than a
# finding — by the word the criterion's prover names, in both steps and all three review personas.
for f in "$review" "$work" $personas; do
  needs_re "$f" 'marked \*?believed\*?' \
    "$f marks an unreproduced claim believed rather than found"
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

# #40 / AC3: the ceiling's other half — the obligation that nothing shipped used to state. It binds
# where a lead acts on it: the review step, the README beside the ceiling sentences, and the merge
# step, which also has to say why holding merge authority is not the same as having read the change.
needs "$review" "not recorded as reviewed until the named human has read it" \
  "$review states that a change is not recorded as reviewed until the named human has read it"
needs "$readme" "not recorded as reviewed until the named human has read it" \
  "the README states that a change is not recorded as reviewed until the named human has read it"
needs "$work" "not recorded as reviewed until the named human has read it" \
  "$work's merge step carries the same obligation"
needs "$work" "answers who may merge and says nothing about who has read" \
  "$work distinguishes merge authority from the named human's reading"

# #33: the release rule in the shipped profile template — when a release is owed, what earns none,
# and that cutting it finishes the batch. Stated generally on purpose: a consuming project renders
# its own definition of done from this file and may ship a library, an image or nothing at all.
needs "$profile" "a release is owed when what this project ships" \
  "$profile states when a release is owed"
needs "$profile" "earns none, and a project that ships nothing never owes one" \
  "$profile states what does not earn a release"
needs "$profile" "the last step of finishing that batch, not something remembered afterwards" \
  "$profile makes cutting the release part of finishing the batch"

if [ "$fails" -eq 0 ]; then echo "PASS"; exit 0; fi
echo "FAIL ($fails)"; exit 1
