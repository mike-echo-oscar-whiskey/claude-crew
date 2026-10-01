# ♻️ refactor(crew): the backlog is authored as data in the repository, and every item's body on the tracker is rendered from it

Architect, 2026-09-30; amended 2026-10-01 for four decisions Kris took that day (§10), and
re-ruled later that day on the data format after he lifted a constraint D16 and D17 had leaned on
(§11 — the shape did not change). Status:
**proposed** — design only; no release is reserved for it, and the task list is not part of this
document (it is registered on the tracker once approved). Sections are numbered §1–§11 so tasks can
cite them; the ten questions the brief put, and the decisions of 2026-10-01, are mapped to
decisions at the end. The file was `item-data.md` until 2026-10-01: that name described stripping
bodies, which §10 reverses, and its owner did not recognise it as his own idea.

Every `tracker.sh` citation below names a function or an expression inside one, never a line.
Line numbers were tried and rotted twice in two commits (#38 found all eight wrong and re-derived
them; the next commit, `f6b898d`, moved every one below `body_placeholders` again), and one quoted
expression had been wrong at the derivation point itself. A name either resolves with `grep -n` or
visibly does not, which a stale number never admits. The names were last checked against
`plugins/crew/scripts/tracker.sh` at `f6b898d` (`0.8.0`) on 2026-10-01; when one stops resolving,
`git log -S<name> f6b898d..` finds the rename. D14 was added the same day, for the reason it states.

## Problem

Four things went wrong under 0.6.0, all countable, all in this repository's own history or the
consuming project's board.

- **A task lost its own story.** Task #4's body was rewritten by an agent during its round and came
  back without its `Story: #1` and `Blocked by: #3` lines. The board rolls a task up under its story by
  `select(.body | startswith($s))` with `--arg s "Story: #$sn"` (`status()` in
  `plugins/crew/scripts/tracker.sh`) and lists it as claimable by the same first-line parse
  (`story_of_body`, called by `next()`), so the
  task that existed to make that first line a checked contract was, for a while, invisible to the story
  it belonged to.
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
  (`tracker.sh`) reads `Size:` with a five-clause regular expression over a prose line (its
  `[[ $size =~ … ]]` test), counts files by counting Markdown bullets under a heading
  (`files_hand_written`), checks the story reference by comparing the first line with
  `Story: $SIGIL$num` (its `head -1`; `lint_body` reads the number back out of that same line with
  `story_of_body`), and finds blockers with `grep -oE '#[0-9]+'` over a `Blocked by:` line
  (`blockers_open`). Every one of those is a fact — a number, a reference, a list of paths — stored as a
  sentence, and every check is a comparison between two sentences that must agree.

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

The inversion this design works out **is** "render the body from the data" — Kris, 2026-10-01,
reversing what this paragraph said until then (D15). The record of an item is two files in the
repository, data and prose; the body on the tracker is output, rendered by the adapter, and nothing
reads a body to decide anything. The earlier text here foreclosed a renderer so that "nothing ever
overwrites prose a person edited on the tracker"; that protection is given up knowingly, and D15
says what a person does instead. Multi-line prose still never sits inside JSON (D17).

Constraints that bind every decision below: `jq` and `python3` (3.9 or later, standard library
only — D16) are the only data dependencies a consumer has, and `jq` is on every profile's `gates:`
line already (since 2026-10-01 this is a choice, not a constraint: Kris permitted a `yq`
dependency, and D20 keeps `jq` and `python3` alone on the merits); boards filed under 0.6.0 keep
working unchanged; there is no CI, so a consumer's
`scripts/local-gates.sh` and the plugin's own commands are the only enforcement points;
`tracker.sh` stays the adapter boundary and the schema encodes nothing GitHub-shaped.

## §1 — What leaves the body and what stays

### D1 — Seven facts move to the data file; five sections of prose remain

Today's task body carries, in prose clothing: `Story: #n`, `Blocked by:`, `Role:` with its
`design:` pointer, `Size: <H> … <T> …`, `Split line:`/`Exception:`, a `## Proves` list of criterion
references and a `## Files` bullet list. The data file instead carries the title, the story, the
role, the blockers, the design pointer, the criteria proved, the file list and the exception licence.
The prose file (D17) keeps `## TL;DR`, `## In one paragraph`, `## Goal`, `## Tests (RED first)` and
`## Done when`, and gains one prose section, `## Split line`, because the seam a task is cut at is a
sentence about the work and belongs with the other sentences — #7's and #8's split lines run four
lines each and would have been the multi-line prose this design keeps out of JSON. The body on the
tracker is rendered from both (D15): its header lines, `## Files` and `## Proves` are output the
adapter derives from the data, and no program reads them back.

Two numbers of the old `Size:` line are computed, never declared. H is the length of `files` minus the
entries matching the profile's `generated:` globs, G is those entries — one `jq` read and the same
glob match `files_hand_written` does today. T, the count of numbered RED tests, stays a property of the
body: the tests are prose the body keeps, and counting `^[0-9]+\.` under one heading is Markdown
structure, not a data format in English. T is therefore not in the file, and the rule "T = 0 only when
the section says the task is test-free" stays a body check.

Bugs get the same file as tasks, because a bug carries a `Size:` line and a `## Files` list too
(`templates/item-bug.md`): leaving bugs on prose would keep the `Size:` regex alive for one kind.
Stories and tech-debt items were to get no file because nothing in them was countable; D19
reverses that — every kind has a file, a story's criterion ids are data, and the reason is
uniformity by construction rather than countability.

*Forecloses:* a body a person writes on the tracker; a `Size:` that a person types; a fact a
program reads from a body; a kind without a file. (Until 2026-10-01 this list opened with "a body
rendered from the file"; D15 reverses it.)

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

*Amended 2026-10-01 (D17):* the directory is `.claude/crew/backlog/`, not `items/`, and an item is
two files, `<id>.json` and `<id>.md`. The id-as-file-name rule and the string id stand.

### D14 — A bug's role leaves its first line for the file; a tech-debt item changes in nothing

*Added 2026-10-01, and the only decision added after the two reviews.* `0.7.0` shipped
`tracker.sh bug create` and `tech-debt create` after this document was written, so the two plain kinds
acquired a create contract D1 and D10 had assumed they were simply replacing. §8 listed `0.6.0`
decisions only and therefore retired nothing for them; that is what this decision answers.

A bug's role is the body's first line today (`templates/item-bug.md`: ``Role: `<crew role>` · design:
… · found …``), and nothing reads it. `validate_plain_body` (`tracker.sh`) judges template
sections and surviving placeholders and has no header contract at all; the role token sits inside
backticks, and the placeholder scan unwraps a span holding nothing but a stub, so that token refuses
the line unfilled in its own right (`body_placeholders`, whose span scan unwraps a span holding nothing
but stubs rather than dropping it). Until #41 it did not: the scan stripped the span before it looked, and the
neighbouring `<none, or the doc>` and `<where and when>` were what refused that line.
`plain_create` takes no `--role`, and the adapter puts no `role:<r>` label on a bug, on
the stated ground that a flag would write "a second copy of a fact the body states, with nothing
holding the two equal".

Under this design a bug's role is in the file exactly as a task's is (D1), its body starts at
`## TL;DR` with no header lines (D1, D10), and the adapter writes the `role:<r>` label from the file
at create as it does for a task (D5). That answers `0.7.0`'s reason rather than overruling it: the
flag was refused for want of a comparator, and the comparator now exists — `lint` reports label
against file and `sync` repairs the label from the file (D8), so the second copy is held equal by the
same machinery that holds `story` and `blockedBy` equal. `bug create` gains `--data-file` on the terms
D12's table already states, and a bug with a file is judged as D9 says.

A tech-debt item changes in nothing, and that is the second half of the answer. It names no role,
carries no `Size:` line and no `## Files` list, gets no data file (D1), and its first line
(`Found in: … · pre-existing since …`) is prose a person reads rather than a fact a program parses —
so there is nothing in it for D10 to retire. `validate_plain_body` keeps its no-header shape for that
kind. The design covers tasks, stories and bugs; `tech-debt` is the one kind it leaves alone entirely.

This corrects a reason in D1 and not its decision. "Leaving bugs on prose would keep the `Size:` regex
alive for one kind" reads as though a bug's `Size:` line is parsed today; no arm of
`validate_plain_body` reads it. What leaving bugs on prose really keeps alive is a number a person
types that nothing ever checks — the same defect one degree worse, so the decision stands.

*Forecloses:* a `--role` flag on `bug create`; a bug whose role stays on a header line while its other
facts move to the file; a separate validator shape for a bug with a file; a `role:<r>` label written
on a bug by anything but the adapter from the file. (Until 2026-10-01 this list also foreclosed a
data file for a tech-debt item; D19 reverses that one point — the kind gets a file for uniformity,
carrying `foundIn` and `since` and nothing else beyond `schema`, `kind` and `title` — and the rest
of this decision stands.)

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
the schema; the table above is its prose; `tests/tracker.test.sh` holds the two together.

*Forecloses:* an open key set; a note that runs to a second line. (Until 2026-10-01 this list also
foreclosed a JSON Schema file and a `python3` dependency; D16 reverses both and keeps `ajv` and
`yq` foreclosed.)

*Amended 2026-10-01 (D16, D17, D19):* the `jq` program and the table above are retired as the
schema; `plugins/crew/schema/item.schema.json` is the one authority and the example above is read
against it. The key set grows by `title` (D17) and, per kind, by a story's `criteria` and a
tech-debt item's `foundIn` and `since` (D19); `proves[]` gains an optional `by` (D15). The closed
key set and the "every failing check at once" form stand.

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
`.claude/crew/backlog/<n>.json` on `<default-branch>`: the plan's change is not merged, or this item
predates the data file — `/crew:conform` brings it over". A task is claimable once its plan has
landed, which is what the consuming project already does by practice (design PR #655 merged before
#656 started).

*Forecloses:* a board that depends on a checkout; a typed field written by anything but the adapter;
a schema field that names a backend.

### D5 — The plan writes the file, the adapter names it, and the file travels with the design

`plan` step 5 writes, per task, a data file and a body to temp paths and runs `tracker.sh task create
--title "<t>" --data-file <d.json> --body-file <b.md>`. The `--story`, `--role` and `--blocked-by`
flags retire: they are in the data. The adapter, in this order:

1. validates the data (D3) and the body (D9) — exit 1 with every refusal, no tracker call;
2. creates the issue with the kind label, the `role:<r>` label and, for a github tracker, `--parent`
   and `--blocked-by` from the data — this is where the number is born;
3. moves the validated temp file to `.claude/crew/backlog/<n>.json` — a rename inside one filesystem,
   the smallest step that can fail;
4. prints the number.

If step 2 fails there is nothing to undo. If step 3 fails the issue exists and the file does not: the
adapter exits 1 and prints the number, the temp path and the one command that finishes it
(`mv <tmp> .claude/crew/backlog/<n>.json`); from then on `lint` reports `#n has no data file`, `work`
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
`--story`/`--role`/`--blocked-by`/`--title`/`--body-file` flag on `create`; a file edited by a
script other than through `mv` at create.

*Amended 2026-10-01 (D15, D17):* `create` takes `--data <d.json> --prose <d.md>` and no body; the
title is in the data. Step 1 validates both files (D16), step 2 renders the body from them (D15)
and creates the issue with it, step 3 moves both files to `backlog/<n>.json` and `<n>.md`. The
recovery for a failed step 3 is the same, for two files. `story create` and `tech-debt create` take
the same two flags (D19).

### D6 — The adapter stops appending the `## Tasks` checklist to a story on a backend that renders sub-issues

`task_create()` today reads the story body, appends `- [ ] #n (role) title` under `## Tasks` and
writes the **whole body back** (the `# append to the story's task checklist` block that closes
`task_create()`: `issue view --json body`, then `issue edit --body`). That is a body rewrite of a document a person
may be editing on the tracker at that moment, and the one place in the adapter where the prose-clobber
this design exists to end is built in. With `parent` set (D4), GitHub renders the sub-issue list and
its progress on the story itself, so the checklist is a third copy of a fact the tracker now holds
twice. Under this design the github adapter does not write it. `## Tasks` stays the last section of
the story template — a project override may want it, and the on-board validator already accepts it
empty (`check_sections` exempt heading) — and the template comment says the adapter no longer fills
it.

*Forecloses:* a template contract that names the checklist as the rollup. (Until 2026-10-01 this
list also foreclosed an adapter write to a story body after creation; D15 reverses it: the adapter
writes a story's body whenever it re-renders it — at `task create`, at `sync` — from the record,
never from the tracker. The checklist append from the tracker's own copy stays retired; `## Tasks`
is now rendered from the task files that name the story.)

## §4 — Enforcement: what refuses, where

### D7 — Four moments enforce the file; the consumer's gate holds the one check only it can make

| Moment | Who | Checks | On failure |
|---|---|---|---|
| create | `tracker.sh <kind> create` | D16 schema over the data file; H ≤ `size-cap:` unless `exception`; `design.path` exists; every `proves` criterion exists in the story's data file (`criteria[].id`, no tracker call — D19); prose file per D9 | refused, nothing created |
| claim | `tracker.sh claim` | the same, read-only, printed as `warning:` lines; an item with no file prints one warning line and is claimed (D7 of 0.6.0 stands) | never refused |
| before review | `tracker.sh size <n>` in `work` step 4 | H, G, and the branch's `git diff --name-only <base>...HEAD` minus `generated:` minus `.claude/crew/backlog/*.json`, listing every path the diff touches that `files` does not name; exit 1 when the list is non-empty or H > cap without `exception` | the review does not open; the role adds the paths to `files` in the same change, or the lead briefs an architect for the split, as D11 of 0.6.0 says |
| gate | the consumer's `gates:` command | `jq empty` over `backlog/*.json`; on a branch matching `branch-pattern`, the same diff-versus-`files` check and the cap; optionally a real JSON Schema validator over the schema file, if the project has one (D16) | red |

The gate row is honest about what a project gate can and cannot do. It cannot call the plugin: the
installed copy lives at a versioned path (`~/.claude/plugins/cache/claude-crew/crew/<version>/`), there
is no stable link, and a Codex install has no equivalent — so a `gates:` line naming `tracker.sh` rots
on the next upgrade. It can do everything that needs `jq` and `git` alone, and that is the check that
matters most: the diff is a subset of the declared list, and the count is under the cap. Ten lines
the design fixes once, so a project copies the contract rather than the validator:

```bash
n=$(git rev-parse --abbrev-ref HEAD | sed -nE 's#^task/([^-]+)-.*#\1#p')   # the profile's branch-pattern
f=.claude/crew/backlog/$n.json
if [ -n "$n" ] && [ -f "$f" ]; then
  cap=$(sed -nE 's/^size-cap:[[:space:]]*([^[:space:]#]+).*/\1/p' .claude/crew/profile.md); cap=${cap:-15}
  declared=$(jq -r '.files[].path' "$f" | sort)
  touched=$(git diff --name-only "$(git merge-base origin/master HEAD)"...HEAD | grep -v '^\.claude/crew/backlog/' | sort)
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
              jq '.blockedBy += ["9"]' .claude/crew/backlog/12.json  then  tracker.sh sync 12
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

*Amended 2026-10-01 (D15, D19):* `lint` adds a fourth comparison, the tracker body against a fresh
render (`stale render`, diff on request), and a fifth, the title; `sync` writes the title and the
body too, so "never touches a body" no longer holds — it writes the body from the record and prints
what it overwrote. "The file is the record" now reads "the files are the record" and is the whole
reason a web edit is discarded rather than merged.

### D9 — What `lint` judges in a body under this design, and what it stops judging

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

*Amended 2026-10-01 (D15, D16):* every check this decision lists runs over the **prose file**, never
over the tracker body, and the heading set is closed both ways — a data heading in the prose file is
refused, and so is a heading the template does not name. The tracker body gets exactly one check:
it equals the render (D8). The `legacy:` validator for an item without files is unchanged.

## §5 — The body keeps no pointer

### D10 — No machine-readable line survives in a body, not even a pointer to the file

The mapping from item to file is the number, which the tracker shows on every page and every list, and
`.claude/crew/backlog/` is one directory. A pointer line would be the one line `lint` would have to grep
for, and one line an edit could drop — the class this design retires. Nothing reads a body for a
fact, so nothing is written there for a reader to find. A reader on the tracker's web page who wants
the file list opens the PR that carries it; the review reads it in the diff; the role gets it in its
brief, because `work` step 3 hands the file over beside the body.

The presence of a file is also the per-item adoption signal (§6): no key in the profile, no line in
the body.

*Forecloses:* a comment carrying a copy of the file; a profile key that says a project adopted.
(Until 2026-10-01 this list opened with "a `Data:` line"; D15 supersedes it with a rendered footer
naming `backlog/<id>` — output, read back by nothing, so the reason given above, "the one line
`lint` would have to grep for", no longer applies. The adoption signal stays the presence of the
files.)

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

Under this design, with no file in the repository:

| Behaviour | Still works | Degrades |
|---|---|---|
| `status`, `next`, `claim`, `release`, `show`, `comment` on items filed under 0.6.0 | yes — `status` falls back to the first-line match and `next` to the `Story:`/`Blocked by:` grep when `parent`/`blockedBy` are null | |
| `lint --all` | yes; old tasks are reported `legacy:` with the 0.6.0 checks | the count says how many items have no file |
| `story create` | unchanged | |
| `task create`, `bug create` | | require `--data-file`: the first new item is the moment a project adopts, and the cost is a directory |
| `tracker.sh size`, the diff check, `sync` | | not available for an item without a file — `size` says so and exits 1 |
| `work` step 1 | | stops on an item without a file and names `/crew:conform` |

The prose fallbacks in `status` and `next` and the `legacy:` validator are kept for one minor release
— the one that delivers this design — and removed in the next, which is at least one release after
`/crew:conform` (#7) can bring a board over in one pass. Once they are gone an item with no file is
not invisible: `status` lists it under an `unlinked` heading of its own and `next` prints it with
`story ?` and no blocker check — loud, not absent. The consuming
project's 209 tasks and this repository's own ten are brought over by that one pass; #7 gains one
step, "write the data file from the body's header lines and `## Files`, and set the typed fields", and
the pass is the only time a program writes a file from prose.

*Forecloses:* a fallback that outlives that one minor release; an unfiled item that is silently
absent once they are gone; a migration by a script that is not shown to the user.

*Amended 2026-10-01 (D15):* the table and the window survive rendering. A board that never adopts
has no files, so there is nothing to render and nothing is rendered: the prose fallbacks in
`status()` (`startswith($s)` on `Story: #`) and `next()` (`story_of_body`, `blockers_open`) carry
its 0.6.0 items for the one minor release exactly as above, and after it they are `unlinked`, loud
and never rendered over. What changes is the adoption pass, because an item without files cannot be
brought over by writing one file from its header lines: `/crew:conform` becomes the importer.
`backlog.py import <kind> <body>` drafts `<n>.json` and `<n>.md` from the body's header lines,
`## Files`, `## Proves` and sections — still the only time a program writes files from prose — the
lead shows both files and the render against the current body as a diff per item, and on approval
commits the files and runs `sync <n>`, whose first write replaces the hand-written body with the
render. The rule "nothing on the board is edited before the diff is shown and approved" holds for
that first write; every later `sync` of that item is a projection and asks nothing (D18).

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

| 0.6.0 | Under this design |
|---|---|
| D2's two load-bearing lines | one: the story's `## Tasks` is last; the task's first line is retired (D1, D10) |
| D4 first-line contract | retired for items with a file; `legacy:` for one minor release; gone in the next (D12) |
| D5 task checks — `Size:` regex, bullets = H, `## Proves` grep, header presence | retired for items with a file; the file's `jq` validator replaces them (D3, D9) |
| D9 `Size:` line and `Exception:` line | computed H/G; `exception` key (D1, D13) |
| D11's foreclosure of a file count in a project gate | superseded: the valve is in data (D7) |
| `task_create` appending the story checklist | retired on github (D6) |
| `--story --role --blocked-by` on `task create` | retired; `--data-file` (D5) |
| `status`/`next` prose matches | fallbacks for one minor release only (D12) |

`0.7.0` landed after this document was written and set two contracts of its own for the plain kinds.
They are answered in D14, which also records that `tech-debt` is superseded in nothing.

| 0.7.0 | Under this design |
|---|---|
| `item-bug.md`'s first line carrying the role, held only by its neighbouring placeholders | retired for a bug with a file: the role is in the data and the header line is rendered from it (D1, D14, D15) |
| `bug create` takes no `--role`, and no `role:<r>` label reaches a bug | `--data --prose`, and the adapter writes the label from the file as it does for a task (D5, D8, D14) |

Four decisions of 2026-10-01 (§10) supersede parts of this document's own 2026-09-30 decisions.
The earlier text is amended in place where it would mislead, with a dated note; nothing is
renumbered.

| 2026-09-30 | Under §10 |
|---|---|
| Why: "the inversion is **not** render the body from the data" | reversed: the body is rendered output (D15) |
| D1's first foreclosure, "a body rendered from the file" | reversed (D15) |
| D1: no file for a story or a tech-debt item | every kind has a file (D19) |
| D2: `.claude/crew/items/<id>.json`, one file | `.claude/crew/backlog/<id>.json` + `<id>.md` (D17) |
| D3: the `jq` program is the schema, the table its prose, no schema file, no `python3` | a JSON Schema file read by the plugin's own stdlib Python validator (D16) |
| D5: `--data-file --body-file`, `--title` | `--data --prose`; the title is data (D15, D17) |
| D6: no adapter write to a story body after creation | the adapter re-renders a story at `task create` and `sync` (D15) |
| D7's create-time `proves` check by one `issue view` | from the story's data file, no tracker call (D19) |
| D8: `sync` "never touches a body" | `sync` writes the body from the record and prints what it overwrote (D15) |
| D9's body checks | the same checks over the prose file; the body gets one check, equality with the render (D15, D16) |
| D10: no pointer line in a body | a rendered footer naming `backlog/<id>`, output only (D15) |
| D12's adoption moment, "write the data file from the body's header lines" | `/crew:conform` imports two files and the first `sync` replaces the body, shown and approved per item (D15) |
| D14: a tech-debt item changes in nothing | it gets a file carrying `foundIn` and `since` (D19) |
| "Deliberately not done": a computed Proof map | rendered from `criteria` and the tasks' `proves` (D15, D19) |

Later on 2026-10-01 Kris lifted the constraint D16 and D17 had partly rested on — a `yq`
dependency is permitted. §11 re-rules the format with it lifted; no decision's substance moves,
two decisions' grounds do.

| 2026-10-01, under the dependency constraint | Under §11 |
|---|---|
| D17's criterion "what is on the machine", and "`pyyaml` is the dependency D16 refuses" as the reason YAML is out | withdrawn as grounds; JSON and two files stand on D20's three reasons |
| D16's install-failure ground for foreclosing `yq` | withdrawn by Kris; `yq` stays out because it has no job and names two programs (D20); the stdlib rule for Python stands on its own ground |
| the "Constraints that bind" paragraph: `jq` and `python3` as the only data dependencies | a choice, not a constraint (D20) |

## §9 — What this design does not improve

It makes shape deterministic and counts honest. It does not make a TL;DR clear, a criterion one
outcome, or a task well-cut: those are still the technical-writer's question in refine step 2, the
owning role's "can you start from this without a conversation" in plan step 3, and the lead reading
every TL;DR cold. Nor does it make a file list **complete** at plan time — `files` is still a
prediction written before the code is open, as `agents/architect.md` says; what changes is that the
prediction meets the diff in a command and a gate instead of in a lead's memory, and its growth is a
hunk a reviewer reads.

## Deliberately not done

- A template language. A template renders nothing but its headings (D15); loops, conditionals and
  substitution tokens in a Markdown template would be a second program a project override could
  break, and the data sections they would express are the adapter's.
- A declared Python dependency, a venv, or a YAML/JSON-Schema library (D16); `ajv`; `yq` — since
  2026-10-01 not because it is a dependency, which Kris permitted, but because the format gives it
  no job and the name is two programs (D20).
- Conflict detection beyond the diff: `lint` shows that the page differs from the render and
  `sync` prints what it overwrote; neither keeps a last-rendered copy or a timestamp (D8).
- A comment on the issue carrying a link to the file: the number is the path, and the footer says so.
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
- A web-page edit is discarded at the next `sync` (D15). It is never discarded unseen — `lint`
  shows the diff and `sync` prints it — but a person who edits the page and never runs `lint` loses
  the edit at someone else's `sync --all`. The footer on every body is the mitigation.
- `sync` projects the checkout it runs in. `work` step 6 runs it from a task branch, so the tracker
  shows that branch's files until the PR merges; if the PR is rejected, the next `sync` from the
  default branch restores the body. The default branch is the record of record; `lint` there is the
  truth.
- `python3` becomes a runtime dependency (D16). The failure is one line at the top of `tracker.sh`,
  before any command, on a machine without it; nothing works partially.
- A story's render depends on other files (D15): adding a task makes the story stale until
  `task create` re-renders it, which it does in the same run; a hand-written task file makes it
  stale until `sync`.

## Question map — the brief's ten questions

| Q | Decision |
|---|---|
| 1 identity before the number | D5: validate → create → `mv` to `<n>.json`; a failed step 3 is printed with its one repair and never repeated as a create |
| 2 who writes and who edits | D5: `plan` writes, the adapter names, the lead and the owning role edit in the repository, `sync` projects |
| 3 drift and the verdict | D8: `tracker.sh lint` compares, the file is the record, `tracker.sh sync <n>` repairs |
| 4 what `lint` becomes | D8, D9: file schema + cross-check + the body's structural checks; `legacy:` for the rest |
| 5 a pointer in the body | D10: none |
| 6 schema versioning | D11: integer, newer refused, older read and migrated by `/crew:conform` |
| 7 a repository that never adopts | D12: the table; fallbacks for one minor release, loud `unlinked` after it |
| 8 the three moments | D13: create and before-review are computations; claim unchanged |
| 9 what is superseded | §8 |
| 10 what does not improve | §9 |

| Kris, 2026-10-01 | Decision |
|---|---|
| 1 render the body from the data | D15, reversing the Why section and D1's first foreclosure; D18 for the template |
| 2 a schema artefact, not a hand-coded validator | D16: a JSON Schema file, the plugin's stdlib Python validator, a stated subset enforced by refusal |
| 3 the format is not the decision | D17: JSON data, a sibling Markdown prose file, under `backlog/` |
| 4 agents keeping a backlog true | D19: the three-command loop, a file for every kind, a total projection |
| the lead's gap: the template is code | D18: versioned by the release; re-render in bulk; a heading change migrates through `/crew:conform` |
| the lead's question: does D12 survive | yes, amended: `/crew:conform` imports, the first `sync` replaces the body with approval |
| later that day: "it is okay if the plugin has a dependency on yq" | D20: re-ruled on the merits — JSON and two files stand, `yq` gets no job, no task changes shape |

## §10 — The body is rendered output, the schema is a file, and agents keep the backlog true (Kris, 2026-10-01)

Four decisions Kris took on 2026-10-01, after the two reviews, and one gap the lead raised. One of
them reverses what the Why section and D1 stated twice. D14's convention holds: the earlier text is
amended in place where it would mislead, each amendment dated, and the decisions are appended,
never renumbered.

### D15 — The record is two files; the tracker body is rendered from them and is never the record

Kris: "templates plus data make every artefact look the same by construction, and validation
becomes trivial." An item is **authored** as a data file and a prose file in the repository (D17);
the body on the tracker is **output**. `tracker.sh render <id>` prints it, `create` writes it, `sync`
rewrites it, `lint` compares the tracker's copy to a fresh render. A person reads it on the
tracker; a program reads it nowhere.

What that buys, and why the earlier foreclosure falls: nothing is ever scanned to decide whether an
item is valid. The validator judges the files (D16); the body is compared whole to a render, as
bytes, and is either current or stale — there is no third state in which a `Size:` regular
expression, a bullet count or a first-line match decides anything. The defect family of 2026-10-01
— a comment and a scanner disagreeing, a changelog and a function disagreeing, a Proof map grading
a tree that had moved — is the family of two hand-kept copies of one fact. A rendered body is not a
copy; it is a projection, and a projection can be stale but cannot disagree.

The cost, accepted knowingly: **an edit made to a body on the tracker's web page is overwritten at
the next `sync`.** Items #19 and #37 of this repository had their criteria amended on the page
after filing; that workflow is given up. What a person does instead: edit the file —
`.claude/crew/backlog/<id>.json` for a criterion, a blocker, a role, a file list; `<id>.md` for a
paragraph — on a branch under the project's git rules, and run `tracker.sh sync <id>`. The edit
becomes a diff a reviewer reads, which is the reason D5 gave for file lists. Two guards keep the
loss from being silent: `lint <id> --diff` prints the tracker body against the render as a unified
diff whenever they differ, under the line "the files are the record; carry this into `<path>` or
`sync` discards it", and `sync` prints what it overwrote on stderr before it writes. `sync` never
asks — a bulk pass must not stop per item (D19) — and never refuses: a body is not evidence against
the files.

What renders, by kind. The body is: a header block the adapter derives from the data (task:
`Story: #2 · Role: … · Blocked by: #6 · Size: 9 hand-written files (+0 generated) · 3 RED tests`,
where T is counted in the prose file's `## Tests (RED first)` as D1 says; bug: `Role: … · design: …
· found …`; tech-debt: `Found in: … · pre-existing since …`; story: none), then the template's
`## ` headings in template order, each filled either from the data — `## Files`, `## Proves`,
`## Acceptance criteria`, `## Proof map`, `## Tasks`, the five **data headings**, a closed set the
adapter owns — or from the prose file's section of the same name (every other heading), then one
footer line, *Rendered by crew from `.claude/crew/backlog/<id>` — edit the files, not this page.
Common definition of done: … Merged by …*, with the profile keys substituted. The footer is output
and is read back by nothing; it exists so the person about to edit the page learns where the edit
goes. That supersedes D10's foreclosure of a pointer line, whose reason — the one line `lint` would
have to grep for — is void when `lint` greps nothing.

**A template renders nothing but its headings.** Everything else in `item-<kind>.md` — the stubs,
the guidance, the leading comment — instructs the author of the prose file and never reaches a
body; the header, the data sections and the footer are the adapter's, as 0.6.0 D2 already said of
the four load-bearing lines ("it decides the sections, not these four lines"). A project override at
`.claude/crew/items/<kind>.md` therefore chooses and orders headings and writes guidance, and cannot
change how a fact renders. That is what keeps "the template is code" small (D18).

A story's body renders from more than its own files: `## Tasks` and the Proof map's Task and
Proven-by columns come from a walk over `backlog/*.json` for the tasks whose `story` is this id and
their `proves` entries — `proves[].by`, filled by the owning role in its own change, is 0.6.0 D21's
"the test that DID". `task create` therefore re-renders its story after creating the task, which
replaces D6's checklist append with the one write D6 objected to — a whole-body write — now
legitimate because the body is output and the record is untouched. The computed Proof map leaves
"Deliberately not done" — and gains the one check a computed map needs: `lint` reports a closed task
whose `proves[].by` is still empty, because a criterion proven by nothing named is the hand-kept
map's rot in a new coat.

Line endings: a body saved from the web page comes back with `\r\n`; `lint` compares after dropping
`\r` and trailing whitespace, and `sync` writes `\n`. Stated because an agent comparing bytes would
otherwise report every web-touched item stale forever.

*Forecloses:* a body a person writes on the tracker; a fact a program reads from a body; a template
that renders text of its own; a `sync` that asks per item; a `sync` that refuses because the page
differs; a render that depends on the tracker (the files and the profile are its only inputs).

### D16 — The schema is a JSON Schema file, and the validator is the plugin's own standard-library Python, which refuses any keyword it does not implement

Kris: "whatever data format we use on disk, a schema would be very useful as it could be used to
validate the data on disk." D3 made the `jq` program the schema and a table its prose — two things
that must agree, the defect family again. Under this decision the shape is one artefact,
`plugins/crew/schema/item.schema.json`, a JSON Schema in the draft 2020-12 vocabulary with one
`$defs` entry per kind; the data file's `kind` selects which `$defs/<kind>` it is judged against.
The schema is the documentation; D3's table is retired.

The lead put three validation shapes while the runtime was bound to `jq`, `sed`, `awk` and `gh`;
Kris then lifted that: "it does not have to be bash right, it could be python or anything else
running on linux." The ruling takes the lifting: **validation and rendering are Python 3, standard
library only, in `plugins/crew/scripts/backlog.py`; the tracker adapter stays bash.** Why Python and
not a fifty-line `jq` interpreter: a schema interpreter in `jq` is hand-rolled text processing in
the language this repository rewrote one scanner in three times today (`body_placeholders`, #41,
#42, `ec352d0`), and would be the incomplete validator that claims completeness. Why standard
library only, and not `jsonschema`, `jinja2` or `pyyaml`: the plugin is cloned into other people's
repositories, so an install failure lands on them. A declared dependency fails on a machine without
`pip`; on every current Debian, Ubuntu and Arch under PEP 668, whose `externally-managed-environment`
refuses `pip install` outright; and on Debian without `python3-venv`; a venv per plugin-cache
version would have to be created on first run under a path the plugin does not own, and a Codex
install has no hook to do it in. A stdlib-only script has one failure mode: no `python3`.
`tracker.sh` checks for it beside `gh` and `jq` — `command -v python3`, floor 3.9, which is what
macOS's command-line tools and Ubuntu 22.04 ship — and exits 1 before any command with the one
install line per platform; nothing works partially without it. Why the adapter stays bash: the `gh`
plumbing (`lint`'s one list per kind, `claim`, `release`, `next`, `status`) is witnessed and is not
where today's defects were; the two jobs that need a real language get one, and `backlog.py` never
calls `gh` or `git` — its inputs are files and the profile, its outputs are text and an exit code.

The validator implements a **stated subset** and refuses the schema itself when it meets a keyword
outside it: completeness is guaranteed by refusal, not by claim, so a `oneOf` added to the schema
cannot go silently unchecked. In: `$schema`, `$defs`, `$ref` (to `#/$defs/<name>` only), `title`,
`description`, `type` (`object`, `array`, `string`, `integer`, `boolean`), `properties`, `required`,
`additionalProperties` (must be `false` on every object schema; one that omits it is refused,
because an open object is the typo-swallowing shape D3 refused), `items` (one schema), `enum`,
`const`, `minItems`, `maxItems`, `uniqueItems`, `minLength`, `maxLength`, `pattern`, `minimum`,
`maximum`. Out, deliberately: `if`/`then`/`else`, `oneOf`/`anyOf`/`allOf`/`not`,
`dependentRequired`, `format`, `patternProperties`, `unevaluatedProperties`, `$dynamicRef`, a
remote `$ref`. Every per-kind difference is expressed by selecting `$defs/<kind>`, never by a
conditional. Because the file is a valid draft-2020-12 document within that subset, a project that
has a real validator (`check-jsonschema`, `ajv`) may run it over `.claude/crew/backlog/*.json` in
its own gate; the plugin never requires one, and a witness in this repository holds the schema to
the subset.

Three checks are not expressible in the schema and are the validator's own, named so no reader
expects the schema to carry them: every `proves` entry names a `criteria[].id` in the story's data
file; `design.path` exists in the checkout; H ≤ `size-cap:` unless `exception`. They print as
`refused:` lines in D5's form, after the schema's, every failing check at once.

The prose file has a schema too, and it is the template: its `## ` headings must be exactly the
template's prose headings — a data heading in the prose file is refused ("`## Files` is rendered
from the data; remove it"), an unknown heading is refused for D3's reason, a missing one is refused,
each must be non-empty, and no template stub may survive. The placeholder scan moves to
`backlog.py` in the same change as the prose validator, with the witness cases of #41 and #42
carried over and the awk form of `body_placeholders` deleted, so one scanner serves both the prose
file and the `legacy:` bodies for the window.

*Forecloses:* a validator that ignores a keyword it does not implement; an object schema without
`additionalProperties: false`; a declared Python dependency; a second validator in the plugin (the
`jq` program of D3); `yq`, `ajv`, `pip`; a `backlog.py` that calls `gh` or `git`.

*Amended 2026-10-01, later (D20):* the install-failure argument above is no longer what keeps
`yq` out — Kris withdrew that objection for `yq` specifically, and D20 keeps `yq` out because the
format gives it no job and the name is two programs. The standard-library rule for Python stands
unchanged: what was permitted is `yq`, not a declared Python dependency, and `pyyaml` and
`jsonschema` remain foreclosed on this decision's own ground. Nothing else in this decision moves.

### D17 — JSON for the data, a sibling Markdown file for the prose, both under `.claude/crew/backlog/<id>.*`

Kris: "I do not care if it is json/yaml or the next popular format." Chosen on two criteria — prose
pleasant to write and to diff, and what is on the machine — and not brought back. The data file is
`<id>.json`; the prose is `<id>.md`, one `## ` heading per prose section of the kind's template.
JSON because `jq` is already present, the consumer's gate (D7) reads two keys of it, and Python's
`json` is standard library. Not YAML or TOML: neither is in the standard library (TOML is read-only
from 3.11, above the floor), a hand-rolled subset parser is the failure D16 refuses, and `pyyaml` is
the dependency D16 refuses. Not JSON alone: five or six paragraphs of prose in a JSON string are
written with `\n` and read in a diff as one line. Not one Markdown file with a data front matter:
the gate's `jq -r '.files[].path' "$f"` and `input_filename` would both need an extraction step
first, in every project. Two files is one more file per item and nothing else; a `.json` without its
`.md`, or the reverse, is refused.

The directory moves from D2's `.claude/crew/items/` to `.claude/crew/backlog/`. The old choice
shared a directory with the template overrides (`items/task.md`); with a prose file per item,
`8.md` beside `task.md` is two kinds of file under one glob. "Backlog" is Kris's word for what this
keeps true. The id stays the file name and stays out of the file (D2); `title` joins the data
because the adapter writes it, `sync` repairs it, and the story's `## Tasks` and Proof map render
task titles from files alone.

*Forecloses:* YAML or TOML on disk; prose inside JSON; a front-matter single file; a data file
under `.claude/crew/items/`; a `--title` flag.

*Amended 2026-10-01, later (D20):* re-ruled with the dependency objection withdrawn. "What is on
the machine" is no longer a criterion and "`pyyaml` is the dependency D16 refuses" is no longer
the reason YAML is out; D20 gives the grounds that hold now, and on them JSON, the sibling
Markdown file and `backlog/` all stand unchanged. The one-file shapes this decision dismissed in a
clause — prose in block scalars, a front-matter file — are weighed there in full.

### D18 — Templates are versioned by the plugin release; a heading change migrates the record through `/crew:conform`, any other change is a re-render

The lead's gap: if the template produces the artefact, the template is code, and a change to it
makes every future body differ from every past one unless they are re-rendered — which quietly
defeats the uniformity that is the point. The answer has two halves, and D15's rule "a template
renders nothing but its headings" is what makes both small.

A change to **how a fact renders** — the header, a data section, the footer — is code in
`backlog.py`, versioned by the plugin release and by nothing else: no template version number,
because a second number to bump is the release-rule drift this repository's profile records twice.
Such a change is a minor release by the changelog's own test (a consumer sees output it could not
before). After the upgrade every body is a stale projection: `lint --all` counts them (`N stale
render`), and `sync --all` re-renders in one pass. Re-rendering is **mandatory in effect and bulk by
design**: `lint` is red until it runs, and it needs no per-item approval because nothing authored
changes — D11's "a migration is a diff the user sees per item" is about the record, and a
projection is not the record. An item rendered under the previous release is stale, never invalid,
and never refused.

A change to a template's **headings** — a prose heading renamed, added or removed, in the shipped
template or in a project override — changes what the prose files must contain, so it is a change to
the record and travels as D11 says: a `schema` bump when shipped, applied by `/crew:conform` as a
diff per item, never on read; a project changing its own override runs the same pass over its own
board. A change to a template's guidance or comment renders nothing and migrates nothing.

*Forecloses:* a template version number; a re-render that asks per item; a heading change applied
on read; a body refused for the release it was rendered under.

### D19 — The purpose is agents keeping a backlog true, so every maintenance act is a command over the files, idempotent and bulk, and every kind has a file

Kris: "AI assisted backlog management is the only way forward." Every failure of 2026-10-01 was
maintenance, not authoring: eight of eight citations wrong in a document agents wrote, a changelog
claim false for four releases, a Proof map grading a moved tree. This design is therefore judged on
an agent updating many items correctly, and that fixes the shape:

- **The maintenance loop is three commands.** Edit files (`jq` over `backlog/*.json` for a bulk
  fact — a role renamed, a design path moved; an editor for prose), `tracker.sh lint --all` to see
  every refusal, disagreement and stale render at once, `tracker.sh sync --all` to project. No step
  edits a body by hand, comments, or asks per item; `lint` is read-only and `sync` is idempotent,
  so a pass can be re-run after a partial failure with no second effect.
- **Every kind has a file.** D1 gave stories and tech-debt none because nothing in them was
  countable; under D15 the reason is uniformity by construction and one validation path, and a
  story is precisely where the hand-kept copies rotted. A story's criteria are data
  (`criteria: [{id, text}]`, ids 1..n checked by the validator rather than by `validate_story_body`'s
  prose walk), its Proof map is computed (D15), and the `proves` cross-check runs from files alone —
  the check D4 said only the adapter could make, the consumer's gate can now make too. A tech-debt
  item's two facts, `foundIn` and `since`, are data and the rest is prose.
- **The projection is total.** `sync` writes the title, the kind label, the `role:<r>` label,
  `parent`, `blockedBy` by set difference, and the body — everything the tracker holds that the
  files decide — so a tracker is reproducible from the repository plus each item's number and
  state.
- **A brief carries the files, not the page.** `work` step 3 hands the owning role `<n>.json` and
  `<n>.md`; the role edits those in its change (D5); the lead runs `sync <n>` before the PR.

*Forecloses:* a maintenance step that edits a body by hand; a kind without a file; a per-item
prompt in a bulk command; a fact that exists on the tracker and not in a file.

## §11 — The format, re-ruled with the dependency constraint lifted (2026-10-01, later)

### D20 — With a `yq` dependency permitted, JSON and two files stand on the merits, and `yq` gets no job

Kris, 2026-10-01, after the lead had argued the dependency case twice: "it is okay if the plugin
has a dependency on yq." The objection is withdrawn and is not re-argued here. D17 chose JSON
partly on "what is on the machine" and D16 foreclosed `yq` on the install-failure ground; both are
re-ruled below with that ground gone. The shape survives it.

The premise the whole ruling rests on, and the first thing to re-examine if anyone reopens this:
asked whether he would hand-edit the facts file or read the rendered body, Kris answered that
agents write it and he reads the body (2026-10-01). Comments are the one thing YAML has that JSON
cannot express, and they buy nothing in a file no person edits — so the trade collapses and JSON
wins without needing the arguments below. Should that premise ever change, and a person starts
editing these files by hand, YAML through `mikefarah/yq` becomes the better choice and this
decision should be reopened on that ground alone.

**The data stays JSON — a choice, not a leftover.** Three reasons, none of them the dependency.

1. *There is nothing left for YAML to carry.* The data file is ten scalar keys and two arrays of
   short records (D3's table plus D17's `title` and D19's per-kind keys); every paragraph is in
   `<id>.md`. What YAML has that JSON lacks — block scalars, anchors, comments, unquoted strings —
   has no reader here: a program writes the file (`plan`, `/crew:conform`, `jq` in a bulk edit of
   D19's loop), a schema validates it, and an agent edits it by expression.
2. *YAML's implicit typing mistypes this schema's own values unless they are quoted.* Witnessed
   with PyYAML 6.0.3, the parser the `yq` of `apt` and `pacman` wraps: `story: 2` is read as an
   integer, `blockedBy: [6]` as integers, `since: 2026-09-30` as a date, `exception: no` as
   `false`. D2 made ids strings, D19 made `since` a string, `exception` is a string — so every id
   written the natural way would be refused by the validator as the wrong type, the refusal class
   this design exists to end. And the other `yq` parses YAML 1.2, which resolves `no` and a bare
   date differently, so one file would be valid on one machine and refused on another. JSON has one
   way to write `"2"`.
3. *`yq` is two unrelated programs under one name, and the package managers disagree about which
   one the name installs.* `apt install yq` (Debian unstable 3.4.3) and `pacman -S yq` (Arch 4.1.2)
   install kislyuk's wrapper — a Python package over `jq` and PyYAML that forwards jq's own
   arguments; `brew install yq` installs mikefarah's Go processor (4.54.1) — its own expression
   language, `-o=json`, `--front-matter`. mikefarah's is `go-yq` on Arch and kislyuk's is
   `python-yq` on Homebrew. A design that names `yq` must name which, carry an install line per
   platform, and detect the other at startup by its `--version` text, and D7's gate snippet would
   need two forms (`--argjson` exists in one and not the other). That is more machinery than a file
   with no YAML in it can justify. Were one ever needed it would be mikefarah's: kislyuk's is
   PyYAML by another name, the dependency D16 refuses on its own ground. Neither was on the
   architect's machine at ruling time (`command -v yq`: exit 127).

**Two files stand; one file with the prose in block scalars is refused.** The real gain of one
file is one path per item and an atomic D5 step 3 — one `mv` instead of two. Against it: the prose
file's schema is the template's heading set (D16), and D18 migrates the record by heading; inside a
block scalar the `## ` headings are text within a string, so the heading validator would parse
Markdown out of YAML — the same check with a decoding step and indentation rules in front of it.
The prose carries numbered tests, fenced snippets and nested lists (`## Tests (RED first)`,
`## Done when`); under a block scalar every one of those lines is indented, and the chomping
indicator (`|`, `|-`, `|+`) with the indentation indicator decides what its trailing newline is —
the several-ways problem applied to prose rather than to data. GitHub renders `8.md` as Markdown in
a PR and an editor treats it as Markdown; neither does so inside a YAML string, and a reflowed
paragraph diffs as indented YAML lines. The half-written case the atomic step would close is
already refused loudly: "a `.json` without its `.md`, or the reverse, is refused" (D17), and a
failed step 3 prints its one repair (D5).

The better one-file shape, named so it is not re-raised: Markdown with a YAML front-matter block,
which mikefarah's `yq --front-matter=extract` reads without the extraction step D17 refused it
for. It is refused for reasons 2 and 3 — the front matter is YAML, and the flag is one
implementation's — and because D7's consumer gate would then read the file with that one `yq`
instead of with the `jq` every `gates:` line already has.

**Had the format moved, the validator pipeline would have been** `yq -o=json . <id>.yaml |
python3 backlog.py validate -` (mikefarah) or `yq . <id>.yaml | …` (kislyuk): one dependency
serving the adapter and the validator, D16's standard-library rule intact. What breaks is not that
file but its siblings: the story render and the `proves` cross-check read other items' files (D15,
D19), so `backlog.py` would either run `yq` per sibling — a subprocess its "inputs are files"
shape does not have — or take a pre-converted stream from the adapter; and reason 2's refusals
arrive before Python sees a byte. Recorded so it is not re-derived; not needed, since the format
does not move.

Nothing registered changes: D2, D5, D7, D12, D15, D16, D17 and D19 keep their paths, extensions,
flags and checks, so no task's files or `## Done when` line moves.

*Forecloses:* YAML or TOML on disk, a front-matter file, prose in a block scalar, `yq` in the
plugin or in D7's gate snippet — each on the grounds above, none on the dependency ground Kris
withdrew, which this decision does not reinstate.
