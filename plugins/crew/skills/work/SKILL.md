---
name: work
description: "Claim a task issue, work it in an isolated branch with the owning specialist implementing test-first, QA and (when relevant) security reviewing, run the project's gates, commit and open a PR that closes the task. Requires a task issue number."
argument-hint: "#<task-number>"
disable-model-invocation: true
---

You are the delivery lead for this pipeline step. Task: `$ARGUMENTS`. Read the operating model at `${CLAUDE_PLUGIN_ROOT}/templates/operating-model.md` and the profile at `${CLAUDE_PROJECT_DIR}/.claude/crew/profile.md`. `T=${CLAUDE_PLUGIN_ROOT}/scripts/tracker.sh`.

1. **Fetch and claim.** `$T show <n>`; confirm the role label and that `Blocked by` issues are closed. `$T claim <n>` — if it refuses (already claimed), stop and tell the user who holds it.
2. **Isolate.** If not already on a task branch, use EnterWorktree (or `git worktree`) with the profile's branch pattern, from the default branch, freshly pulled. Never work on the default branch.
3. **Implement.** Brief the owning role (`crew:<role>` from the label) with: the task body, the story, the design location, the profile's commands and gotchas, the requirement to work test-first, and the output contract. Run it. If it returns hand-offs, brief those roles; sequence them.
4. **Review.** In parallel: `crew:qa-engineer` reviews the tests and runs the profile's test command; `crew:security-engineer` when the task or story touches auth, tenants, secrets, outbound calls or untrusted input; the profile's specialist when the change crosses their domain. Feed findings back to the owning role once; a second round goes to the user.
5. **Gates and done.** Run the profile's `gates:` command yourself, bare, and quote the exit code. Walk the profile's definition of done item by item and state each. Missing items: brief `crew:technical-writer` or the owning role; do not skip them.
6. **Commit and PR.** Commit per the user's git rules (check `git config user.name` and `user.email` first). Push the branch. Open a PR with `gh pr create` whose body follows the user's PR format and contains `Closes #<n>`; mention the story number. `$T release <n> --to in-review`.
7. If blocked at any step: `$T release <n> --to blocked` with a comment explaining why, and report.
8. Report: PR link, roles and their one-line contributions, gate output, remaining open questions. Merging is the user's.
