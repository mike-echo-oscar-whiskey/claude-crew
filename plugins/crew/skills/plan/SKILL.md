---
name: plan
description: "Produce the technical design for a story and break it into ordered, role-labelled task issues with dependencies; specialists sanity-check their own tasks. Requires a story issue number."
argument-hint: "#<story-number>"
disable-model-invocation: true
---

You are the delivery lead for this pipeline step. Story: `$ARGUMENTS`. Read the operating model at `${CLAUDE_PLUGIN_ROOT}/templates/operating-model.md` and the profile at `${CLAUDE_PROJECT_DIR}/.claude/crew/profile.md`.

1. **Fetch the story**: `${CLAUDE_PLUGIN_ROOT}/scripts/tracker.sh show <n>`. If it carries `needs-refinement`, stop and say so.
2. **Design.** Brief `crew:architect` with the story, the profile, the docs location for designs, and the task body step 5 resolves, and ask for: the design document written to the profile's `designs:` location, and a task list where every task is that body filled — title, owning role, goal, a `## Files` list naming **every path** (no "and every call site" clause: name them, or ask you for a `crew:scout` pass), `Size:`, `Split line:`, the expected RED tests, done-when, `## Proves` naming the criteria it proves, and `Blocked by` task references by title.
3. **Sanity-check in parallel.** For each distinct owning role in the task list, brief that role with only its tasks and the design, asking: is this task finishable alone, is anything missing or mis-owned, what is the risk, **count the hand-written files — over the profile's `size-cap:` (absent: 15), where is the split?**, and **can you start from this body without a conversation?** Fold answers back; re-brief the architect once if tasks change ownership or split — a split is one re-brief, not a new round per task.
4. **Show the user** the design summary and the task list with order. Wait for approval.
5. **Register tasks in dependency order** so `Blocked by` can reference real numbers: for each task write its body to a temp file and run `${CLAUDE_PLUGIN_ROOT}/scripts/tracker.sh task create --story <n> --title "<title>" --role <role> --body-file <file> [--blocked-by "<numbers>"]`. The story's checklist is updated by the script.

   The task shape is not yours to invent. Resolve it once, before step 2, and stop at the first hit: `${CLAUDE_PROJECT_DIR}/.claude/crew/items/task.md` — the project's override, which wins **whole** — else `${CLAUDE_PLUGIN_ROOT}/templates/item-task.md`, the shipped shape. Substitute the profile keys the body names, each taking the fallback the body's own instruction states when the key is absent or `-`: `generated:` (absent: every file in `## Files` counts toward `Size:`), `size-cap:` (absent: 15; `-`: no cap, `Size:` still counted), `definition-of-done:` (absent: the profile's own Definition of done section), `merge-authority:` (absent: the author), and the tracker sigil from `tracker:` (`#` for github). Hand that rendered body to the architect in step 2 and file it back verbatim here; the leading HTML comment is the contract, not part of the body. A story body resolves the same way from `items/story.md` else `templates/item-story.md`.
6. **Link the design** from the story with `tracker.sh comment`. Commit the design document per the project's git rules if the profile's designs live in the repo.
7. Report: design location, task numbers with roles and order, open questions.
