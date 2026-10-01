# ✨ feat(crew): every item has one shape and one size, a reviewer sees the change and the criteria only, and the model each run used is proved

Design for stories #1 and #2, release 0.6.0. Architect, 2026-09-30. Status: **shipped** in **0.6.0**
on **2026-10-01** (task #10). Sections are numbered §1–§10 because the eight task
bodies (#3–#10) cite them by that number; the map is at the end. The body's `D<n>` headings are a
second scheme and not interchangeable with the first: a `D` number names one decision and is how
this document cross-references itself, a `§` number names the section a set of them lives in and is
the only form a task body or a review brief cites — the map at the end is what turns one into the
other. What the plan got wrong is recorded
in "Corrections the tasks returned", below the Risks — the decisions themselves stand as written,
because a design document records what was decided when it was decided.

## Problem

Three things went wrong in one consuming project between 2026-09-22 and 2026-09-30, all countable.

- **A story planned into 13 tasks whose first task still shipped 34 files.** #716 was planned into
  thirteen tasks. Its first task, #717, was written down as "about 22 files", registered and claimed.
  It landed as PR #731 at 34 files (+1259/−463), took a fix commit of 7 more, and its review round
  produced PR #732 at 16 files in 3 commits — three review rounds in all. Three moments could have
  compared a number against a ceiling (plan step 2, plan step 3's sanity check, claim) and none had a
  number to compare: `agents/architect.md` says "sized to one PR each", plan step 3 asks "finishable
  alone?", and `tracker.sh task create` takes `--story --title --role --body-file --blocked-by` and
  nothing about size.
- **A board where 18 of 209 tasks were invisible.** `tracker.sh status` rolls a task up under its
  story with `select(.body | startswith("Story: #" + n))` (`scripts/tracker.sh:120`) and `next`
  greps `^Story: #[0-9]+` (`:110`). Eighteen task bodies do not begin with that line, so they are on
  the tracker and absent from the board, and nothing said so.
- **A review round in which two findings were wrong.** In #733's round a finding that the runtime
  config was "baked into the image" travelled from the lead's own bug body (`config-cache-bug.md`,
  Tests item 2) into a QA finding into a refusal, and was disproved by one busybox probe of the
  build context; a second finding named a missing witness that already existed. Every real defect
  of the same session — four surviving mutants, a 422 that should have been 409, a first-act race
  answering 500 — came from running something. The wrong ones came from reading and inferring, and
  the reviewers had been handed the implementer's report and the lead's narrative beside the diff.
- **The model proof did not exist.** The `SubagentStop` hook wrote one line for 56 completed runs in
  that session (`crew-models.log`: `2026-09-29T22:02:35+02:00 - declared=- actual=-`), because the
  payload carried neither `agent_type` nor `agent_transcript_path`. Rule 13 and the README both tell
  the reader the hook logs the comparison automatically. In the same session product-owner declared
  sonnet and ran opus, technical-writer declared sonnet and ran opus three times, and
  commercial-analyst ran one of two runs on opus — visible only by a hand grep afterwards.

The shape of an item lived nowhere: the task shape was prose in `skills/plan/SKILL.md` step 5, the
story shape one phrase in `skills/refine/SKILL.md` plus a parenthetical naming Dutch section names,
and the two had drifted apart.

## Why

Kris, 2026-09-30, the decisions this design implements and does not reopen: two levels only, story
and task; the story is the specification, no separate spec document; one task is one change set
with a hard ceiling of fifteen hand-written files, generated files excluded and declared per
project; this repository generates nothing; uniformity is enforced by refusal at creation, not
described; an older board is brought over in one pass, never silently; the conformance check joins
this repository's gates only after that pass has run over its own board; the README stays true per
change set; an upgrade may refuse a body written from now on but never rewrites, breaks or unclaims
what is on a board, and every new profile key is safe by its absence. For story #2: the review
carries the change, the criteria and the agreed contracts and not the implementer's account; one
round of agent review is the ceiling; the model a run used is proved by an audit of the session's
own files, and the hook may not be described as the proof; default model tiers are a separate
matter; the work ships as one minor release.

The outside evidence is in `docs/design/crew-0.6.0-research.md` (2026-09-30) and cited where a decision
rests on it. Where a decision below is Kris's it says so; the rest are mine and stand until a task
returns a correction, which #10 records here.

## §1 — The item shape

### D1 — Four bodies ship in the plugin and are read at runtime, never copied into a project

`plugins/crew/templates/item-story.md`, `item-task.md`, `item-bug.md` and `item-tech-debt.md`,
verbatim from `docs/design/crew-0.6.0-item-bodies.md` "The four templates, paste-ready", with the one amendment
D3 names. Every reader resolves a kind in this order and stops at the first hit:

1. `${CLAUDE_PROJECT_DIR}/.claude/crew/items/<kind>.md` — the project's override; it wins **whole**.
2. `${CLAUDE_PLUGIN_ROOT}/templates/item-<kind>.md` — the shipped shape.

The file existing is the whole declaration: no profile key, nothing to keep in sync. `refine` reads
`story`, `plan` reads `task`, `work` and any role filing a finding read `bug` and `tech-debt`.
`tracker.sh` resolves the same two paths for its checks (§3), through `CREW_PROJECT_DIR` and its own
`$(dirname "$0")/../templates`, because a script has no `${CLAUDE_PLUGIN_ROOT}`.

A copy written into the project at init was rejected for invisible drift: a project would keep the
0.5.9 shape forever and an improvement in 0.6.0 would never reach it, with nothing to show the gap.
The override file pays the same price — that one kind stops receiving plugin improvements — but pays
it visibly: the file is in the project's git history, and the leading HTML comment of every shipped
template names the override path and says the price out loud. The documentation states that sentence
once (A1).

*Forecloses:* a template rendered into the project by `/crew:init` as the source of truth; a profile
key that names an override; a partial override that merges sections.

### D2 — Each template carries its own contract in a leading comment, and two lines are load-bearing

The comment at the top of each body names the override path and the checks `tracker.sh` refuses on,
so a writer meets the gate in the file before meeting it in a refusal. Two conventions are not
format choices but the board's rollup and are marked as such in the comment: the task body's literal
first line `Story: <sigil><n>` (§3) and the story body's `## Tasks` as its last section, empty, where
`task_create()` appends the checklist line (`tracker.sh:60-68`). The sigil comes from the profile's
`tracker:` backend — `#` for github — so a second backend's author sees the contract instead of
guessing.

The `.github/ISSUE_TEMPLATE/{story,task,bug,tech-debt}.md` files are a separate, opt-in render for
humans filing through the GitHub web UI, never a source: `/crew:init` offers them off by default,
only for a `github` tracker, each with the header `<!-- Generated by /crew:init from crew <version>.
Do not hand-edit: re-run /crew:init --refresh after a plugin upgrade, or take ownership by moving it to
.claude/crew/items/<kind>.md. -->`, and `/crew:status` prints one line when that version lags the
installed plugin (§6).

*Forecloses:* a template with no statement of where it is read from; a rollup convention that lives
only in the script.

## §2 — The four profile keys

### D3 — Every key has a fallback, the rendered body shows it, and absence changes nothing silently

`templates/profile.md` gains four keys, each with its fallback in the trailing comment. "Rendered
body" means the template after key substitution, as the skill hands it to the writing role and before
the role fills a single placeholder; that artifact is what A10's proof examines, one per case.

| Key | Value | Absent or `-` | Where the rendered body shows it |
|---|---|---|---|
| `generated:` | globs, comma-separated | every changed file counts toward H | the `## Files` instruction: "Files matching `<profile:generated>` are counted in G" reads "no generated paths are declared: every file in this list counts" |
| `size-cap:` | integer, default 15 | `-` disables the refusal in §5 and nothing else; `Size:` stays required, parsed and counted | the `Split line:` instruction names the cap or says "no cap: `Size:` is still counted" |
| `definition-of-done:` | a path or a section name | "the profile's Definition of done section" | the closing line `*Common definition of done: <profile:definition-of-done>, walked in the PR.*` |
| `merge-authority:` | who may merge | "the author" | the same closing line of the task and bug bodies gains `Merged by <profile:merge-authority>.` |

The last row is the one amendment to the paste-ready draft: the draft never renders
`merge-authority:` anywhere, and A10 requires every absent key's fallback to be visible in the
rendered body. One clause on one line, in `item-task.md` and `item-bug.md`.

`generated:` absent meaning "everything counts" is the safe direction: the cap stays honest, and a
project with a large generated surface feels the cap as too tight and declares its globs in one
edit. Silently excluding an unknown set is the expensive direction. `/crew:init` fills `generated:`
from the scan (generator output directories, `*.g.*`, `Generated/`, lock files, vendored client
folders) and reports it as *guessed*; it asks the three others in the question round (§6). A profile
written before these keys existed renders every fallback and the crew runs unchanged — the only
behaviour an absent key produces is the one the rendered body states.

*Forecloses:* a key whose absence is an error; a default that differs between the skill and the
script (both read the value through `crew_profile_value` in `scripts/common.sh`); a hidden exclusion
list.

## §3 — The first-line contract and the create-time checks

### D4 — `Story: <sigil><n>` becomes a checked contract, and a body that fails it is refused, not filed

`task_create()` already prepends `Story: #<n>` to the caller's fragment (`tracker.sh:60`). The check
runs on the **assembled** temp file, not on the fragment: first line matches `Story: <sigil><n>` for
the story given. That is where the eighteen invisible bodies came from — filed by hand or from a
web-UI template, never through the adapter — so the adapter also becomes the only creation path the
skills use, and `lint` (§4) catches the rest.

What a body that fails any create-time check gets: exit 1, one line per failing check on stderr in
the form `refused: <check> — <what was found>` (for this one: `refused: first line must be "Story:
#<n>" (the board rolls tasks up by it) — got "<line>"`), and **no `gh` call** — the witness asserts
the stub `gh` recorded nothing. Nothing reaches the board.

*Forecloses:* a task that is on the tracker and absent from `status` and `next`; a check that runs on
the caller's fragment and passes a body the adapter then breaks.

### D5 — One validator per kind, its section list read from the resolved template, shared by `create` and `lint`

The checks are functions in `tracker.sh`, called by `story create`, `task create` and `lint` — one
implementation, two callers, no copy. The required `##` headings are **read from the resolved
template** (D1's order), so the list lives once and a project that overrides a kind is checked
against its own shape. Everything else is the validator's own rule per kind:

**Story:** all template headings present and non-empty; `## Tasks` last and its body empty; `## TL;DR`
non-empty and ≤ 320 characters with no code span, no `/` path, no item reference; criteria ids
`1..n` strictly increasing, no gaps, no duplicates (a `withdrawn` line still occupies its number);
exactly one Proof-map row per criterion id; no surviving placeholder (`<!-- ` from the template, or an
unfilled `<…>` stub).

**Task:** the first line (D4); `Blocked by:`, `Role:` and `Size:` present; `Size:` parsing to integers
H, G and T; `Split line:` or `Exception:` present when H ≥ 12 or T ≥ 4; H ≤ `size-cap:` unless
`Exception:` (§5); all template headings present and non-empty; `## Files` bullet count == H;
`## Tests (RED first)` numbered count == T, with T = 0 accepted when that section declares the task
test-free; `## Proves` carries at least one `AC <n>`; no surviving placeholder.

**Bug and tech-debt:** headings and placeholder only, plus `Size:` for a bug.

One consequence the adapter must absorb: today it writes `Blocked by:` only when `--blocked-by` is
given (`tracker.sh:60`). From 0.6.0 it writes `Blocked by: none` when it is not, so the line is
always present and the check is uniform. A refusal prints every failing check, not the first, so the
caller fixes and retries in one turn.

*Forecloses:* a second section list hard-coded in the script; a validator `lint` cannot call; a
refusal that stops at the first failing line.

## §4 — Conformance: refuse at create, warn at claim, report with `lint`

### D6 — `tracker.sh lint` judges the board, cheaply enough to run unprompted

`tracker.sh lint [<n> | --all | --kind story|task|bug|tech-debt] [--quiet]`: one `gh issue list
--state all --limit 500 --json number,title,labels,body` per kind — two to four calls for 209 tasks
and their stories, a few seconds, no per-issue fetch — then D5's validators over each body in hand.
Output: one line per non-conforming item (`#719  task   missing: TL;DR; Size: unparseable ("about 25
files")`), a closing `N conforming, M not`, exit 0 when all conform and 1 when any does not;
`--quiet` prints the closing line only. `/crew:status` runs `lint --all --quiet` and shows
`items: N conforming, M not (tracker.sh lint --all)`. A6's proof measures the wall time and the call
count on this board and on the consuming project's, because a drift detector nobody runs is not one.
`lint` only reads.

*Forecloses:* a per-issue fetch; a conformance count that lives anywhere but the board's status line.

### D7 — `claim` warns and continues; refusing at claim was rejected

`claim` keeps its two refusals (not open, already claimed: exit 3) and gains one behaviour: when the
item does not conform it prints the item's lint lines prefixed `warning:` and **continues** — the
assign, the label and the comment still happen, the exit code is unchanged. Refusing at claim was
rejected because it strands every item filed before the upgrade and turns a claim into a migration,
on boards nobody here can open (A7, A11). The lead brings an old item to shape in one edit before
working it — the cheapest moment, the smallest unit, the person with the context — and briefs the
owning role only where a section needs product judgement rather than transcription.

*Forecloses:* an exit 3 for an old shape; a claim that edits the body.

### D8 — What the machine cannot judge is not gated, and two readers already paid for judge it

Mechanical: presence, emptiness, length, counts, id well-formedness, `Files == H`, the first line,
placeholder survival, and one weak proxy for jargon in a TL;DR. Not mechanical, and the plugin does
not pretend otherwise: whether a TL;DR is understandable by a stranger, whether a criterion is one
outcome, whether a section restates another. Those go to `crew:technical-writer` in refine step 2's
parallel critique with that one question, and to the owning role in plan step 3 with "can you start
from this body without a conversation". The lead still reads every TL;DR cold before registering.
`ensure-labels` creates `p1` (`B60205`), `p2` (`D93F0B`) and `p3` (`FEF2C0`), `--force` like the
rest, so a finding's severity is a label and never body text.

*Forecloses:* a machine check for readability; a new reviewer role.

## §5 — The size contract

### D9 — `Size:` is a count, `Split line:` is the seam, and `Exception:` is a licence with a reason

Header line: `Size: <H> hand-written files (+ <G> generated) · <T> RED tests · one PR`. H is the
length of `## Files` minus the entries matching `generated:`; G is those entries; T is the numbered
items under `## Tests (RED first)`, at most five, T = 0 only when the section says the task is
test-free (the profile's definition of done allows it for a Markdown-only change; four of this
story's own tasks are exactly that). The architect fills the line at plan time from a **complete**
file list — no "and every call site" clause: name them or ask the scout.

`Split line:` names the seam the task is cut at if it grows: which files and which criteria go to
the follow-up. "n/a — the cap holds with room" is valid. `Exception: <reason> — <H> files, no
behaviour change; reviewed as one sweep.` replaces it only for a mechanical sweep provable by a
search that afterwards returns nothing, or a regenerated set that must land with its generator to
keep the tree buildable. The improvement plan's `--sweep "<reason>"` flag became this line: the same
licence, and the reason stays in the stored body where `lint` and the reviewer read it, instead of
in a flag nobody sees again.

*Forecloses:* a `Size:` that is an estimate ("about 22"); an exception without a reason; a sweep that
changes behaviour.

### D10 — The cap default is 15, read from `size-cap:`, and applies to this repository too

Fifteen hand-written files is the ceiling one human can read whole on a review; the outside numbers
say size drifts 2.5–3.5× under agents while review time explodes (Faros, 22,000 developers,
2026-04-12: files per PR +59.7 %, median review time +441.5 %; Brodzinski, 2026-07-14: 817 vs 232
LOC). A project moves it with `size-cap:`; `-` removes the refusal and keeps the count. Kris,
2026-09-30: this repository declares `generated: -`, so every changed file counts toward its own
ceiling — and the eight filed tasks are 4–6 files each with no exception needed.

*Forecloses:* a plugin constant; a cap that applies to consuming projects and not to this one.

### D11 — The count is checked at three moments: create, claim, and before review

1. **Create** — `task create` refuses H > cap without `Exception:`, and H ≠ the `## Files` count, and
   an unparseable `Size:` — including in a project with `size-cap: -` (A3).
2. **Claim** — `claim` prints the lint lines (D7); an old task with no `Size:` is sized by the lead in
   one comment and split there if it must be.
3. **Before review** — `work` step 4, before any reviewer is briefed: `git diff --name-only
   <base>...HEAD` with `generated:` globs removed; over the cap with no `Exception:` in the body, the
   lead does not open the review but briefs a fresh architect with the diff stat and the `## Files`
   bullets — "two PRs by path, or say it cannot". Can: a second task is registered, PR 1 is the branch
   with group 2 reverted to base, PR 2 stacked on it (the stacked-PR trial showed this works, at one
   rebase and re-gate per layer). Cannot: the PR carries the exception retroactively, says so in its
   summary, and the architect's next estimate learns from it.

The third moment is filed by task #8; it is the lead's procedure
and costs one paragraph in `skills/work/SKILL.md` step 4.

*Forecloses:* a file count in a project's gate (it would block a legitimate sweep with no valve); a
split after the diff has run long as the normal case.

## §6 — An older board is brought over in one pass

### D12 — `/crew:conform` does the countable half without a role, briefs the text half, and waits for the user on every item

"Rewrite on touch" was rejected: it guarantees a mixed board for as long as items go untouched,
which for parked items is forever, and Kris's requirement is uniformity. Conformance needs headers
and counts, not new prose — `Size:` is the `## Files` list counted, the Proof-map skeleton is derivable
from the criteria ids, the `Story:` line is known from the story, and only the TL;DRs are genuinely
new text. So `plugins/crew/skills/conform/SKILL.md` (`argument-hint: "[<n> | --all]"`,
`disable-model-invocation: true`), five steps:

1. `tracker.sh lint --all` for the non-conforming list with its per-item checks.
2. Draft the mechanical fixes with no role: `Size:` from the `## Files` count, `Story: #n` for a task
   lacking it, the Proof-map skeleton from the criteria ids, the `## Proves` line from a body already
   citing criteria in prose, and the flag that a `Split line:` is now required.
3. For each item needing text, brief the owning role — product-owner for a story, architect for a
   task — with that one item and nothing else, cheapest tier, in parallel across items.
4. Show the user a diff per item and **wait**; edit only after agreement, through
   `tracker.sh comment` / `gh issue edit`.
5. Report what conformed, what needed a split, and what the user declined.

Nothing is rewritten silently, no item is refused for being old, and the honest cost is stated: the
consuming project's pass will fail two of its eleven open tasks on `Size:` (#721 at H ≈ 22, #719 at
H ≈ 20) and those are split before they start — work the old shape was hiding. Kris, 2026-09-30: this
repository's own newly filed items (#1–#10) go through the same pass as the consuming project's
fifteen, and `tracker.sh lint --all` joins this repository's `gates:` line only after that pass has
run, so the gate never goes red on items that predate it.

*Forecloses:* a background sweep; a sweep task in the tracker (it rots, and filing is not finishing);
a script that writes a TL;DR.

### D13 — `/crew:init` learns the four keys and offers the render

The step-1 scan fills `generated:` and marks it *guessed*; the step-3 question round covers
`size-cap:`, `definition-of-done:` and `merge-authority:`; the report names the
`.claude/crew/items/<kind>.md` override; for a `github` tracker it offers the
`.github/ISSUE_TEMPLATE/` render, off by default, with D2's header; `/crew:status` warns when a
rendered file names an older plugin version than the installed one. The scan is setup only: what
proves A10 is the fallback rendering of D3 on a profile that declares none of the keys.

*Forecloses:* a render that is on by default; a drift check heavier than a version string compare.

## §7 — Reviewer isolation, findings and severity

### D14 — A reviewer's brief carries the change, the criteria and the contracts, and nothing written about the work by the people who did it

May contain: the diff (worktree path and reviewed commit `headRefOid`), the task's `## Proves` ids
with the story's criterion text for each, this design's contracts by section, the profile, the
findings format, the task's `## Done when` as the hard boundary, and the mandate "correctness and the
stated criteria; everything else is optional". May **not** contain: the implementer's report, the
lead's summary or narrative of what changed, the PR body's summary, or an earlier round's findings.
`skills/review/SKILL.md` step 2 and `skills/work/SKILL.md` step 4 state the prohibition, not a
permission, and `plugins/crew/scripts/tests/review-contract.test.sh` — filed with this item, not with
the templates story — asserts that both name every forbidden item and call the list a prohibition.

The evidence, all in `docs/design/crew-0.6.0-research.md`: a fresh-session reviewer scores F1 28.6 % against
24.6 % for self-review and 21.7 % for a second self-review in the same session, p ≤ 0.008
(arXiv 2603.12123, 2026-03-12); refined PR descriptions flipped the verdict in 32 of 33 real CVE
cases against Claude Code and CodeRabbit pipelines (arXiv 2603.18740, March–September 2026); Cognition
reports its reviewer "performs best with completely fresh context" (2026-04-22); Anthropic's own
callout is that a reviewer prompted to find gaps will report some even when the work is sound
(best practices, 2026). And the session's record agrees: the wrong findings came from a premise
handed to the reviewer, not from the diff.

*Forecloses:* a brief that says what the implementer thinks it did; a second reviewer that inherits
the first's findings.

### D15 — An agent review is a net under the human, never the gate, and one round is the ceiling

Frontier models find 15–31 % of what a human flags on 350 real PRs (SWE-PRBench, arXiv 2603.26130,
2026-03-27) and reach F1 0.066 on real PRs against 0.847 on synthetic bugs (arXiv 2606.15689,
2026-04-09); 61.38 % of agent-authored PRs on 100+-star repositories get no human review at all
(arXiv 2605.02273, 2026-05-04). So a change read only by agents has not been reviewed: the completion
record distinguishes what agents read from what the named human read, and the release says so (B3).
Kris, 2026-09-30: one round of agent review is the ceiling; a contested finding goes to the user,
never to a second pass in the same session against the same framing by readers who have taken a
position. A fix round still goes to a fresh agent with a complete brief — only what that brief may
contain changes.

*Forecloses:* "reviewed by the crew" as a merge condition; iterated in-session review rounds.

### D16 — A finding carries its reproduction or it is a question

A P1 or P2 names the command whose output shows it, or quotes the line: the surviving mutant, the
request that answered 500, the `ls` of the build context. Anything else goes in a separate
`## Questions` list, never enters a fix round, and is put to the owning role in the next brief marked
*believed*, costing one sentence. The 733 round would have been one question ("is `public/config.json`
in the image?") answered by one probe. The rule lands in `review/SKILL.md` step 3, `work/SKILL.md`
step 4 and the Findings line of the three personas that file findings (`qa-engineer`,
`security-engineer`, `architect`) — not in the shared output-contract line that sits in 16 of 17
personas, because that is a 16-file diff with no seam (D10 at work). QA's finding takes the criterion
shape: "`AC n` has no test that dies under mutation", so traceability is checked as a mutation, not a
reading. The brief template's `Known context` gains `Evidence file:` naming the scout's own report,
and whatever the lead adds is `believed` unless it quotes a line — the wrong 733 premise was born in
a lead-written body with no such marker.

*Forecloses:* a finding by reasoning alone; a fix round on an unverified premise.

### D17 — Severity and what is fixed where (Kris, 2026-09-30)

- **P1** is always fixed in the task under review.
- **P2** is fixed in the task when the task caused it or made it reachable; otherwise it gets one line
  in the PR and its own item (a bug or tech-debt body, `p2` label). **P3** is grouped, and lands in a
  planned task's body or its own item.
- **Mutation anchor:** a `Survived` mutant on a line the PR changed is P1; elsewhere in a touched file
  it is P2; a mutant no test reaches is checked against the wider suite first and is never a finding
  on its own. A reviewer may depart from the anchor: it states the anchor's rating, the rating it
  gives and the one reason, and the departure is the lead's to accept or put to the user — it is
  never silent.

The two cases from the #731 round that fixed the boundary: the first-act race
(`PlanVersionStore.RecordAsync`'s `StartStream` branch letting `ExistingStreamIdCollisionException`
escape as a 500) was pre-existing, but #717's new act endpoint made it reachable — the
security-engineer's P2, fixed in #732 with a red run quoted; the `lost_race` counter's own tags at
`ModelFlowPublication.cs:82` were pre-existing and untouched by the change — one line in the PR,
"left open deliberately, pre-existing", and nothing folded into the fix round. The same round rated
four changed-line survivors P2 rather than the anchor's P1, as one observability group with the reason
stated; that is the departure form D17 keeps.

*Forecloses:* a P2 fixed under review because it was nearby; a pre-existing defect the task made
reachable being deferred as "not mine".

## §8 — The model audit

### D18 — `subagent-model.sh audit` walks the session's own files and is the proof; the hook is best-effort

`audit [<session-dir>]` walks `tasks/*.output`, prints one line per run — role, declared model, actual
models, call count, output size — with `MISMATCH` where declared and actual disagree, a closing
`N runs, M lines, K mismatches`, and exits 1 when K > 0 or M < N. A run it cannot resolve still gets a
line reading `unresolved` so the count never silently shrinks (B4: a record with fewer lines than runs
fails). The role comes from the payload's `agent_type` when present and otherwise from the
transcript's own first `Role: <name>` line, which every crew brief starts with; the declared model
from the persona's frontmatter as today (`declared_model_for`). `/crew:status` and `work` step 8 print
the table at every task boundary instead of `tail 10` of a log that has one line in it.

The hook (`scripts/subagent-model.sh` on `SubagentStop`) keeps its fallbacks and gains two: the same
role fallback, and the transcript resolved from the session's `tasks/<agent_id>.output` and
`subagents/agent-<id>.jsonl`. When it still cannot resolve either, it logs the payload's own field
**names** once — never a value; a prompt is not for a log — so the next diagnosis is a read, not a
guess. It never fails the run it observes: exit 0 on every path, nothing on stdout, no
`hooks/hooks.json` change expected. B4's proof is the audit over a real session of at least ten runs,
beside the count of runs the hook logged over the same period — the number that made this necessary.

*Forecloses:* a proof that depends on a payload field this client does not send; a hook that can fail
a subagent; a log line carrying a payload value.

### D19 — Rule 13 and the README stop claiming the hook proves it

`templates/operating-model.md` rule 13: the audit is the proof, the transcript grep
(`grep -o '"model":"[^"]*"' <output> | sort | uniq -c`) is the fallback, and the sentence claiming the
hook logs the same comparison per session is **deleted** — a rule that tells the lead something is
proved when it is not is worse than no rule. README "Which model actually ran": the same correction,
naming the hook as best-effort and the audit as the proof. B6's proof is a search showing the
sentence is gone. Default tiers per role are out of both stories: the removed task 8 is filed on its
own, and this design says nothing about which tier a role should run on.

*Forecloses:* "the hook logs it automatically" anywhere in the plugin's prose.

## §9 — Traceability

### D20 — Criterion ids are permanent integers per story, and `## Proves` is what makes the Proof map mechanical

Ids are `1..n` inside a story, never renumbered, never reused; a withdrawn criterion stays in place
reading "withdrawn — <reason>". The only cross-reference anyone writes is `<story-ref> AC <n>` — the
sigil from `tracker:` — under a task's `## Proves`, and a task naming no criterion is refused at
create (D5): a task that proves nothing should not have been planned. The story's Proof map has one
row per criterion (refused otherwise) and four columns filled by four hands: the product-owner ships
it with the first column only; the architect fills Task at plan time from the `## Proves` lines; the
engineer fills "Proven by" in the PR that lands it; the lead ticks on merge, and where the profile has
a deploy target, when seen working there. That table is the one place anyone looks to answer "how far
is this story". The board does not compute criteria no task claims — the empty rows show it, and that
computation was cut deliberately.

*Forecloses:* a criterion id that moves; a tracker feature beyond editing a body; a tag on every
criterion for provenance (it lives once under `## Related`).

### D21 — The product-owner names what WOULD prove a criterion, the engineer names the test that DID, and a disagreement is a finding

The italic *Would be proved by* line under each criterion is written by the product-owner before
anyone knows a test's name and is never rewritten to match what the engineer did; the Proof map's
"Proven by" column is the engineer's alone and names the test that actually ran, never a restatement
of that line. They answer different questions — intent and record. When the two describe different
things, nobody edits either: it is a finding to the product-owner, who accepts the engineer's proof
as sufficient or names the part of the criterion still unproved. `agents/product-owner.md` carries
the numbering rule and the first-column-only Proof map; the traceability check at review is D16's
"`AC n` has no test that dies under mutation".

*Forecloses:* a "Would be proved by" line edited after the fact; a Proof-map row filled by the role
that wrote the criterion.

## §10 — Upgrade and compatibility

### D22 — A board that upgrades and changes nothing else keeps working, and one command tells it what would fail

On 0.6.0 with no profile edit and no conform pass, a project meets exactly three things, and the
release notes say which and when:

1. **Day one, on new bodies only:** `story create` and `task create` refuse a body that does not
   conform (§3). Nothing already on the board is touched — `lint` reads, `claim` edits labels and
   assignees as before, and `conform` runs only when asked and waits on every item.
2. **Day one, on old bodies:** `claim` succeeds and prints the failing checks as `warning:` lines
   (D7); every item stays claimable.
3. **When the project chooses:** `tracker.sh lint --all` reports which existing items would fail
   before anyone meets a refusal; `/crew:conform` brings them over in one reviewed pass (§6).

Every new profile key renders its fallback when absent (D3), and every skill reads the plugin's
template when the project has no override (D1), so a profile written for 0.5.9 is a valid 0.6.0
profile. A11's proof is the witness over an old-shape board asserting the claim succeeds and nothing
is edited, plus the lint report over the same board and the one sentence in the documentation.

*Forecloses:* migration tooling past one command; version negotiation; a compatibility matrix.

### D23 — 0.6.0 is a minor release, one commit, and it marks this design shipped

Both manifests (`.claude-plugin/marketplace.json`, `plugins/crew/.claude-plugin/plugin.json`) carry
`0.6.0` — minor because the templates and `/crew:conform` are new capability, the four keys are
additive with fallbacks, and the one behaviour change to an existing project (a refused new body) is
what a minor bump announces. The release notes carry, in one place: the one behaviour change, the keys
that are safe by their absence, and the one command that reports existing items (B8). The README is
read against the tree the eight PRs left — Layout, Roles, "Model per role", "Which model actually
ran", "Honest limits" — with the technical-writer reviewing (B7). This document is then marked shipped
with the version and the date and records the one thing the plan got wrong if any task returned a
correction. The release commit changes no script, skill, persona or template: a release that also
changes behaviour cannot be rolled back by a version pin.

*Forecloses:* a patch bump for a refusal; a release commit carrying a behaviour change.

## Deliberately not done

- A third level (epic, feature, wave): "wave" stays a word in a body.
- A separate specification document: the story is the specification, and the outside evidence found
  no measurable gain from a third artifact over a story with testable criteria plus a design
  (Scott Logic 2025-11-26, Marmelab 2025-11-12, Thoughtworks Radar Nov 2025).
- Default model tiers per role: out of both stories; the removed task 8 is its own item.
- The board computing criteria no task claims; the PR body's criterion table (a definition-of-done
  item, not a criterion); the consuming project's own docs and checklists; the tracker rename; an
  Azure DevOps adapter (`tracker.sh` still exits 2 for it — one adapter function when it comes, not a
  template change).
- A machine check for whether a TL;DR reads well (D8).

## Risks

- The validator's section list read from the template (D5) makes an overriding project's bodies
  checked against its own headings; a project that removes `## Tasks` from its story override breaks
  its own rollup, and the template comment says so.
- `lint` at `--limit 500` per kind: a board past 500 of one kind needs paging; the closing line must
  say when the limit was hit rather than report a partial count as whole. **Closed by #14**, after
  this release shipped: the cap is 2000 per kind, a fetch that comes back full names the kind and the
  limit in the closing line, and `lint` exits 2 for it — a partial read rather than a verdict.
- The before-review count (D11, moment 3) is filed in task #8; the lead's procedure is detailed there.

## Corrections the tasks returned

Recorded by task #10, 2026-10-01, from the closing comments of #3–#9 and #11–#13. The decisions above
stand as written; this is what the plan got wrong, so the next design does not repeat it.

- **The evidence under "The model proof did not exist" compared two sessions.** The hook log quoted
  there belongs to one session id and the `.output` files to another, which is itself the defect #9
  fixed. The hook also fires more than once per completion — 723 log lines for 180 runs — so its line
  counts were never run counts. The Haiku runs in the measured window are ten, not eight, and every
  one was explicitly dispatched on Haiku; they read as mismatches only because the comparison used the
  persona default instead of the dispatch.
- **D16 was too strong as first written.** "A finding you have not reproduced is not a finding" closed
  the class of authorization and tenant gaps this tree cannot execute, where a quoted line and the
  path reaching it are the only proof there is. The shipped wording is a disjunction — a command whose
  output shows it **or** the quoted line — and a finding that could not be executed says so. The same
  review found the three review personas being asked for a `## Questions` section their own output
  contract forbade.
- **D12's split of the countable half from the text half was incomplete.** Step 2's countable list
  omitted the `Blocked by:` and `Role:` header lines and half of `Size:`, and step 3 triggered only on
  a missing *section* — so a missing header line was handled by nobody. `lint --all` on this
  repository's own board reports exactly one failing item whose only fault is that line, so the pass
  as designed would have run against its own demonstration case and changed nothing. Step 2's first
  bullet and step 3's trigger now say "section or header line".
- **Story #2's criterion 9 contradicted itself** — it required two personas on `opus` while the rule
  it also stated allowed a move only on a logged miss. Resolved by scoping the rule rather than
  weakening it: judging a tier *wrong* is a quality claim and needs named evidence; choosing the
  frontmatter fallback answers a different question — which tier runs when a lead names none — and a
  fallback is chosen, not earned. #11 ships both changes under that scoping and the roster says so.
- **D14's witness was hung on the wrong task.** The assertion that both skills name every forbidden
  item and call the list a prohibition was first attached to the templates story's witness; it moved
  to the task that authored the prohibition, as `plugins/crew/scripts/tests/review-contract.test.sh`.
  D14's text above already names it there.
- **§5/D11's foreclosure was read wider than it is.** It forecloses a file count in a project's
  *gate*, not a count before review: what shipped is `skills/work/SKILL.md` step 4, a lead step over
  the committed diff, which is what moment 3 always described.
- **The design named no transition meaning *finished*.** `claim` adds `in-progress` and `release`
  offered only `in-review`, `blocked` and `open`, so closing an item always left the lane label and
  `status` counted finished tasks as in flight — five of them were. `rg 'gh issue close'` across the
  plugin returned nothing: the pipeline had no documented end at all. #13 adds `release --to done` and
  `work` step 7, keyed on the merge event rather than on who merged.
- **The design cited `tracker.sh show` as the read path without checking it.** It printed only the
  comment stream, so the two pipeline steps that open on it — `plan` step 1 and `work` step 1 — could
  not see a body, and `/crew:conform` carried a workaround sentence explaining why not to use it.
  Fixed in #12; the usage line had said `(issue + comments)` since the beginning.
- **Documentation drift the design did not know about**: `README.md` and
  `templates/operating-model.md` both named a stale model trio that had been wrong since 0.5.6, and
  the README's witness list lagged the tree twice during the eight tasks. The gate validates neither
  — see the README's "Honest limits".
- **D18 names a stale step number** — "`/crew:status` and `work` step 8 print the table", at `:412`
  here (`:410` before this section was added); the audit is printed at `work` step 9 after
  renumbering. It **stays as written**, for the reason at the top of this file.
- **Task #10's own body undercounted twice.** It said `scripts/tests/` holds two witnesses — the tree
  holds four — and said both manifests enumerate the pipeline skills, where only
  `plugins/crew/.claude-plugin/plugin.json` did. Its file list also carries no release-notes file;
  0.6.0 adds `CHANGELOG.md` as a fifth, because the release has to say what changed somewhere a
  reader who installs it can read.

## Section map — which task cites what

| § | Carries | Cited by |
|---|---|---|
| §1 | the item shape, override, why not a copy | #3 |
| §2 | the four keys and their fallbacks | #3, #6 |
| §3 | the first-line contract and the create-time checks | #4, #5 |
| §4 | refuse at create, warn at claim, `lint`, labels, what is not gated | #5 |
| §5 | the size contract and the three moments | #6, #8 |
| §6 | `/crew:conform` and `/crew:init` | #7 |
| §7 | reviewer isolation, findings, severity | #8 |
| §8 | the model audit and rule 13 | #9 |
| §9 | traceability — criterion ids, `## Proves`, the Proof map, the split of duty | #4, #6 |
| §10 | upgrade, compatibility, the release | #10 |
