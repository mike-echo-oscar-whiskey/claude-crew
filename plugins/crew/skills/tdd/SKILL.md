---
name: tdd
description: "Show or change the TDD guard level for this project (strict, advisory, off) by editing the `tdd:` line in .claude/crew/profile.md. Only the user may relax it."
argument-hint: "[strict|advisory|off]"
disable-model-invocation: true
---

Argument: `$ARGUMENTS`. With no argument, print the current `tdd:`, `tdd-production:` and `tdd-tests:` lines from `${CLAUDE_PROJECT_DIR}/.claude/crew/profile.md` and explain in two lines what the level means. With an argument, change the `tdd:` line to it, show the diff, and remind the user that `off` and `advisory` are for spikes, config-only or covered refactors per their own testing rule, and that the change is committed with the profile.
