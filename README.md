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
| Board | `/crew:status` |
| Whole session as delivery lead | `/crew:on` … `/crew:off` (or `mode: always` in the profile) |

Second session on the same repo: `claude --worktree task-15`, then `/crew:next`. Claims are
issue assignee + `in-progress` label + a claimed-by comment; `next` never offers a claimed task.

## Roles

product-owner · architect · frontend-engineer · backend-engineer · integration-engineer ·
event-sourcing-engineer · genai-engineer · agentic-ai-engineer · multitenancy-engineer ·
commercial-analyst · qa-engineer · security-engineer · cloud-engineer · ux-designer ·
privacy-and-compliance · technical-writer. Disable any of them per project in the profile.

Every persona has the same skeleton: read the profile first, mandate, not-my-job with the
owning role named, how I work, definition of done, a fixed output contract
(Result / Changes or Findings / Verification / Hand-offs / Open questions), and escalate-early
rules. Read-only roles cannot edit files.

## TDD

Practice, not tooling. Every code persona writes the test first and must quote the failing
run before the passing run in its Verification; the qa-engineer files a missing red run as a
P1; the delivery lead sends it back once and then to the user; the definition-of-done
template carries the same line. Genuinely test-free changes (covered refactor, config,
generated code) are declared in Result and the lead decides.

## Model per role

Set in each persona's frontmatter (`model:`), by kind of work rather than by role prestige:

| Kind of work | Model | Roles |
|---|---|---|
| Design, implementation, review and security; output becomes a contract or a verdict for others | `opus` | architect, backend, frontend, integration, cloud, event-sourcing, genai, agentic-ai, multitenancy, qa-engineer, security-engineer, ux-designer |
| Reading, checking and writing inside a fully bounded brief | `sonnet` | product-owner, technical-writer, commercial-analyst, privacy-and-compliance |

No persona is pinned to `fable`. The delivery-lead session runs on it; a frontmatter pin fails hard
when the allowance runs out (every pipeline step stops with a 429 instead of degrading, seen
2026-09-04), and the allowance burns in the many specialist runs, not in the one lead context. When
a single review needs the depth — a mutation review of a guard, a security review of an exposure
decision — the lead passes `model` on that Agent call and says so in the brief.

Tune after measuring; `effort:` is a separate lever (a cheaper model at high effort often beats
a stronger one at low effort for reviews).

## Layout

```
plugins/crew/
  agents/           16 personas
  skills/           init refine plan work review next status on off
  hooks/hooks.json  SessionStart (incl. compact) + UserPromptSubmit
  scripts/          session-context.sh prompt-context.sh crew-mode.sh tracker.sh common.sh
  templates/        operating-model.md profile.md role-addendum.md brief.md
```

Tracker backend: GitHub via `gh` today. `tracker: azure-devops …` is recognised and refused
with a clear message until that backend exists.

## Honest limits

Subagents do not see the conversation: the brief is the quality lever. Specialists cannot
debate each other; the lead reconciles. A story through the full pipeline costs several times
the tokens of a single-agent session; the profile's triage table keeps small things small.
