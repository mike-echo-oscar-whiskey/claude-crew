# ♻️ refactor(crew): the machine facts of an item leave its body for a data file in the repository, and the body keeps only what a person reads

Design for release 0.7.0. Architect, 2026-09-30. Status: **proposed** — design only; the task list is
not part of this document. Sections are numbered §1–§9 so tasks can cite them; the ten questions the
brief put are mapped to decisions at the end.

## Problem

Four things went wrong under 0.6.0, all countable, all in this repository's own history or the
consuming project's board.

- **A task lost its own story.** Task #4's body was rewritten by an agent during its round and came
  back without its `Story: #1` and `Blocked by: #3` lines. The board rolls a task up under its story by
  `select(.body | startswith("Story: #" + n))` (`plugins/crew/scripts/tracker.sh:462`) and lists it as
  claimable by `grep -oE '^Story: #[0-9]+'` (`:452`), so the task that existed to make that first line a
  checked contract was, for a while, invisible to the story it belonged to.
- **Eighteen of 209 tasks were absent from a board with no error anywhere.** On the consuming
  project's tracker, 18 task bodies do not begin with the rollup line. `status()` and `next()` match
  prose; a body that starts otherwise is not wrong, it is gone. 0.6.0 made `task create` refuse such a
  body (D4), which stops the next eighteen; it did not stop a body edit after creation, which is how #4
  lost its lines.
- **A number was hand-amended twice to chase a count a program would have produced.** Task #8 was
  filed at `Size: 6 hand-written files`. Its review added three files. The delivery lead edited the
  issue body twice — the `Size:` line and the `## Files` list — so that `## Files lists 9 files, Size:
  says 6` would stop being a lint refusal. `gh issue view 8` shows the result: nine bullets, three of
  them ending "Added in review", and a `Size:` that reads `9` because a person retyped it.
- **The validator is a parser for a data format written in English.** `validate_task_body`
  (`tracker.sh:164-223`) reads `Size:` with a five-clause regular expression over a prose line
  (`:181`), counts files by counting Markdown bullets under a heading (`files_hand_written`,
  `:107-121`), reads the story number out of the first line (`:342`), and finds blockers with
  `grep -oE '#[0-9]+'` over a `Blocked by:` line (`:439`). Every one of those is a fact — a number, a
  reference, a list of paths — stored as a sentence, and every check is a comparison between two
  sentences that must agree.

The board's own typed fields go unused: on the consuming project, 0 of 209 tasks carry a `parent` and
0 carry a `blockedBy` relation (`gh issue list --json parent,blockedBy`, 2026-09-30), while every one
of them carries the same facts as prose.

## Why

Kris, 2026-09-30, the decision this design implements and does not reopen: a work item's body stays
human-readable prose; the machine-readable data lives in a file in the consumer repository, one per
item, validated by the project's own gate. His words: "I am not saying the body of stories and tasks
should be json, that should be human readable, maybe an attachment could be the json for the
agents/scripts." A literal tracker attachment was investigated and ruled out: `gh issue create
--attach` takes images and videos only, appends them to the body as a Markdown reference, and there
is no attachment or asset field on the read side, so an agent cannot fetch one back as data.

The inversion this design works out is **not** "render the body from the data". It is: the machine
facts leave the body entirely. There is no renderer, so nothing ever overwrites prose a person edited
on the tracker, and no multi-line prose ever sits inside JSON.

Constraints that bind every decision below: `jq` is the only data dependency a consumer has (it is on
every profile's `gates:` line already); boards filed under 0.6.0 keep working unchanged; there is no
CI, so a consumer's `scripts/local-gates.sh` and the plugin's own commands are the only enforcement
points; `tracker.sh` stays the adapter boundary and the schema encodes nothing GitHub-shaped.

## §1 — What leaves the body and what stays

### D1 — Seven facts move to the data file; five sections of prose remain

Today's task body carries, in prose clothing: `Story: #n`, `Blocked by:`, `Role:` with its
`design:` pointer, `Size: <H> … <T> …`, `Split line:`/`Exception:`, a `## Proves` list of criterion
references and a `## Files` bullet list. From 0.7.0 the data file carries the story, the role, the
blockers, the design pointer, the criteria proved, the file list and the exception licence. The body
keeps `## TL;DR`, `## In one paragraph`, `## Goal`, `## Tests (RED first)` and `## Done when`, and
gains one prose section, `## Split line`, because the seam a task is cut at is a sentence about the
work and belongs with the other sentences — #7's and #8's split lines run four lines each and would
have been the multi-line prose this design keeps out of JSON. A body starts at `## TL;DR`: no header
lines at all.

Two numbers of the old `Size:` line are computed, never declared. H is the length of `files` minus the
entries matching the profile's `generated:` globs, G is those entries — one `jq` read and the same
glob match `files_hand_written` does today. T, the count of numbered RED tests, stays a property of the
body: the tests are prose the body keeps, and counting `^[0-9]+\.` under one heading is Markdown
structure, not a data format in English. T is therefore not in the file, and the rule "T = 0 only when
the section says the task is test-free" stays a body check.

Bugs get the same file as tasks, because a bug carries a `Size:` line and a `## Files` list too
(`templates/item-bug.md`): leaving bugs on prose would keep the `Size:` regex alive for one kind.
Stories and tech-debt items carry no size contract and get no file; a story's criterion ids are
numbering of prose, like headings, and stay where they are.

*Forecloses:* a body rendered from the file; a `Size:` that a person types; a `## Files` section in a
body; a file for a kind that has nothing countable in it.

### D2 — One file per item at `.claude/crew/items/<id>.json`, and the id is the file name

The brief's working shape was `.crew/items/<n>.json`. This design puts the file under the root the
crew already owns in a project — `.claude/crew/` holds the profile, `roles/` and the template
overrides — so there is one directory to look in, one glob in a gate and one path in the README. The
override templates already live at `.claude/crew/items/<kind>.md`; a data file is `<id>.json`, a
number against a kind name and one extension against the other, and the gate's glob is
`.claude/crew/items/*.json`.

The item's id is the file name and appears nowhere inside the file: a copy inside is a second source
for the one fact that cannot be wrong. `jq` reads it through `input_filename` when it needs it. The id
is a **string**, as the tracker prints it without its sigil — `8.json` here, `PROJ-12.json` on a Jira
backend — because an integer id would encode two of the three backends into the schema.

*Forecloses:* a second root beside `.claude/crew/`; a `number` field; an integer item id.

## §2 — The schema

### D3 — Schema 1 is a closed set of nine keys, and `jq` in `tracker.sh` is its only validator

```json
{
  "schema": 1,
  "kind": "task",
  "story": "2",
  "role": "agentic-ai-engineer",
  "blockedBy": ["6"],
  "design": { "path": "docs/design/crew-0.6.0-items-and-proof.md", "sections": ["§7", "§5 D11"] },
  "proves": [
    { "story": "2", "criterion": 1 },
    { "story": "2", "criterion": 2 },
    { "story": "2", "criterion": 3 }
  ],
  "files": [
    { "path": "plugins/crew/skills/review/SKILL.md", "note": "steps 2 and 3" },
    { "path": "plugins/crew/skills/work/SKILL.md", "note": "step 4: isolation and the before-review size count" },
    { "path": "plugins/crew/agents/qa-engineer.md", "note": "the Findings line" },
    { "path": "plugins/crew/agents/security-engineer.md", "note": "the Findings line" },
    { "path": "plugins/crew/agents/architect.md", "note": "the Findings line" },
    { "path": "plugins/crew/templates/operating-model.md", "note": "the brief template's Evidence file: and believed-by-default" },
    { "path": "plugins/crew/scripts/tests/review-contract.test.sh", "note": "the witness that holds the contract; added in review" },
    { "path": ".claude/crew/profile.md", "note": "the witness joins the test: and gates: lines; added in review" },
    { "path": "docs/design/crew-0.6.0-items-and-proof.md", "note": "D14 names the witness above; added in review" }
  ]
}
```

That is task #8 as it landed: nine files, three of them added during review, H = 9 and G = 0 under this
repository's `generated: -`, no exception because 9 ≤ 15. The three review additions are three hunks in
the PR that added them, not two hand edits of an issue body.

| Key | Type | Rule |
|---|---|---|
| `schema` | integer | exactly the version this plugin reads (1) — see D11 |
| `kind` | `"task"` or `"bug"` | decides which of the rules below apply |
| `story` | string id | required for a task; optional for a bug (absent = standalone) |
| `role` | string | one of the plugin's roles (`ROLES` in `tracker.sh`) |
| `blockedBy` | array of string ids | may be empty; never absent |
| `design` | `{path, sections?}` | `path` must exist in the checkout; `sections` is free strings |
| `proves` | array of `{story, criterion}` | non-empty for a task (D20's "a task proving nothing was not planned"); empty allowed for a bug |
| `files` | array of `{path, note?}` | non-empty; `path` unique; `note` one line, at most 120 characters |
| `exception` | string | optional; one line, the reason; its presence is the licence to exceed `size-cap:` |

Any other key is refused, and the reason is the whole point: a typo — `blockedby`, `file` — would
otherwise drop a blocker or a file list in silence, which is the class of failure this design exists to
end. The validator is one `jq` program in `tracker.sh` that emits an array of failure strings (`[if
.schema != 1 then "schema must be 1" else empty end, …]`), printed one per line as `refused: …`, every
failing check at once, in the form D5 set. There is no JSON Schema file: nothing available on a
consumer's machine could enforce one, and a schema document nothing refuses rots. The `jq` program is
the schema; the table above is its prose; `scripts/tests/tracker.test.sh` holds the two together.

*Forecloses:* an open key set; a JSON Schema file; a `python3`/`ajv`/`yq` dependency; a note that
runs to a second line.

## §3 — Where each fact is read from, and who writes it

### D4 — The file is the write model, the tracker's typed fields are the read model, and the adapter projects one onto the other

The story–task relation and the blockers are facts every backend already has a typed field for:
GitHub's `parent`/`subIssues` and `blockedBy`/`blocking` (`gh issue view --json` exposes all four, and
`gh issue create --parent --blocked-by`, `gh issue edit --parent --add-blocked-by
--remove-blocked-by` write them; verified on gh 2.101.0), Jira's parent and issue links, Linear's
parent and blocked-by. The role and the kind are labels already. So the question the brief put — do
the relational facts belong in the typed fields rather than the file — has the answer **both, with a
fixed direction**: the file is where the plan writes them and the gate reads them; the typed fields
are what the board computes from; the adapter is the only thing that writes the typed fields, and it
writes them from the file.

Why not the typed fields alone: the gate needs `story` to check that every `proves` entry names a
criterion that exists, and a gate cannot call the tracker; and a second backend may lack one relation
(Jira "blocked by" is a configurable link type, not a given). Why not the file alone: `status` and
`next` would then depend on the checkout — a task planned on a branch whose PR is not merged would be
on the tracker and absent from the board, which is the 18-invisible-tasks bug in a new coat. With two
copies and one comparator (D8), a disagreement is visible; with three, it is not.

Readers therefore change as follows. `status()` rolls tasks up by `parent` (`gh issue list --json
number,parent,…`, one call as today), `next()` reads blockers from `blockedBy` (the same list call
returns each blocker's number; state is one `issue view` per blocker as now), and neither opens a file.
`work` step 1 opens the file — and stops when it is not on the branch's base: "no
`.claude/crew/items/<n>.json` on `<default-branch>`: the plan's change is not merged, or this item
predates 0.7.0 — `/crew:conform` brings it over". A task is claimable once its plan has landed, which
is what the consuming project already does by practice (design PR #655 merged before #656 started).

*Forecloses:* a board that depends on a checkout; a typed field written by anything but the adapter;
a schema field that names a backend.

### D5 — The plan writes the file, the adapter names it, and the file travels with the design

`plan` step 5 writes, per task, a data file and a body to temp paths and runs `tracker.sh task create
--title "<t>" --data-file <d.json> --body-file <b.md>`. The `--story`, `--role` and `--blocked-by`
flags retire: they are in the data. The adapter, in this order:

1. validates the data (D3) and the body (D9) — exit 1 with every refusal, no tracker call;
2. creates the issue with the kind label, the `role:<r>` label and, for a github tracker, `--parent`
   and `--blocked-by` from the data — this is where the number is born;
3. moves the validated temp file to `.claude/crew/items/<n>.json` — a rename inside one filesystem,
   the smallest step that can fail;
4. prints the number.

If step 2 fails there is nothing to undo. If step 3 fails the issue exists and the file does not: the
adapter exits 1 and prints the number, the temp path and the one command that finishes it
(`mv <tmp> .claude/crew/items/<n>.json`); from then on `lint` reports `#n has no data file`, `work`
refuses to start it (D4), and the adapter never creates a second issue for the same body — that is
the one recovery path, and it is idempotent. If the projection in step 2 is partial (a label set, a
relation refused), `sync` (D8) repairs it from the file.

The files are committed with the design document, on whatever branch the project's git rules put it,
by the lead (`plan` step 6 already commits the design). Afterwards the file is edited like any file in
the repository: the delivery lead at claim, when an old item is sized by hand; the owning role in its
own change, when the list grows once the code is open — which is exactly #8's case, and the growth
becomes hunks in the PR that a reviewer sees, not a hand edit of an issue. Every edit to `story`,
`blockedBy`, `role` or `kind` is followed by `tracker.sh sync <n>`, which `work` step 6 runs before
the PR is opened so a projection is never stale for longer than one task.

*Forecloses:* a number reserved before the issue exists; a second `gh issue create` on retry; a
`--story`/`--role`/`--blocked-by` flag on `create`; a file edited by a script other than through
`mv` at create.

### D6 — The adapter stops appending the `## Tasks` checklist to a story on a backend that renders sub-issues

`task_create()` today reads the story body, appends `- [ ] #n (role) title` under `## Tasks` and
writes the **whole body back** (`tracker.sh:312-315`). That is a body rewrite of a document a person
may be editing on the tracker at that moment, and the one place in the adapter where the prose-clobber
this design exists to end is built in. With `parent` set (D4), GitHub renders the sub-issue list and
its progress on the story itself, so the checklist is a third copy of a fact the tracker now holds
twice. From 0.7.0 the github adapter does not write it. `## Tasks` stays the last section of the story
template — a project override may want it, and the on-board validator already accepts it empty
(`check_sections` exempt heading) — and the template comment says the adapter no longer fills it.

*Forecloses:* an adapter write to a story body after creation; a template contract that names the
checklist as the rollup.

## §4 — Enforcement: what refuses, where

### D7 — Four moments enforce the file; the consumer's gate holds the one check only it can make

| Moment | Who | Checks | On failure |
|---|---|---|---|
| create | `tracker.sh task create` / `bug create` | D3 schema; H ≤ `size-cap:` unless `exception`; `design.path` exists; every `proves` criterion exists in the story body (`^<n>\.` under its criteria heading, one `issue view`); body per D9 | refused, nothing created |
| claim | `tracker.sh claim` | the same, read-only, printed as `warning:` lines; an item with no file prints one warning line and is claimed (D7 of 0.6.0 stands) | never refused |
| before review | `tracker.sh size <n>` in `work` step 4 | H, G, and the branch's `git diff --name-only <base>...HEAD` minus `generated:` minus `.claude/crew/items/*.json`, listing every path the diff touches that `files` does not name; exit 1 when the list is non-empty or H > cap without `exception` | the review does not open; the role adds the paths to `files` in the same change, or the lead briefs an architect for the split, as D11 of 0.6.0 says |
| gate | the consumer's `gates:` command | `jq empty` over the items; on a branch matching `branch-pattern`, the same diff-versus-`files` check and the cap | red |

The gate row is honest about what a project gate can and cannot do. It cannot call the plugin: the
installed copy lives at a versioned path (`~/.claude/plugins/cache/claude-crew/crew/<version>/`), there
is no stable link, and a Codex install has no equivalent — so a `gates:` line naming `tracker.sh` rots
on the next upgrade. It can do everything that needs `jq` and `git` alone, and that is the check that
matters most: the diff is a subset of the declared list, and the count is under the cap. Ten lines
the design fixes once, so a project copies the contract rather than the validator:

```bash
n=$(git rev-parse --abbrev-ref HEAD | sed -nE 's#^task/([^-]+)-.*#\1#p')   # the profile's branch-pattern
f=.claude/crew/items/$n.json
if [ -n "$n" ] && [ -f "$f" ]; then
  cap=$(sed -nE 's/^size-cap:[[:space:]]*([^[:space:]#]+).*/\1/p' .claude/crew/profile.md); cap=${cap:-15}
  declared=$(jq -r '.files[].path' "$f" | sort)
  touched=$(git diff --name-only "$(git merge-base origin/master HEAD)"...HEAD | grep -v '^\.claude/crew/items/' | sort)
  undeclared=$(comm -13 <(echo "$declared") <(echo "$touched"))   # minus the generated: globs, as the project matches them
  [ -z "$undeclared" ] || { printf 'crew item %s: touched but not in files:\n%s\n' "$n" "$undeclared"; exit 1; }
  jq -e --argjson cap "$cap" '(.exception != null) or ((.files | length) <= $cap)' "$f" >/dev/null || { echo "crew item $n: over size-cap $cap with no exception"; exit 1; }
else echo "crew items: no item for branch $(git rev-parse --abbrev-ref HEAD); file-list check skipped"; fi
```

The only schema the gate depends on is two keys, `files[].path` and `exception`, frozen by schema 1.
A branch that matches no item prints that it skipped — a printed skip, never a silent one. The
plugin's own `lint` is where the full schema is judged (D9); a project that wants that in its gate
too wires `tracker.sh lint --files` through the path it chooses to name and owns that choice.

This supersedes one foreclosure of 0.6.0 D11 — "a file count in a project's gate (it would block a
legitimate sweep with no valve)" — because the valve now exists in data: `exception` is read by the
gate, and a sweep declares it at plan time as D9 of 0.6.0 always required.

*Forecloses:* a `gates:` line that names the plugin's path; a copy of the validator in a project; a
size check that silently skips on a branch it cannot map.

### D8 — `lint` compares the file to the tracker and the file wins; `sync` is the one repair

`tracker.sh lint` keeps its shape (`[<n> | --all | --kind …] [--quiet]`, one list call per kind, exit 1
when any item fails and exit 2 when a kind's fetch came back filling its limit, which is a partial read
and not a verdict) and, for every item that has a file, adds three comparisons to the schema check:
`story` against `parent`, `blockedBy` against `blockedBy`, `role` and `kind` against the labels. A
disagreement is one line —

```
#12   task   blockedBy: file [6], tracker [6, 9] — the file is the record; keep the tracker's change with:
              jq '.blockedBy += ["9"]' .claude/crew/items/12.json  then  tracker.sh sync 12
```

— and the verdict is fixed: **the file is the record.** It is in git, it was validated when it was
written, and a change to it is a reviewed diff; a change on the tracker's web page is none of those.
The line prints the one `jq` edit that would make the file agree with the tracker, so keeping a
deliberate web edit costs one paste, and then `sync`. `tracker.sh sync <n> | --all` writes the typed
fields and labels from the file — `--parent`, `--add-blocked-by`/`--remove-blocked-by` by set
difference, the two labels — and never touches a body or a file. It is idempotent and is the whole
of the write path from file to tracker after create. Body checks stay as D9 lists them; a body a person
edited on the tracker is judged on its sections and placeholders and on nothing that was moved to the
file, so there is nothing left in a body for an edit to break silently.

`/crew:status` keeps printing `items: N conforming, M not`; an item whose only fault is drift counts
as not conforming, and the line names the repair.

*Forecloses:* a second direction (`sync --from tracker`); a `lint` that edits; a verdict that depends
on timestamps.

### D9 — What `lint` judges in a body from 0.7.0, and what it stops judging

For a task or bug **with** a file, the body checks are: every `##` heading of the resolved template
present and non-empty; no surviving placeholder; `## Tests (RED first)` numbered count T at most five,
and T = 0 only with the test-free sentence; `## Split line` non-empty when H ≥ 12 or T ≥ 4, where H
comes from the file — the one check that reads both, and the reason the section is a heading rather
than a header line that a rewrite can drop. Retired for those items: the first-line check (0.6.0 D4),
the `Blocked by:`/`Role:`/`Size:` presence checks, the `Size:` regular expression, the
files-by-bullets count, the `## Proves` grep. Story bodies keep every 0.6.0 check.

For a task **without** a file the 0.6.0 task validator runs unchanged and its line is prefixed
`legacy:` — the item is not wrong, it predates the file — for as long as §6 says.

*Forecloses:* a check that reads a fact from a body when the file holds it; a body check that cannot
be stated as heading, emptiness, count or placeholder.

## §5 — The body keeps no pointer

### D10 — No machine-readable line survives in a body, not even a pointer to the file

The mapping from item to file is the number, which the tracker shows on every page and every list, and
`.claude/crew/items/` is one directory. A pointer line would be the one line `lint` would have to grep
for, and one line an edit could drop — the class this design retires. Nothing reads a body for a
fact, so nothing is written there for a reader to find. A reader on the tracker's web page who wants
the file list opens the PR that carries it; the review reads it in the diff; the role gets it in its
brief, because `work` step 3 hands the file over beside the body.

The presence of a file is also the per-item adoption signal (§6): no key in the profile, no line in
the body.

*Forecloses:* a `Data:` line; a comment carrying a copy of the file; a profile key that says a project
adopted.

## §6 — Compatibility, versioning and the migration window

### D11 — `schema` is an integer; a newer file is refused, an older one is read

A plugin reads every schema up to its own. A file whose `schema` is greater than the plugin's is
refused at every moment with both numbers named (`schema 2 is newer than this plugin reads (1):
upgrade the plugin`) — never read on a guess, because a key the reader does not know may carry a
licence or a blocker. A file whose `schema` is lower is read with that version's rules, and `lint`
prints `schema 1, current 2: /crew:conform migrates it` for it. A schema bump ships its migration as
one `jq` expression in `tracker.sh`, applied by `/crew:conform` (task #7's vehicle) as a diff the user
sees per item, never in the background; every bump is additive or is a major release.

*Forecloses:* a reader that ignores an unknown schema; a migration that runs on read; a schema bump
in a patch release.

### D12 — A board that never adopts keeps exactly what it has, and one minor release later the prose readers go

On 0.7.0 with no file in the repository:

| Behaviour | Still works | Degrades |
|---|---|---|
| `status`, `next`, `claim`, `release`, `show`, `comment` on items filed under 0.6.0 | yes — `status` falls back to the first-line match and `next` to the `Story:`/`Blocked by:` grep when `parent`/`blockedBy` are null | |
| `lint --all` | yes; old tasks are reported `legacy:` with the 0.6.0 checks | the count says how many items have no file |
| `story create` | unchanged | |
| `task create`, `bug create` | | require `--data-file`: the first new item is the moment a project adopts, and the cost is a directory |
| `tracker.sh size`, the diff check, `sync` | | not available for an item without a file — `size` says so and exits 1 |
| `work` step 1 | | stops on an item without a file and names `/crew:conform` |

The prose fallbacks in `status` and `next` and the `legacy:` validator are kept for 0.7.x and removed
in 0.8.0, which is at least one release after `/crew:conform` (#7) can bring a board over in one pass.
From 0.8.0 an item with no file is not invisible: `status` lists it under an `unlinked` heading of its
own and `next` prints it with `story ?` and no blocker check — loud, not absent. The consuming
project's 209 tasks and this repository's own ten are brought over by that one pass; #7 gains one
step, "write the data file from the body's header lines and `## Files`, and set the typed fields", and
the pass is the only time a program writes a file from prose.

*Forecloses:* a fallback that outlives 0.7.x; an unfiled item that is silently absent in 0.8.0; a
migration by a script that is not shown to the user.

## §7 — The size contract's three moments, re-stated

### D13 — Create and before-review become computations; claim stays a comparison of nothing new

0.6.0 D11 named three moments. Under this design:

1. **Create** — a computation: H and G from `files` and the globs, compared to `size-cap:` and to the
   presence of `exception`; there is no `Size:` to parse and no bullet count to match, so the two
   refusals of 0.6.0 that compared a declared number to a counted one cannot fire and are deleted.
2. **Claim** — unchanged: the lint lines as warnings; an old item is sized by writing its file, not by
   a comment.
3. **Before review** — a computation with a new input: `tracker.sh size <n>` counts the branch's diff
   against `files`, prints the undeclared paths, and decides; the gate repeats the same check so a
   change that reaches the gate without passing through `work` meets it there. The lead's procedure in
   `work` step 4 — two PRs by path, or the exception retroactively with the summary saying so — stands;
   only its arithmetic moved into a command.

The `Split line:`/`Exception:` pair stops being one line replaced by the other. The split is prose in
the body (D1); the exception is a one-line licence in the file, and `## Done when` still names the
search that returns nothing afterwards, as `agents/architect.md` requires.

*Forecloses:* a `Size:` line anywhere; a before-review count done by hand.

## §8 — What is superseded

| 0.6.0 | 0.7.0 |
|---|---|
| D2's two load-bearing lines | one: the story's `## Tasks` is last; the task's first line is retired (D1, D10) |
| D4 first-line contract | retired for items with a file; `legacy:` for 0.7.x; gone in 0.8.0 (D12) |
| D5 task checks — `Size:` regex, bullets = H, `## Proves` grep, header presence | retired for items with a file; the file's `jq` validator replaces them (D3, D9) |
| D9 `Size:` line and `Exception:` line | computed H/G; `exception` key (D1, D13) |
| D11's foreclosure of a file count in a project gate | superseded: the valve is in data (D7) |
| `task_create` appending the story checklist | retired on github (D6) |
| `--story --role --blocked-by` on `task create` | retired; `--data-file` (D5) |
| `status`/`next` prose matches | fallbacks for 0.7.x only (D12) |

## §9 — What this design does not improve

It makes shape deterministic and counts honest. It does not make a TL;DR clear, a criterion one
outcome, or a task well-cut: those are still the technical-writer's question in refine step 2, the
owning role's "can you start from this without a conversation" in plan step 3, and the lead reading
every TL;DR cold. Nor does it make a file list **complete** at plan time — `files` is still a
prediction written before the code is open, as `agents/architect.md` says; what changes is that the
prediction meets the diff in a command and a gate instead of in a lead's memory, and its growth is a
hunk a reviewer reads.

## Deliberately not done

- A computed Proof map: with `proves` in data, the story's Task column is one `jq` walk over
  `.claude/crew/items/`, and a lint line for a row that disagrees with the files is cheap. Not in
  0.7.0: the story body is untouched by this design, and the map's other two columns are prose by
  D20/D21. It is the next item, and this design makes it a computation rather than a design.
- A file for stories and tech-debt items (D1).
- A comment on the issue carrying a link to the file: the number is the path.
- The consuming project's own documents (`docs/agents/delivery.md`'s four templates, its issue
  format): its conform pass changes them, not this plugin.
- An Azure DevOps or Jira adapter: the schema is ready for one (string ids, no sigil, relations behind
  `sync`), and `tracker.sh` still exits 2 for the backend it does not have.
- A rendered validator in a project (D7).

## Risks

- The file list leaves the issue page: a reader on the tracker no longer sees the paths a task will
  touch without opening the repository. The PR carries them; the trade is deliberate.
- A task is claimable only once its plan's change has merged (D4). On a project whose designs are
  merged by one person, plan-to-work has a wait it did not have; the practice already exists there.
- `lint` on a github tracker adds no calls (`parent`, `blockedBy` and `labels` come back in the list
  call it already makes); `sync --all` is one `issue edit` per item and is run by hand.
- The `## Split line` section is required text, and "n/a — the cap holds with room" will be most of
  it; the alternative — a header line — is what #4 lost.
- `legacy:` lines make `lint --all` red on every un-migrated board until #7's pass runs; the count
  says how many, and `/crew:status` already reports the number rather than the colour.

## Question map — the brief's ten questions

| Q | Decision |
|---|---|
| 1 identity before the number | D5: validate → create → `mv` to `<n>.json`; a failed step 3 is printed with its one repair and never repeated as a create |
| 2 who writes and who edits | D5: `plan` writes, the adapter names, the lead and the owning role edit in the repository, `sync` projects |
| 3 drift and the verdict | D8: `tracker.sh lint` compares, the file is the record, `tracker.sh sync <n>` repairs |
| 4 what `lint` becomes | D8, D9: file schema + cross-check + the body's structural checks; `legacy:` for the rest |
| 5 a pointer in the body | D10: none |
| 6 schema versioning | D11: integer, newer refused, older read and migrated by `/crew:conform` |
| 7 a repository that never adopts | D12: the table; fallbacks for 0.7.x, loud `unlinked` from 0.8.0 |
| 8 the three moments | D13: create and before-review are computations; claim unchanged |
| 9 what is superseded | §8 |
| 10 what does not improve | §9 |
