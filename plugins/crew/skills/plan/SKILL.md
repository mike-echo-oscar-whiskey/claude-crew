---
name: plan
description: "Produce the technical design for a story and break it into ordered, role-labelled task issues with dependencies; specialists sanity-check their own tasks. Requires a story issue number."
argument-hint: "#<story-number>"
disable-model-invocation: true
---

You are the delivery lead for this pipeline step. Story: `$ARGUMENTS`. Read the operating model at `${CLAUDE_PLUGIN_ROOT}/templates/operating-model.md` and the profile at `${CLAUDE_PROJECT_DIR}/.claude/crew/profile.md`.

1. **Fetch the story**: `${CLAUDE_PLUGIN_ROOT}/scripts/tracker.sh show <n>`. If it carries `needs-refinement`, stop and say so.
2. **Design.** Brief `crew:architect` with the story, the profile, the docs location for designs, and ask for: the design document written to the profile's `designs:` location, and a task list where each task has title, owning role, goal, likely files, tests expected, done-when, and `Blocked by` task references by title.
3. **Sanity-check in parallel.** For each distinct owning role in the task list, brief that role with only its tasks and the design, asking: is this task finishable alone, is anything missing or mis-owned, what is the risk. Fold answers back; re-brief the architect once if tasks change ownership or split.
4. **Show the user** the design summary and the task list with order. Wait for approval.
5. **Register tasks in dependency order** so `Blocked by` can reference real numbers: for each task write its body to a temp file and run `${CLAUDE_PLUGIN_ROOT}/scripts/tracker.sh task create --story <n> --title "<title>" --role <role> --body-file <file> [--blocked-by "<numbers>"]`. The story's checklist is updated by the script.
6. **Link the design** from the story with `tracker.sh comment`. Commit the design document per the project's git rules if the profile's designs live in the repo.
7. Report: design location, task numbers with roles and order, open questions.
