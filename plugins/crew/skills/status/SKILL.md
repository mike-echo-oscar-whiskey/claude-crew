---
name: status
description: "Show the crew board: open stories with task progress, who holds what, claims that look stale, how many items still match the item shape, and the model every subagent actually ran on."
disable-model-invocation: true
---

Run `${CLAUDE_PLUGIN_ROOT}/scripts/tracker.sh status` and present it unchanged in a code block, then add at most five lines of observations: tasks in progress with no recent branch activity (check `gh issue view <n> --comments` for the claimed-by time and `git branch -r --list '*<n>-*'`), blocked tasks and what they wait on, stories with all tasks done that are still open. Do not change anything.

Then run `${CLAUDE_PLUGIN_ROOT}/scripts/tracker.sh lint --all --quiet` — its closing line reads `N conforming, M not` — and put that line under the board, on a line of its own, as `items: N conforming, M not (tracker.sh lint --all)` — it is read-only, and `tracker.sh lint --all` is the command that lists which items they are. Exit 1 only means M is not 0; it is not a failure, and nothing else is reported about it here.

Then run `${CLAUDE_PLUGIN_ROOT}/scripts/subagent-model.sh audit` and present its output under a `## Models` heading, unchanged, in a code block — its first line is the tasks directory it walked, then one row per run as `<run-id> <role> <declared> <actual> <calls> <size> <flag>`, then a closing count. `declared` is what the dispatch asked for: the model token its task title started with, else its explicit `model` argument, else the persona's default. The table is the proof, not the `crew-models.log` the `SubagentStop` hook writes, which is best-effort and depends on payload fields this client does not always send. Exit 1 means the closing count is not clean; it is a finding, not a script failure.

Call out every row flagged `MISMATCH` in one sentence each: which role, what it was dispatched on, what it actually ran on, and that its output should be judged accordingly. Call out a `DISPATCH-CONFLICT` as a lead error — the title and the `model` argument named different models — and say which. A `?` in the declared column means the dispatch could not be located and is not a finding; so is `unresolved`. When the script says no runs were found, say so in one line and move on: it means no subagent has completed in this session yet.
