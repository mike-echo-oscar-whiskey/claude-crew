---
name: next
description: List claimable tasks (open, unassigned, unblocked, not in progress or review) and start /crew:work on the one the user picks, or on the first when --auto.
argument-hint: "[--auto]"
disable-model-invocation: true
---

Run `${CLAUDE_PLUGIN_ROOT}/scripts/tracker.sh next` and show the result as a short table (number, role, story, title). If `$ARGUMENTS` contains `--auto`, take the first row; otherwise ask the user which one with AskUserQuestion. Then follow the `crew:work` skill for that task number exactly as written there.
