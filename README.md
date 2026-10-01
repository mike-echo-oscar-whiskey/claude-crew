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

Upgrading: `CHANGELOG.md` says per release what changed, what to do, and what happens to a project
that changes nothing.

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
| Bring items filed before the item shape over to it | `/crew:conform [<n> \| --all]` (drafts the fixes a body already decides, briefs the owning role for new text, and shows you a diff per item before anything is written) |
| Whole session as delivery lead | `/crew:on` … `/crew:off` (or `mode: always` in the profile) |

`scripts/tracker.sh lint [<n> | --all | --kind story|task|bug|tech-debt] [--quiet]` is that report:
it only reads the board, prints one line per item whose body no longer matches its kind's template
naming each failing check, and exits 1 when any item fails. It reads up to 2000 items per kind (`gh`
pages the API to get there); if a kind fills that, the closing line names the kind and the limit and
the exit is 2, because a read that stopped short has no verdict to report.

Rollout policy: items filed before the item shape stay untouched until you run `/crew:conform`,
which edits one only after you approve its diff. The crew will not file a new item that lacks the
shape. A claim on an old item still goes through, with a warning.

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
the docs. A hand-off may be addressed to the lead for what only the lead can supply. When the diff
changes code a test protects, the qa-engineer reviews by mutation in a worktree of its own, detached
at the reviewed commit, which both pipeline skills create; for a docs-only diff, or a script nothing
builds or imports, no worktree is made and the review records the mutation as not applicable.

## TDD

Practice, not tooling. Every code persona writes the test first and must quote the failing
run before the passing run in its Verification; the qa-engineer files a missing red run as a
P1; the delivery lead sends it back once and then to the user; the definition-of-done
template carries the same line. Genuinely test-free changes (covered refactor, config,
generated code) are declared in Result and the lead decides.

## Model per role

One row per persona, keyed by the persona file in `plugins/crew/agents/`. **Dispatched** means the
tier the lead passed on the Agent call that started a run; a call that passes no tier gets the
persona's frontmatter `model:`. **Default** is that frontmatter value, verbatim. **Second tier** is
the tier the lead dispatches for the other *kind* of work that persona does, and reads `—` for a
persona that does one kind — the same work at a larger size is moved per call and is not a tier.
**Why this tier** names the error the tier is bought against, the runs behind it, and what would move
it.

Every count comes from one measured window: the 68 subagent runs of the 2026-09-29/30 session
(`scripts/subagent-model.sh audit`). A row's numbers are that persona's share of those 68, which is
why they do not add up to 68 anywhere, and six personas have no run in the window at all — their rows
say so instead of borrowing a reason they have not earned.

One principle decides which tier a kind of work earns: the higher tier goes where the error it
prevents is one no gate catches. A design that fits the wrong layer and an exposure nobody named are
invisible to every test here, so `architect` and `security-engineer` are pinned to `fable`. `opus`
over `sonnet` is that same test one step down — `opus` where a wrong answer survives review because
the reader cannot see what is missing (a specification, a mutation verdict, a tenant boundary), and
`sonnet` where the work is bounded and something other than the model that wrote it checks the
output. `haiku` is for locating and transcribing, where there is nothing to judge.

| Persona | Default | Second tier | Why this tier |
|---|---|---|---|
| `agentic-ai-engineer` | `opus` | — | A tool surface or loop whose wrong turn a green suite still hides; 13 runs, no miss logged. The four runs dispatched `haiku` were mechanical edits moved down per call. Down to `sonnet` on a window whose runs were all bounded edits. |
| `architect` | `fable` | `opus` | A design that fits the wrong layer is an error no gate catches: 4 runs on `fable` for the design itself. 3 runs were dispatched `opus` for the counting half — the plan whose first task shipped 34 hand-written files against this repository's size cap of 15. Down to `opus` once two consecutive plans hold every task under that cap. |
| `backend-engineer` | `opus` | — | No run in the measured window; unchanged. |
| `cloud-engineer` | `opus` | — | Infrastructure whose mistake surfaces in the apply rather than the review; 1 run, no miss logged. One run is thin: down to `sonnet` on a window of bounded chart or script edits. |
| `commercial-analyst` | `opus` | — | The fallback for a call that names no tier, set to the tier the dispatches name when they do name one: 1 of 1 in the window. That count chose the fallback and is not a logged miss — nothing says `sonnet` got a margin or tier claim wrong. Down to `sonnet` on a window of bounded catalog or margin lookups. |
| `event-sourcing-engineer` | `opus` | — | An event shape that is wrong is wrong permanently; 4 runs, no miss logged. Down to `sonnet` on a window whose runs only added handlers a rebuild checks. |
| `frontend-engineer` | `opus` | — | A spec that passes while the screen is still wrong; 2 runs, no miss logged. The one run dispatched `haiku` was a mechanical edit moved down per call. Down to `sonnet` on a window whose runs were all bounded edits. |
| `genai-engineer` | `opus` | — | No run in the measured window; unchanged. |
| `integration-engineer` | `opus` | — | No run in the measured window; unchanged. |
| `multitenancy-engineer` | `opus` | — | No run in the measured window; unchanged. |
| `privacy-and-compliance` | `sonnet` | — | No run in the measured window, and the only default *below* `opus` that nothing has measured: `sonnet` here is a declaration, not a finding. Up to `opus` on a logged miss — an obligation a run did not name. |
| `product-owner` | `opus` | — | The fallback for a call that names no tier, set to the tier the dispatches name when they do name one: 7 of 7 in the window. This persona writes the story every acceptance criterion is proved against, so a forgotten `model` argument landing on the cheaper tier is the mistake worth avoiding. That count chose the fallback and is not a logged miss. Down to `sonnet` on a window whose stories were all small and bounded. |
| `qa-engineer` | `opus` | `sonnet` | A mutation review's verdict comes from running the mutation tool and judging which surviving mutants matter — a judgement on a result no gate grades: 8 runs on `opus`. The 1 run on `sonnet` was a read-only documentation review, which has a text to check against. The frontmatter has said `opus` since 0.5.6. Down to `sonnet` on a window with no mutation review in it. |
| `scout` | `haiku` | — | Locating evidence for a brief — paths, lines, symbols — and returning no verdict; 1 run, no miss logged. Up on a brief whose Known context a run got wrong. |
| `security-engineer` | `fable` | — | An exposure nobody named is an error no gate catches: 4 runs on `fable`. The 1 run on `sonnet` was dispatched for a read-only check. Down to `opus` on a window where every exposure it named was also caught by a gate. |
| `technical-writer` | `sonnet` | `haiku` | Prose checked against the code, where the text to check against exists: 4 runs on `sonnet`, 3 dispatched `haiku` for one-line factual corrections. The 3 runs dispatched `opus` were whole-section prose — the same kind of work at a larger size, moved per call, which is why `opus` is not the second tier. Up to `opus` on a logged miss: prose that shipped contradicting the code. |
| `ux-designer` | `opus` | — | No run in the measured window; unchanged. |

What moves a tier is the finding that a persona's tier is *wrong* — that the work it does needs a
tier other than the one it is getting. That is a quality claim, so it moves only on named evidence: a
logged miss in the audit, a deliverable a run skipped, or a verdict that could not be trusted —
never on impression, and the run that justifies the move is named in this roster when the move is
made. It reads the same way **down**: a window in which the work needed no judgement the lower tier
could not have given. What is **not** grounds for it, in either direction, is that the persona has
been dispatched at some other tier, because a habit is not a miss. The **Default** column answers a
different question — which tier runs when a lead names none — and a fallback is chosen rather than
earned, so this rule does not reach it: the tier the dispatches ask for is the sensible fallback,
because a forgotten `model` argument should land on what the role is wanted on. That is why
`product-owner` and `commercial-analyst` default to `opus` with no logged miss behind either, and why
that default is not a claim their `sonnet` was wrong — only that nobody dispatches them on it.

A pin fails hard when its allowance — the quota that tier draws on in a window — runs out: every
pipeline step stops with a 429 instead of degrading (seen 2026-09-04), and the allowance burns in the
many specialist runs, not in the one lead context. That is why rule 13 of the operating model
(`plugins/crew/templates/operating-model.md`) carries a fallback: the lead re-issues the run at the
persona's default tier or below (`opus` for the two `fable` pins) and names the downgrade in the
report, so the user can judge whether the verdict still carries. That downgrade is one run, not a
tier move. The same lever moves a run up: when a single review needs the depth — a mutation review of
a guard, a security review of an exposure decision — the lead dispatches `model` on that Agent call
and says so in the brief.

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
  on it. `/crew:status` and `/crew:work` step 9 print the table; rule 13 requires it at every task
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
  skills/           init refine plan work review next status conform on off
  hooks/hooks.json  SessionStart (incl. compact) + UserPromptSubmit + SubagentStop
  scripts/          session-context.sh prompt-context.sh crew-mode.sh tracker.sh
                    subagent-model.sh common.sh
  scripts/tests/    subagent-model.test.sh tracker.test.sh review-contract.test.sh
                    model-roster.test.sh  (run bare; exit 0 on pass)
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

An agent review is a net under your own, never a substitute for it. A review brief carries the diff
and the criteria and nothing the people who did the work wrote about it; one round is the ceiling;
and a contested finding goes to you rather than to a second pass in the same session.

Nothing in the gate checks what this README and the two manifests claim about the plugin's own
shape. `claude plugin validate .` reads the manifests' structure, `jq empty` their syntax, and
`scripts/tests/model-roster.test.sh` holds the "Model per role" table's Default column against the
persona frontmatter — that is the whole of it. The skill set, the counts in Layout and the `17` in
both manifest descriptions are true by review only, which is why neither description enumerates the
skills: an enumeration that goes stale is invisible to every check here, and one did.
`tracker.sh lint --all` is deliberately not on the `gates:` line either — it would turn a gate red
for items nobody has had the chance to bring over.

The `/crew:*` skills are human-only under Claude Code, by `disable-model-invocation: true` in all
ten. Under Codex that key is rejected by its own authoring validator and parsed by neither of its
runtime paths (verified 2026-10-01), so a command written for a human to run — `/crew:conform`, which
edits issue bodies — would be model-invocable there with nothing to stop it. Drive the pipeline from
Claude Code.
