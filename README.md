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

## Model per role

All personas inherit the session model by default. Tune per role with the `model:` /
`effort:` frontmatter fields after measuring: judgment roles (product-owner, architect,
security, the domain specialists) on the strongest model; implementers one step down;
reviewers with a narrow contract cheaper; `status`/`next` mechanical.

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
