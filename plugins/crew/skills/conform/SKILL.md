---
name: conform
description: "Bring a board filed before the item shape to it in one reviewed pass: the countable fixes drafted with no role, the new text briefed to the role that owns each item, and every change shown to you as a diff and written only once you agree."
argument-hint: "[<n> | --all]"
disable-model-invocation: true
---

You are the delivery lead for a one-off pass. Target: `$ARGUMENTS` — one item number, or `--all` for the whole board; no argument behaves as `--all`. Read the profile at `${CLAUDE_PROJECT_DIR}/.claude/crew/profile.md` for the tracker, the roles, `generated:` and `size-cap:`. `T=${CLAUDE_PLUGIN_ROOT}/scripts/tracker.sh`.

Two rules hold over every step. **No item is ever refused, reshaped or unclaimed for being old** — a claim warns about a non-conforming body and continues, so this pass is a convenience and never a gate anyone must pass first. **Nothing on the board is edited before step 4 has shown you the diff and you have said yes** — no silent rewrite, no background sweep, not even for a one-character header.

1. **List what fails.** Run `bash $T lint --all` (`lint <n>` for a single item) and quote it whole: one line per failing item as `#<n>`, its kind, then its failing checks, closing with `N conforming, M not`. Exit 1 only means M is not 0; it is the report working. Stop and say so when M is 0. The checks come from each kind's resolved shape, so resolve it the way `/crew:plan` does and name which one you got: `${CLAUDE_PROJECT_DIR}/.claude/crew/items/<kind>.md` — the project's override, which wins whole — else `${CLAUDE_PLUGIN_ROOT}/templates/item-<kind>.md`.

2. **Draft the countable fixes yourself, with no role.** Fetch each failing body with `bash $T show <n>` and write only what the body already decides:
   - `Size:` — the `## Files` list counted. H is the hand-written count, G the entries matching the profile's `generated:` globs; absent or `-`, every entry counts toward H.
   - the literal first line `Story: <sigil><n>` for a task that lacks it, taken from the story whose `## Tasks` checklist lists that task. When no story lists it, that is a question for step 4, never a guess.
   - the `## Proof map` skeleton for a story: one row per criterion id in the body, with Task and Proven by left empty.
   - the `## Proves` line for a task whose body already cites criteria in prose — copy the ids it names and invent none.
   - a **flag, not an edit**, when the counted H is above the profile's `size-cap:` (absent: 15, `-`: no cap): the item needs a `Split line:` and a split before it starts. Never split an item yourself; it is work the old shape was hiding and the split is its own decision.

   Everything else — a TL;DR, a why-it-matters, a done-when, a criterion's text, a split's seam — is new prose a machine cannot write. Do not write it here.

3. **Brief the owning role for the text, one item per brief.** For each item still missing a section after step 2, dispatch the role that owns the kind — `crew:product-owner` for a story, `crew:architect` for a task, bug or tech-debt — on the cheapest tier that can do the job, in parallel across items. Each brief carries that one item's body, its failing check lines and the resolved template, and **nothing else**: no second item, no board summary, no history of the pass. Ask for the missing sections as text to paste and for nothing the body does not support — a role that cannot tell says so, and the item arrives at step 4 as a question rather than as an invented sentence.

4. **Show a diff per item and wait.** Per item, present the failing checks, the current body against the proposed one as a unified diff, which parts came from step 2 and which from a role, and every question left open. Then **stop and wait for the user**, item by item: there is no batch yes. Apply only what is approved — `gh issue edit <n> --body-file <f>` for the body, then `bash $T comment <n> --body-file <f>` for a short note saying which sections this pass changed and that it was proposed and approved, not swept in. Leave a declined item exactly as it stands and record the decline; never touch its labels, its assignee or its claim.

5. **Report** in four lists: what now conforms, what needs a split (each with its counted H and the cap), what a role could not answer, and what the user declined. Close by re-running `bash $T lint --all` and quoting its closing line as the after-count, and note that a declined or split-pending item will keep appearing in `/crew:status`'s `items:` line until it is dealt with — which is the point, not a failure.
