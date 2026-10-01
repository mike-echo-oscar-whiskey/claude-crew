# Changelog

Per release: what changed, what to do, and what happens to a project that changes nothing. Entries
are appended, never rewritten — an entry describes the release it names, not the current tree.

## 0.7.1 — 2026-10-01

Patch, not minor: nothing is added, and no command, flag, profile key, label or item section is new.
`next` parses a field it already parsed, `/crew:init` does two things it already said it did, and four
witnesses leave a payload that never ran them. The one change that could be read as minor is that
move, because it changes what an install *contains* — and an install did contain them:
`~/.claude/plugins/cache/claude-crew/crew/0.5.9/scripts/tests/` holds all four, so the removal is
visible to anyone who looks, and this entry says so rather than calling it invisible. It is a patch
anyway, and for a reason stronger than size. That path carries the version in it, so no consumer ever
had a stable path to those files; nothing in the payload — no skill, hook or script — named or invoked
one; and two of the four could only exit 1 from inside an install, because they read a repository-root
README that an install has no copy of. The one instruction that ever pointed at them was `0.7.0`'s
Layout block, which listed them under `plugins/crew/` with "run bare" beside them — and following it
was already a failure for half of them. Nothing a project could have depended on is gone, which is
what decides the number.

Two of the five commits behind this release reached no consumer at all. `438cb51` and `cefd090` change
`.claude/crew/`, this repository's own crew configuration, which is not in the payload — so master
moved by five and an install moves by three. Counting all five is how an empty release came within a
command of being tagged earlier today; keeping the two counts apart is the subject of open item #33.

### What changed

- **`next` reads a task's story from the body's first line only, so a task that names its story twice
  prints one row** (#30). The story number came out of an unanchored `grep -oE '^Story: #[0-9]+'`, so
  every matching line in a body contributed one number. A task carrying `Story: #676` as its first
  line and `Story: #676 · design …` on its third yielded two, handed the row's `printf` an argument
  too many, and split the record across two lines — live on a 489-item board, where two tasks each
  printed as two half-rows. The anchored first-line parse `lint` has had since it was written is now
  the function `story_of_body`, and both call sites read through it: one regex in two places is how
  this bug existed, and it is the third of that shape. A first line that is not a story reference
  still contributes nothing and the row still prints, as `#?`.
- **The four witnesses leave the payload, so no install carries a test that cannot pass** (#31).
  `review-contract.test.sh` read `../../README.md` and `model-roster.test.sh` read
  `$crew/../../README.md`. An install is `{agents,.claude-plugin,hooks,scripts,skills,templates}`
  copied out of `plugins/crew/`, so a repository-root file is never two levels up and both exited 1
  on a consumer's machine; they passed here only because a checkout happens to put a repo root in the
  right place. Making the two skip on a missing file would have left the payload carrying tests that
  pass by asserting nothing, so all four move to `tests/` at the repository root instead, where each
  anchors on `$here/..` and derives `plugins/crew` from it. They are this repository's own gates:
  they are on the `test:` and `gates:` lines of **this repository's** `.claude/crew/profile.md`, and
  nothing is asked of your profile. `CHANGELOG.md` and the three `docs/design/` files naming the old
  path keep it, because they record what was true when they were written.
- **`/crew:init`'s two steps whose unhappy path was silence now have one, and say what they did**
  (#32). Step 7 appended a "Crew" section to `CLAUDE.md` when that file lacked one, so a project with
  no `CLAUDE.md` at all fell outside the condition and got no crew pointer without a word — in the
  one procedure a project runs once and never revisits. It now writes the file, holding one line of
  what the project is plus that same section, and reports creating rather than appending, so a user
  who did not want one can delete it. Step 4 now creates the directory the profile's `designs:` line
  names, because `/crew:plan` writes a design into it as its first act and a missing path surfaced
  there as a failed write, a pipeline away from the one `mkdir` that prevents it. It is created
  empty. Three values stay uncreated and are reported instead of attempted — a path outside the
  project, an absolute path, and no value at all — each with the value read and the sentence that
  `/crew:plan` will fail until the line is fixed.

### What to do

1. Install it: `claude plugin install crew@claude-crew`.
2. **Nothing is required.** `0.7.0` needed `ensure-labels` run before `tech-debt create` had a label
   to file under; nothing here gains a dependency on an action. The `next` fix is live the moment the
   install lands, no witness was ever on a path you used, and the `init` text is read the next time
   `/crew:init` runs.
3. Two optional repairs, both only for a project that already ran `/crew:init` and neither caused by
   this release — `0.7.1` is what makes them visible. If `.claude/crew/profile.md` names a `designs:`
   directory that is not there, `/crew:plan` still fails on its first write: `/crew:init --refresh`
   creates it, and so does one `mkdir`. If that project had no `CLAUDE.md` when it was set up, it
   still has no crew pointer and every future session starts without knowing the crew exists;
   `--refresh` writes the file. A project whose designs directory exists and whose `CLAUDE.md`
   carries a "Crew" section has nothing to do.

### What happens if a project changes nothing

Three things, and nothing else:

1. **`/crew:next` keeps printing a broken row** for any task whose body names its story on more than
   one line — two half-rows instead of one record, with the second carrying the overflow argument.
   Nothing else in the pipeline misreads it: `lint` always had the anchored parse, and a claim, a
   status rollup and a plan all read the first line.
2. **`/crew:init` keeps both silences.** A project set up without a `CLAUDE.md` is already past that
   step and cannot get the pointer back from an upgrade, and a missing `designs:` directory still
   surfaces inside `/crew:plan` as a failed write rather than at setup.
3. **Four files disappear from the installed payload** at `scripts/tests/`, and nothing else in it
   moves. No skill, hook or script referenced them, the path they lived on was stamped with the
   plugin version, and the two that read the repository README could only fail there. Everything
   that existed under `0.7.0` keeps its flags, its output and its exit codes, `lint`'s 2 among them.

There is no migration tooling, no version negotiation and no compatibility matrix.

## 0.7.0 — 2026-10-01

Minor, not patch: `tracker.sh bug create` and `tracker.sh tech-debt create` are commands that did not
exist, and `ensure-labels` mints two labels it did not mint. The rest of the release is a rule the
lead reads, a template sentence and thirty-four witness cases — but capability was added, and that is
what decides the number, by the same rule `0.6.1` used to decide it was a patch. No command that
already existed changes its flags, its output or its exit codes. One action is required of an
upgrading project, and unlike `0.6.1`'s it is not optional: `ensure-labels` is where the two new
labels come from, and `tech-debt create` has nothing to file under until it has run.

### What changed

- **`bug create` and `tech-debt create` file through the adapter, so the validator written for them is
  finally reached** (#21). The dispatch had arms for `story create` and `task create` and none for the
  other two kinds `lint` already judges, so `tracker.sh bug create …` fell through to the usage block
  — exit 1, no check named, nothing created — and whoever needed one of those items reached for `gh
  issue create`, where nothing looks at the body. `validate_plain_body` was written for exactly these
  two kinds and nothing called it. Both arms take `--title` and `--body-file`, validate the body before
  a single `gh` call, return every failing check on its own line, create nothing on a refusal, and
  print the number under the kind's own label on success. Neither takes `--role`, and the shapes are
  why: `item-tech-debt.md` names no role at all, and `item-bug.md` carries its role in the body's first
  line, where the placeholder scan already refuses it unfilled — a flag would write a second copy of a
  fact with nothing holding the two equal. A board that wants `role:<r>` on one of these adds it with
  `gh issue edit --add-label`, which skips no check, because every check here is on the body.
- **`ensure-labels` mints `bug` and `tech-debt`** (#21). Without them a consuming board had no label to
  carry either shape, and `lint --kind tech-debt` named a kind nothing on a fresh board could be.
  `tech-debt` is new (`8D6E63`). `bug` is minted in GitHub's own `D73A4A` on purpose — GitHub creates
  that label in every new repository, and the `--force` every label here carries would otherwise
  repaint one a project already uses for exactly this. The description it does rewrite: an existing
  `bug` comes out as "Reported defect in behaviour that shipped (crew pipeline)".
- **A command whose answer the lead will report runs bare and alone** (#18). Rule 16 of
  `templates/operating-model.md` covered the project's gates only, and a lead's day is mostly other
  verification — a search, a count, a push, a comparison of two git objects — composed into one call
  with `&&` to save a round trip. It now states the general discipline with the four specifics the
  evidence supports: nothing chained after the command being judged, because the exit code that comes
  back then belongs to the last command in the line; an absence or a count in a call of its own,
  because `grep -c` and `rg` exit non-zero on zero matches, which is the answer when it stands alone
  and a poisoned chain when it does not; a pattern written against text that has been read rather than
  from memory of a file; and two git objects compared as `<ref>^{commit}`, because on an annotated tag
  `git rev-parse` returns the tag object, which is equal to no commit. Rule 8 and the token-economy
  bullet point at it instead of restating a narrower version, and step 5 of `/crew:work` names it
  rather than repeating it.
- **A rendered task body's `## Files` instruction reads as English where no generated paths are
  declared** (#25). `item-task.md` put `<profile:generated>` in the middle of a sentence, and the
  substitution for an absent key is a whole clause, so a profile with no `generated:` key — two of the
  three measured, this repository's own among them — rendered "Files matching nothing — no
  `generated:` paths are declared, so every file in this list counts are counted in G and do not spend
  the cap". Correct, and unreadable, in the first body a new project renders. The placeholder moves to
  the end of the block on its own labelled line, where a clause and a glob list both fit.
- **Thirty-four witness cases, over behaviour that already worked and nothing asserted** (#20, #21,
  #23, #26). `tracker.test.sh` goes from 38 cases to 49: the size checks with the ceiling off
  (`size-cap: -` still refuses a body stating no size, one whose size is not a number and one whose
  number disagrees with its `## Files` list, and accepts twenty files so the arm proves the ceiling
  really is off), a conforming submission that comes back out of the stored body byte for byte under
  the two header lines, an accepted `Exception:` keeping its reason, every bullet counting where no
  `generated:` key is declared, a claim on a pre-upgrade item asserted in all four of its clauses, the
  four cases that hold the two new create arms, a `## Proves` section that names no criterion, and the
  placeholder scan reached from all four kinds rather than from `story` alone.
  `review-contract.test.sh` goes from 27 to 50: the severity obligations in all five files that file a
  finding — a `p1` fixed before the change is offered, a `p2` fixed here when this change caused it or
  made it reachable, a pre-existing `p2` deferred to one line and its own item — each as a regex over
  the wording that is actually there, because those five word the sentence differently; and the
  one-round ceiling both by its presence, in the review step and in the README, and **by its absence**,
  one check that searches every Markdown file the plugin ships for a sentence permitting a second round
  and passes on finding none. Both suites were already on the `test:` and `gates:` lines of **this
  repository's own** `.claude/crew/profile.md`; nothing is asked of your profile.

### What to do

1. Install it: `claude plugin install crew@claude-crew`.
2. **Re-run `scripts/tracker.sh ensure-labels`.** This is the one required action and nothing does it
   for you — `/crew:init` runs it at setup, and an upgrade does not run `/crew:init`. Until it has run
   the board has no `tech-debt` label for `tracker.sh tech-debt create` to file under, and `lint --kind
   tech-debt` reads a kind the board cannot hold. It is idempotent, `--force` on every label; on a board
   that already carries a `bug` label the one thing it changes is that label's description.
3. If `/crew:init` rendered `.github/ISSUE_TEMPLATE/` for you, re-run `/crew:init --refresh`, which
   also does step 2. `templates/item-task.md` changed, so the task template a human files through keeps
   the unreadable `## Files` instruction until you do, and `/crew:status` prints `issue templates:
   rendered from crew <rendered>, installed is 0.7.0 (/crew:init --refresh)` under the board meanwhile.
   A project that declined that render, or has taken those files over, has nothing to do here.

Nothing else: no profile key, no item section and no flag on an existing command is new. A project that
has taken a kind over with its own `.claude/crew/items/<kind>.md` keeps that copy, including — for
`task` — the `## Files` sentence this release fixed in the plugin's.

### What happens if a project changes nothing

Two things, and nothing else:

1. **`tech-debt create` has no label to file under**, and `lint --kind tech-debt` reports on a label the
   board does not carry. `bug create` works wherever GitHub's own `bug` label is still there, which is
   every repository that has not deleted it. Neither command existed before this release, so nothing
   that worked stops working.
2. **Everything that existed under `0.6.1` behaves as it did.** Rule 16 is read by the lead, not
   executed; the `## Files` sentence is read by whoever drafts a task body; the witness cases run in
   this repository against its own profile. Every command keeps its flags, its output and its exit
   codes — `lint`'s 2, and `next`'s and `status`'s stderr warning beside their exit 0, among them.

There is no migration tooling past those two steps, no version negotiation and no compatibility matrix.

## 0.6.1 — 2026-10-01

Patch, not minor: nothing is added. Every change below is a fix to behaviour `0.6.0` already
described — one report sentence that was untrue, and three reads that passed a partial board off as
the whole one. No command, flag, profile key, label or item section is new, and no output that was
already correct changes shape. The one thing a caller could trip over is `lint`'s new exit 2, and it
fires only where `0.6.0` returned a `0` it had not earned; "What happens if a project changes
nothing" says what that means for a script written around it.

### What changed

- **`lint` says when a fetch filled its limit instead of printing a partial read as a clean board**
  (#14). `0.6.0` fetched 500 items per kind and said nothing when a kind held more, so a board past
  500 of one kind reported a count that read as complete over items it had never seen. The cap is now
  2000 per kind — `--limit N` is an exact cap that `gh` pages the API to satisfy, so the cost is the
  pages a board actually fills — and a fetch that comes back exactly full names the kind and the limit
  in the closing line and exits 2, which is a partial read and not the verdict exit 1 gives. Read
  further into the kind that filled with `lint --kind <kind>`, which gives each kind its own budget.
  **This retracts `0.6.0`'s "Honest limits" note about the 500 cap**: a reader told there to treat
  `lint`'s count as a lower bound until this was fixed no longer has to, because the count now says
  for itself when it is one.
- **`next` and `status` say when a fetch filled its limit instead of passing a partial board off as
  the whole one** (#16). The three fetches behind them — open tasks, tasks of every state, open
  stories — capped at 200, 500 and 100 and said nothing when a label held more, so a large board could
  keep a claimable task out of `/crew:next` and drop a story off `/crew:status` with no sign at all.
  All three now share the same 2000-item cap, and a fetch that comes back exactly full warns on
  **stderr**, naming which of the three filled and what it costs the reader. **stdout and the exit
  code are unchanged, deliberately**: unlike `lint`, these two are not reporters — every row they
  print is real and claimable, so a filled fetch makes the output incomplete rather than wrong, and a
  non-zero exit would have `/crew:next --auto` read "there is more" as "this failed" and refuse work
  that is genuinely there.
- **The setup report and the three resolution lines no longer promise that a project's own item shape
  wins whole** (#15). `0.6.0` described an override as deciding the whole shape. It decides the
  required sections; the `Story: #<n>` first line and the `Blocked by:`, `Role:` and `Size:` lines are
  checked against the adapter's own rules whatever the override contains, because the board's rollup
  reads them. A project that believed the sentence and dropped `Size:` had every task creation refused
  with nothing explaining why. The enforcement was right, so only the wording changed — in
  `/crew:init`'s report and in `/crew:conform`, `/crew:plan` and `/crew:refine`, and in
  `templates/item-task.md`'s own header comment, which had named only the `Story:` line.
- **The three hook commands are quoted** (#15). `hooks/hooks.json` interpolated
  `${CLAUDE_PLUGIN_ROOT}` unquoted in all three entries, which printed three warnings on every
  `claude plugin validate` run and exits 127 from an install whose plugin root contains a space.
- **Both caps are witnessed.** `scripts/tests/tracker.test.sh` now asserts the limit each fetch hands
  `gh` — the stub truncates to it, so a call hard-coded to the wrong number cannot stay green — that
  saturation reaches `lint`'s closing line with exit 2 and `next`'s and `status`'s stderr with exit 0
  and rows alone on stdout, that a warning fires for the fetch that actually filled and not for its
  siblings, and that a non-numeric cap falls back to 2000 instead of switching the comparison off in
  silence. Still four witnesses, all on the `test:` and `gates:` lines of **this repository's own**
  `.claude/crew/profile.md`; nothing is asked of your profile.

### What to do

1. Install it: `claude plugin install crew@claude-crew`.
2. If `/crew:init` rendered `.github/ISSUE_TEMPLATE/` for you, re-run `/crew:init --refresh`. This is
   the one action an upgrading project needs, and the easiest to miss: those files carry the version
   they were rendered from, so `/crew:status` prints `issue templates: rendered from crew 0.6.0,
   installed is 0.6.1 (/crew:init --refresh)` under the board until you do — and the refresh is also
   how the corrected `item-task.md` header reaches the copy a human files through. A project that
   declined that render, or that has taken those files over, has nothing to do.

Nothing else: no profile key, no label, no command and no item body changes. A project whose own
`.claude/crew/items/task.md` dropped `Blocked by:`, `Role:` or `Size:` on `0.6.0`'s wording does still
have to put those three lines back, but that is a `0.6.0` refusal this release only stops
mis-describing, not a new requirement.

### What happens if a project changes nothing

Three things, and nothing else:

1. **`lint`'s exit code gains the value 2**, so a project that put `lint` behind something reading its
   exit code should know 2 means "read incompletely" rather than "items failed". It fires only on a
   board holding 2000 or more items of one kind — which is precisely where `0.6.0` exited 0 over items
   it had never read, so a wrapper that trusted that 0 was already being told the wrong thing.
   Nothing in this plugin reads it: the `gates:` line deliberately carries no `lint`, and every other
   consumer is prose a human or an agent reads.
2. **`next` and `status` may write one line to stderr.** Their stdout and their exit 0 are what they
   were, so anything parsing the rows is untouched; a caller that folds stderr into stdout with
   `2>&1` sees the warning among them.
3. **`/crew:status` prints the issue-template version line** above until the render is refreshed or
   removed. It is a string compare of two versions and says nothing about the bodies.

There is no migration tooling past that one optional re-render, no version negotiation and no
compatibility matrix.

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
