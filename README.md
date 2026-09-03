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

## TDD enforcement

Three layers, all driven by the profile's `tdd:` line (`/crew:tdd` shows or changes it):

1. **Guard hook** (PreToolUse on Write/Edit): a file matching `tdd-production` may only be
   edited when a file matching `tdd-tests` is modified, untracked, or in the last commit.
   `advisory` (the default) warns in context, `strict` denies with a reason, `off` disables.
   Applies to the lead and every subagent alike. The hook cannot tell a rename from a
   behaviour change, so the evidence contract below is the real enforcement.
2. **Evidence contract**: every code role must quote the RED run before the GREEN run in
   Verification; the qa-engineer files "no red run" as a P1 and the lead sends it back.
3. **Definition of done** carries the same line, so a PR is not opened without it.

Bash edits bypass the hook by construction; the personas are told not to use that door and
QA checks git history for tests written after the implementation.

## Model per role

Set in each persona's frontmatter (`model:`), by kind of work rather than by role prestige:

| Kind of work | Model | Roles |
|---|---|---|
| Judgment and design; output becomes a contract for others | `fable` | product-owner, architect, security-engineer, qa-engineer, event-sourcing, genai, agentic-ai, multitenancy, commercial-analyst, privacy-and-compliance |
| Implementation against a design and tests | `opus` | frontend, backend, integration, cloud, ux-designer, technical-writer |

Tune after measuring; `effort:` is a separate lever (a cheaper model at high effort often beats
a stronger one at low effort for reviews).

## Layout

```
plugins/crew/
  agents/           16 personas
  skills/           init refine plan work review next status on off tdd
  hooks/hooks.json  SessionStart (incl. compact) + UserPromptSubmit + PreToolUse TDD guard
  scripts/          session-context.sh prompt-context.sh crew-mode.sh tracker.sh tdd-guard.py common.sh
  templates/        operating-model.md profile.md role-addendum.md brief.md
```

Tracker backend: GitHub via `gh` today. `tracker: azure-devops …` is recognised and refused
with a clear message until that backend exists.

## Honest limits

Subagents do not see the conversation: the brief is the quality lever. Specialists cannot
debate each other; the lead reconciles. A story through the full pipeline costs several times
the tokens of a single-agent session; the profile's triage table keeps small things small.
