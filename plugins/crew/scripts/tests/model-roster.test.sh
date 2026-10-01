#!/usr/bin/env bash
# Witness for the model roster in README.md "Model per role": every persona in
# plugins/crew/agents/ has a roster row, the row's Default column equals that persona's frontmatter
# `model:` verbatim, every row carries a reason, and the rule that moves a tier is stated exactly
# once in the tree. Run it bare:
#   bash plugins/crew/scripts/tests/model-roster.test.sh
# Exits 0 when every case passes, 1 when the roster and the frontmatter have drifted apart or the
# moving rule is stated zero times or more than once, and names the case either way.
set -u

here=$(cd "$(dirname "$0")" && pwd)
crew=$(cd "$here/../.." && pwd)
root=$(cd "$crew/../.." && pwd)
readme="$root/README.md"
agents="$crew/agents"
fails=0

pass() { echo "  ok   $1"; }
fail() { echo "  FAIL $1"; echo "       $2"; fails=$((fails + 1)); }

# roster_cell <persona> <column-number> — the cell of that persona's roster row, backticks and
# surrounding whitespace stripped; empty when the persona has no row.
roster_cell() {
  awk -v want="$1" -v col="$2" -F'|' '
    /^## Model per role/ { sec = 1; next }
    /^## / && sec       { sec = 0 }
    sec && /^\|/ {
      key = $2; gsub(/[ `]/, "", key)
      if (key != want) next
      cell = $(col + 1)
      gsub(/`/, "", cell)
      gsub(/^[ \t]+|[ \t]+$/, "", cell)
      print cell
      exit
    }' "$readme"
}

echo "model-roster.sh"

if [ ! -f "$readme" ]; then
  echo "  FAIL README.md is not there"
  echo "FAIL (1)"
  exit 1
fi

# Case 1 — the roster is keyed by persona file name and its Default column is the frontmatter model.
case1=0
for f in "$agents"/*.md; do
  persona=$(basename "$f" .md)
  declared=$(sed -n 's/^model: *//p' "$f" | head -1)
  row=$(roster_cell "$persona" 2)
  if [ -z "$row" ]; then
    fail "every persona file has a roster row whose default tier equals its frontmatter model: ($persona)" \
      "README.md \"Model per role\" has no roster row for $persona"
    case1=1
  elif [ "$row" != "$declared" ]; then
    fail "every persona file has a roster row whose default tier equals its frontmatter model: ($persona)" \
      "$persona declares '$declared' in frontmatter and the roster says '$row'"
    case1=1
  fi
done
[ "$case1" -eq 0 ] && pass "every persona file has a roster row whose default tier equals its frontmatter model:"

# Case 2 — the fourth column of every roster row says why that tier.
case2=0
for f in "$agents"/*.md; do
  persona=$(basename "$f" .md)
  why=$(roster_cell "$persona" 4)
  if [ -z "$why" ] || [ "$why" = "—" ]; then
    fail "every roster row carries a non-empty reason ($persona)" \
      "the roster row for $persona has no reason in its fourth column"
    case2=1
  fi
done
[ "$case2" -eq 0 ] && pass "every roster row carries a non-empty reason"

# Case 3 — the rule that moves a tier is stated exactly once in the tree, in README.md. The needle is
# split so that this witness is not itself an occurrence of the rule it counts.
needle="never on "'impression'
hits=$(grep -rnF -- "$needle" "$root" \
  --exclude-dir=.git --exclude-dir=docs --exclude-dir=node_modules 2>/dev/null | wc -l)
where=$(grep -rlF -- "$needle" "$root" \
  --exclude-dir=.git --exclude-dir=docs --exclude-dir=node_modules 2>/dev/null | tr '\n' ' ')
if [ "$hits" -eq 1 ] && [ "$where" = "$readme " ]; then
  pass "the moving rule is stated exactly once in the tree, in README.md"
else
  fail "the moving rule is stated exactly once in the tree, in README.md" \
    "counted $hits occurrence(s) of the rule, in: ${where:-nothing}"
fi

if [ "$fails" -eq 0 ]; then echo "PASS"; exit 0; fi
echo "FAIL ($fails)"; exit 1
