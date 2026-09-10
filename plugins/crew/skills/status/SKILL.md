---
name: status
description: "Show the crew board: open stories with task progress, who holds what, claims that look stale, and the model every subagent actually ran on."
disable-model-invocation: true
---

Run `${CLAUDE_PLUGIN_ROOT}/scripts/tracker.sh status` and present it unchanged in a code block, then add at most five lines of observations: tasks in progress with no recent branch activity (check `gh issue view <n> --comments` for the claimed-by time and `git branch -r --list '*<n>-*'`), blocked tasks and what they wait on, stories with all tasks done that are still open. Do not change anything.

Then run `${CLAUDE_PLUGIN_ROOT}/scripts/subagent-model.sh tail 10` and present its output under a `## Models` heading, unchanged, in a code block — its first line is the log path, the rest are the last ten subagent completions as `<timestamp> <agent-type> declared=<persona model> actual=<model from the transcript>`. Call out every line marked `MISMATCH` in one sentence each: which role, what it was dispatched on, what it actually ran on, and that its output should be judged accordingly. When the script prints that no log exists yet, say so in one line and move on — it means no subagent has completed in this project since the hook was installed.
