# Changelog

Per release: what changed, what to do, and what happens to a project that changes nothing. Entries
are appended, never rewritten — an entry describes the release it names, not the current tree.

## 0.6.0 — 2026-10-01

Minor, not patch: the item templates and `/crew:conform` are new capability, the four profile keys
are additive with stated fallbacks, and one existing behaviour changes — `story create` and
`task create` now refuse a body that is off-shape.

One output changes shape too: `tracker.sh show <n>` printed comments only and now prints the item,
then `--- comments ---`, then the comments. Anything parsing that output breaks. Nothing in this
repository parses it — the skills that call `show` read it, and no test or script asserts on its
shape — so it is minor here; if you have a script around `show`, read it before you upgrade.

### What changed

- **Every item has one shape.** Four bodies ship with the plugin and are read at runtime —
  `templates/item-story.md`, `item-task.md`, `item-bug.md`, `item-tech-debt.md`. A project replaces
  one kind by putting its own complete copy at `.claude/crew/items/<kind>.md`; nothing is copied into
  a project.
- **The shape is enforced by refusal at creation.** `tracker.sh story create` and `task create`
  refuse a body that misses a section or a header line, and `Story: #<n>` is now a checked first-line
  contract — the line the board's rollup has always needed.
- **One size contract.** A task body carries `Size: <H> hand-written files (+ <G> generated) · <T>
  RED tests · one PR`, a `Split line:` naming the seam it is cut at, and `Exception: <reason>` for a
  mechanical sweep. The default ceiling is 15 hand-written files, moved with `size-cap:` and removed
  with `size-cap: -`. The count is checked at creation, printed at claim, and compared against the
  committed diff before any reviewer is briefed.
- **`tracker.sh lint [<n> | --all | --kind …] [--quiet]`** reports every board item that no longer
  matches its kind's template, one line per item naming each failing check, exit 1 when any fails.
  It only reads. `/crew:status` prints its count under the board.
- **`/crew:conform [<n> | --all]`** brings a board filed before the shape over to it in one pass:
  it drafts the fixes a body already decides, briefs the owning role read-only for new text, and
  shows a diff per item before anything is written. With nobody to approve a diff, the pass refuses.
- **Four new profile keys**, each safe by its absence: `generated:` (globs whose files do not count
  toward the size), `size-cap:`, `definition-of-done:` and `merge-authority:`. An absent key renders
  its fallback in the item body, where the writer reads it.
- **`/crew:init` learns them** — it fills `generated:` by scanning and marks the guess in the profile
  itself, asks for the other three, and offers to render the issue templates (off by default).
- **A reviewer is isolated.** A review brief carries the diff, the reviewed commit, the criteria with
  their text, the design's contracts, the profile and the findings format — and may not carry the
  implementer's report, the lead's narrative or an earlier round's findings. A reported problem that
  names no command and quotes no line is a question, not a finding, and never enters a fix round.
  One round of agent review is the ceiling; a contested finding goes to the user.
- **The model a run used is provable.** `scripts/subagent-model.sh audit [<session-dir>]` walks the
  session's own files and prints one row per run — the model the dispatch asked for beside the model
  that ran — flagging `MISMATCH` and `DISPATCH-CONFLICT`, exit 1 when any stands. `/crew:status` and
  `/crew:work` print it at every task boundary. The `SubagentStop` hook is best-effort and is no
  longer described as the proof.
- **Every persona's model tier is stated once**, in the README's "Model per role" roster, with what
  the tier buys against and what would move it. `scripts/tests/model-roster.test.sh` holds the
  roster's Default column against the persona frontmatter.
- **`tracker.sh release <n> --to done`** is the transition that means finished: lane labels off, item
  closed, assignee kept. `/crew:work` step 7 finishes an item when its PR is merged, whoever merged
  it. Before this, a closed item kept `in-progress` and the board counted it as in flight.
- **`tracker.sh show <n>`** prints the item and then its comments, separated by `--- comments ---`.
  It printed only the comments before, which hid every body from the two pipeline steps that open on
  it.
- **`plan` and `refine` read the shipped shapes.** Both resolve the item body before briefing anyone
  — `.claude/crew/items/<kind>.md` if the project has one, else the plugin's
  `templates/item-<kind>.md` — and hand the architect or the product-owner that rendered body to
  fill. Neither invents a shape from prose any more.
- **QA gets no worktree it cannot use.** `/crew:work` step 4 and `/crew:review` step 1 create the
  qa-engineer's mutation worktree only when the diff changes code a test protects. For a docs-only
  diff, or a script nothing builds or imports, no worktree is made, the brief says the mutation
  review is not applicable, and the PR says so too.
- **`ensure-labels` mints the review severities.** It now creates `p1`, `p2` and `p3` alongside the
  lane and `role:*` labels, so a review finding has a label to carry.
- New: `scripts/tests/review-contract.test.sh`, `scripts/tests/model-roster.test.sh`. Four witnesses
  now — all on the `test:` and `gates:` lines of **this repository's own**
  `.claude/crew/profile.md`, which is what the plugin is developed against. Nothing is asked of your
  profile.

### What to do

1. Install it: `claude plugin install crew@claude-crew`.
2. Re-run `scripts/tracker.sh ensure-labels`. This is the one action an existing board needs: `p1`,
   `p2` and `p3` are new, and a board set up before this release does not have them until you do.
   The command is idempotent and updates the labels it already made.
3. Optionally add the four new keys to `.claude/crew/profile.md` — `generated:`, `size-cap:`,
   `definition-of-done:` and `merge-authority:`. Each renders its fallback in the item body when
   absent, so a profile written for 0.5.9 is a valid 0.6.0 profile. `/crew:init` fills `generated:`
   by scanning and asks the other three.
4. Run `scripts/tracker.sh lint --all` to see which existing items are off-shape and so will
   warn at claim, then `/crew:conform` when you want them brought over. Do not add `lint --all` to
   your `gates:` line until that pass has run and the board reports zero non-conforming — otherwise
   every gate run goes red for items nobody has had the chance to migrate.

### What happens if a project changes nothing

Four things, and nothing else:

1. **On new bodies, from day one:** `story create` and `task create` refuse a body that does not
   conform. Nothing already on the board is touched.
2. **On old bodies, from day one:** `claim` succeeds and prints the failing checks as `warning:`
   lines. Every item stays claimable; no item is reshaped, refused or unclaimed for being old.
3. **On finished items, from day one:** `/crew:work` step 7 closes a merged item with
   `release --to done` instead of leaving it closed with a lane label on. Nothing retroactive:
   items closed before this release keep their stale lane label, and `status` keeps counting them as
   in flight, until someone takes it off by hand. No command in this release does that for you.
4. **When the project chooses, never before:** `lint --all` reports and `/crew:conform` migrates, and
   `conform` edits one item only after a human has approved its diff.

There is no migration tooling past that one command, no version negotiation and no compatibility
matrix.
