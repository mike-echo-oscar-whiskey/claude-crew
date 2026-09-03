---
name: status
description: Show the crew board: open stories with task progress, who holds what, and claims that look stale.
disable-model-invocation: true
---

Run `${CLAUDE_PLUGIN_ROOT}/scripts/tracker.sh status` and present it unchanged in a code block, then add at most five lines of observations: tasks in progress with no recent branch activity (check `gh issue view <n> --comments` for the claimed-by time and `git branch -r --list '*<n>-*'`), blocked tasks and what they wait on, stories with all tasks done that are still open. Do not change anything.
