# ✨ feat(crew): every subagent shows the model it was dispatched on, and its real model is proven from the transcript

## Problem

The delivery lead dispatches a persona with a `model:` from its frontmatter (or an override), and the
user sees only the task title. Claude Code's UI never shows a subagent's model or effort, there is no
flag for it, and the docs (v2.1.248+) list no `effort:` key for agent frontmatter — so the
`effort: high` on `architect`, `qa-engineer` and `security-engineer` is ignored by the harness today.
The user cannot tell whether a verdict came from the model the profile pins, which is exactly the
thing the fable pins exist for.

What does exist: every subagent's JSONL transcript under the session's tasks directory records
`"model":"<id>"` on every message, so the real model is provable after the fact with one grep.
Verified 2026-09-10 in vonk-platform: scout → claude-haiku-4-5, backend-engineer → claude-opus-5,
qa-engineer → claude-fable-5-1.

## Why

Kris, 2026-09-10: "I do not trust you using the correct model if I do not see it." A pinned verdict
role that silently degraded (a 429 fallback, a wrong override, a persona edit) would pass unnoticed.
The operating model already says the lead names a downgrade in the report; nothing makes the normal
case visible.

## Acceptance criteria

1. Given the lead dispatches any `crew:<role>`, then the Agent call's `description` (the task title)
   starts with the model it dispatches on, and the effort when one is intended:
   `haiku · locate evidence for #371`, `opus · implement #371`, `fable/high · security review of PR #403`.
   An override of the persona's `model:` shows the override, not the default.
2. Given a subagent completes, then the lead's report names the model it actually ran on, read from
   the transcript (`grep -o '"model":"[^"]*"' <output> | sort | uniq -c`), beside the dispatched one;
   a mismatch is reported as such, never absorbed.
3. Given a `SubagentStop` hook fires, then the plugin appends one line
   `<timestamp> <agent-type> declared=<model> actual=<model from transcript>` to a per-session log
   under the session's scratchpad (path from the hook payload; if the payload carries neither the
   agent type nor the transcript path, the hook records what it has and the operating model says the
   transcript grep is the authority), so the status line or `/crew:status` can show the last N runs.
4. Given the `effort:` frontmatter key does nothing in the harness, then it is removed from the three
   personas and the README's model table says effort is session-level; if a future Claude Code
   release documents a per-agent effort field, this reverses.
5. Given the operating model, then rules 2 and 13 carry the title convention and the transcript
   check, so a lead that reads nothing else still does both.

## Out of scope

- Rendering the model inside Claude Code's own task row or completion line (not available; a
  `/feedback` to Anthropic is the route).
- Per-subagent effort control (no harness support today).

## Open questions

1. Log location: the session scratchpad (session-local, disappears) or `~/.claude/crew/<session>.log`
   (survives, needs its own cleanup)? Recommendation: scratchpad, and print the path in `/crew:status`.
2. Should `/crew:status` show the model column, or only the log? Recommendation: a column — it is the
   board the user already looks at.
