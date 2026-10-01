# claude-crew

A Claude Code plugin that turns a session into a **delivery lead** directing a scoped crew of
specialist agents, with a per-project **stack profile**, a story → design → tasks → PR pipeline
on GitHub issues, and multi-session work through worktrees and issue claims.

Discipline lives in the personas (this repo). Stack lives in each project's
`.claude/crew/profile.md`. That split is what makes the same crew work on any stack.

## Install

```bash
# once per machine
claude plugin marketplace add mike-echo-oscar-whiskey/claude-crew   # or a local path while developing
claude plugin install crew@claude-crew
# once per project
claude   # then: /crew:init
```

Development from a checkout: `claude --plugin-dir ./plugins/crew`.

## Using it

| Want | Do |
|---|---|
| One specialist's opinion | mention `@agent-crew:security-engineer` (any role) in a prompt |
| Refine a backlog line into a story issue | `/crew:refine <text or #issue>` |
| Design + task issues for a story | `/crew:plan #12` |
| Work a task to a PR in a worktree | `/crew:work #15` |
| Crew review of a PR | `/crew:review 40` |
| Pick the next claimable task | `/crew:next` |
| Board, with how many items still match the item shape | `/crew:status` (the count comes from `scripts/tracker.sh lint --all --quiet`; `lint --all` is the per-item report behind it) |
| Whole session as delivery lead | `/crew:on` … `/crew:off` (or `mode: always` in the profile) |

`scripts/tracker.sh lint [<n> | --all | --kind story|task|bug|tech-debt] [--quiet]` is that report:
it only reads the board, prints one line per item whose body no longer matches its kind's template
naming each failing check, and exits 1 when any item fails.

Second session on the same repo: `claude --worktree task-15`, then `/crew:next`. Claims are
issue assignee + `in-progress` label + a claimed-by comment; `next` never offers a claimed task.

`scripts/tracker.sh ensure-labels` mints the board's labels, the review severities `p1`, `p2` and
`p3` among them, each carrying in its own description what that severity obliges.

## Roles

product-owner · architect · frontend-engineer · backend-engineer · integration-engineer ·
event-sourcing-engineer · genai-engineer · agentic-ai-engineer · multitenancy-engineer ·
commercial-analyst · qa-engineer · security-engineer · cloud-engineer · ux-designer ·
privacy-and-compliance · technical-writer · scout. Disable any of them per project in the profile.
The scout is the lead's only: use it before writing a brief to locate the evidence for its Known
context (files, symbols, call sites, config keys, each as `path:line` plus the quoted line, and an
explicit not-found list); a specialist never calls it and it never gives a verdict.

Every persona has the same skeleton: read the profile first, mandate, not-my-job with the
owning role named, how I work, definition of done, an evidence block, a fixed output contract
(Result / Changes or Findings / Verification / Hand-offs / Open questions), and escalate-early
rules. Read-only roles cannot edit files.

The evidence block is what the crew learned on its first real day (2026-09-04): the brief's Known
context is the lead's belief and the code wins over a wrong fact in it; Claude Code strips the
built-in `LSP` tool from every subagent, so a project that wants code intelligence in its roles
registers [Serena](https://github.com/oraios/serena) in its `.mcp.json` — MCP tools are inherited —
and every reference list a persona reports comes from it, at Serena's default answer cap (a
grep-based list where Serena was available is a defect the lead sends back); without it a persona
declares grep-based call-site lists as such and asks the lead for references it needs; and neither
tool sees reflection, string-keyed dispatch or convention-based registration, so those are checked
before anything is called dead. Each role carries
only the Serena tools its mandate needs: engineers and QA navigate and edit by symbol, architect,
technical-writer, security, privacy and the scout navigate only, product-owner, commercial-analyst and
ux-designer have none, and no role touches Serena's memory store — project memory is the profile and
the docs. A hand-off may be addressed to the lead for what only the lead can supply. The qa-engineer reviews by mutation, always in a worktree of its own, detached at the
reviewed commit; both pipeline skills create it.

## TDD

Practice, not tooling. Every code persona writes the test first and must quote the failing
run before the passing run in its Verification; the qa-engineer files a missing red run as a
P1; the delivery lead sends it back once and then to the user; the definition-of-done
template carries the same line. Genuinely test-free changes (covered refactor, config,
generated code) are declared in Result and the lead decides.

## Model per role

One row per persona, keyed by the persona file in `plugins/crew/agents/`. **Default** is that file's
frontmatter `model:`, verbatim. **Second tier** is the tier the lead passes on the Agent call for the
other kind of work that persona does, and reads `—` for a persona that does one kind of work.
**Why this tier** names the runs behind it: the counts are the audit of the 68 subagent runs in the
2026-09-29/30 session (`scripts/subagent-model.sh audit`), and a persona with no run in that window
says so instead of borrowing a reason it has not earned.

| Persona | Default | Second tier | Why this tier |
|---|---|---|---|
| `agentic-ai-engineer` | `opus` | — | 13 runs on `opus`. The four runs dispatched `haiku` were mechanical edits moved down per call, not a second kind of work. Unchanged. |
| `architect` | `fable` | `opus` | 4 runs on `fable` for the design itself, 3 on `opus` for the counting half — the thirteen-task plan whose first task shipped 34 files (#716/#717). A design that fits the wrong layer is an error no gate catches. Unchanged. |
| `backend-engineer` | `opus` | — | No run in the measured window; unchanged. |
| `cloud-engineer` | `opus` | — | 1 run on `opus`; unchanged. |
| `commercial-analyst` | `opus` | — | Declared `sonnet` and ran `opus` on its one run in the window. Changed here, `sonnet` → `opus`. |
| `event-sourcing-engineer` | `opus` | — | 4 runs on `opus`; unchanged. |
| `frontend-engineer` | `opus` | — | 2 runs on `opus`. The one run dispatched `haiku` was a mechanical edit moved down per call. Unchanged. |
| `genai-engineer` | `opus` | — | No run in the measured window; unchanged. |
| `integration-engineer` | `opus` | — | No run in the measured window; unchanged. |
| `multitenancy-engineer` | `opus` | — | No run in the measured window; unchanged. |
| `privacy-and-compliance` | `sonnet` | — | No run in the measured window; unchanged. |
| `product-owner` | `opus` | — | Declared `sonnet` and ran `opus` seven times in the window, every one of them dispatched `opus`; the story it writes is the specification every criterion is proved against. Changed here, `sonnet` → `opus`. |
| `qa-engineer` | `opus` | `sonnet` | 8 runs on `opus`, 1 on `sonnet`: a mutation review's verdict comes from running Stryker and reading what survived (`opus`); a read-only documentation review does not (`sonnet`). This table listed it under `fable` until the roster landed; the frontmatter has said `opus` since 0.5.6. |
| `scout` | `haiku` | — | 1 run on `haiku`: locating evidence for a brief, no judgement. Unchanged. |
| `security-engineer` | `fable` | — | 4 runs on `fable`, 1 on `sonnet`. An exposure nobody named is an error no gate catches. Unchanged. |
| `technical-writer` | `sonnet` | `haiku` | 4 runs on `sonnet`, 3 on `haiku` for one-line factual corrections — and 3 on `opus`, moved up per call for whole-section prose. What would move the default to `opus`: a logged miss on a README truth pass, or a run that shipped prose the code contradicts. Unchanged. |
| `ux-designer` | `opus` | — | No run in the measured window; unchanged. |

A tier moves only on named evidence — a logged miss in the audit, a deliverable a run skipped, or a
verdict that could not be trusted — never on impression, and the run that justifies a move is named
in this roster when the move is made.

`architect` and `security-engineer` are pinned to `fable` because their errors are the ones the gates
cannot catch: a design that fits the wrong layer, an exposure that nobody named. A pin fails hard
when the allowance runs out — every pipeline step stops with a 429 instead of degrading (seen
2026-09-04) — and the allowance burns in the many specialist runs, not in the one lead context. That
is why rule 13 of the operating model carries a fallback: the lead re-issues the run at the persona's
default tier or below (`opus` for those two) and names the downgrade in the report, so the user can
judge whether the verdict still carries. The same lever moves a run up: when a single review needs
the depth — a mutation review of a guard, a security review of an exposure decision — the lead passes
`model` on that Agent call and says so in the brief.

`effort:` is **not** a supported agent-frontmatter key (verified 2026-09-10 against the Claude Code
hooks and subagent documentation, client 2.1.263): a subagent inherits the *session's* effort level,
and there is no per-agent lever. The roles whose verdict no gate checks used to carry
`effort: high`; the harness
ignored it, so it is gone rather than left as decoration that reads like a guarantee. The lead
compensates the only way the harness allows — with the model: the roles whose errors no gate catches
are pinned a tier up (`fable`), and a single run that needs more depth is moved up per call with
`model` on the Agent call. If a future release documents a per-agent effort field, this reverses and
those pins come back.

## Which model actually ran

A pin is a declaration, not proof, and Claude Code's UI never shows a subagent's model. Two things
make the real one visible:

- **The task title.** Operating-model rule 2 requires every Agent call's `description` to start with
  the model it dispatches on — `haiku · locate evidence for #371`, `fable/high · security review of
  PR #403` — so the model is on screen while the run is in flight, and an override shows the
  override.
- **The audit — this is the proof.** Every message in a subagent's JSONL records `"model":"<id>"`,
  so the model a run really used is provable after the fact, and
  `scripts/subagent-model.sh audit [<session-dir>]` proves it for a whole session at once. It walks
  the session's `tasks/*.output` and prints one row per run — run id, role, the model the
  **dispatch asked for**, the model or models that ran, call count, size — flagging `MISMATCH`
  where those two disagree and `DISPATCH-CONFLICT` where a task title and an explicit `model`
  argument named different models. The declared value is the dispatch's, resolved in that order:
  the title's leading model token (the claim the user saw), then the `model` argument, then the
  persona's `model:`. A run whose dispatch cannot be located prints `?` and is not counted as a
  mismatch — an unknown is not a finding. It exits 1 when any row disagrees, so a caller can gate
  on it. `/crew:status` and `/crew:work` step 8 print the table; rule 13 requires it at every task
  boundary.

The plugin's `SubagentStop` hook (the same script) appends a line per completed subagent to
`crew-models.log` in the session's scratchpad, but it is **best-effort, not proof**: it can only
report what the client's payload carries, and a payload with no `agent_type` and no
`agent_transcript_path` leaves it resolving both from the session's own files — when it cannot, it
records the payload's field *names* once so the next diagnosis is a read rather than a guess. It
records the role, the model the **persona** declares and the model that ran, and passes no verdict:
it cannot see what the dispatch asked for, so a deliberate override would read there as a mismatch.
It never fails a subagent: it exits 0 on every path and writes nothing to stdout.

That matters most for the 429 fallback in rule 13: a verdict role re-issued a tier down is exactly
the case where the user must be free to discount the verdict, and the audit shows it happened.

## Layout

```
plugins/crew/
  agents/           17 personas
  skills/           init refine plan work review next status on off
  hooks/hooks.json  SessionStart (incl. compact) + UserPromptSubmit + SubagentStop
  scripts/          session-context.sh prompt-context.sh crew-mode.sh tracker.sh
                    subagent-model.sh common.sh
  scripts/tests/    subagent-model.test.sh tracker.test.sh review-contract.test.sh
                    (run bare; exit 0 on pass)
  templates/        operating-model.md profile.md role-addendum.md
                    item-story.md item-task.md item-bug.md item-tech-debt.md
                    (read at runtime; a project replaces one kind by putting its own
                     complete copy at .claude/crew/items/<kind>.md)
```

Tracker backend: GitHub via `gh` today. `tracker: azure-devops …` is recognised and refused
with a clear message until that backend exists.

## Honest limits

Subagents do not see the conversation: the brief is the quality lever. Specialists cannot
debate each other; the lead reconciles. A story through the full pipeline costs several times
the tokens of a single-agent session; the profile's triage table keeps small things small.
