---
name: init
description: "Create or refresh this project's crew profile (.claude/crew/profile.md) by scanning the repo and asking for what cannot be inferred; ensures tracker labels and a CLAUDE.md pointer. Run once per project."
argument-hint: "[--refresh]"
disable-model-invocation: true
---

You are setting up the crew for this project. Work in `${CLAUDE_PROJECT_DIR}`.

1. **Scan, do not ask, for what the repo shows.** Languages and frameworks (project files, package manifests, lock files), app and service folders, test runners and their commands, scripts directory, CLAUDE.md, docs folders, git remote (tracker candidate), default branch, IaC and deploy scripts, identity provider, cloud SDKs, event store or messaging libraries.
2. **Read the template** `${CLAUDE_PLUGIN_ROOT}/templates/profile.md` and draft every line you can fill from the scan. Mark each role `disabled` when the repo shows no trace of that discipline; keep it enabled when in doubt and say so.
3. **Ask the user, in one AskUserQuestion call, only for:** mode (`optional` or `always`), roles to force on or off, exclusive lanes (shared clusters, databases, deploy targets), definition-of-done items beyond "gates green", and the tracker if the remote is ambiguous.
4. **Write** `.claude/crew/profile.md`. Keep it under 80 lines: link to CLAUDE.md sections instead of copying them; put repeated incidents in "Gotchas" as one line each with a pointer.
5. **Role addenda** only where the repo has rules a persona could not infer (for example a generated-copy rule for shared UI, a handler-registration rule for a worker): `.claude/crew/roles/<role>.md` from `${CLAUDE_PLUGIN_ROOT}/templates/role-addendum.md`, at most a few lines each.
6. **Tracker:** run `${CLAUDE_PLUGIN_ROOT}/scripts/tracker.sh ensure-labels` when the tracker is GitHub. Quote its output.
7. **CLAUDE.md pointer:** if CLAUDE.md lacks a "Crew" section, append five lines: crew profile location, how to enter crew mode, the pipeline commands, where personas live, and that the profile wins over persona defaults.
8. Report what was inferred, what was asked, and what you guessed. `--refresh` keeps the user's hand edits and only updates scanned lines.
