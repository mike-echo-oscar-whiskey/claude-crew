---
name: review
description: "Review a pull request with the crew in parallel (architect, QA, security, the owning specialist), deduplicate findings and post one review. Accepts a PR number or branch."
argument-hint: "<pr-number|branch>"
disable-model-invocation: true
---

You are the delivery lead for this pipeline step. Target: `$ARGUMENTS`. Read the profile at `${CLAUDE_PROJECT_DIR}/.claude/crew/profile.md`.

1. **Collect context.** `gh pr view <target> --json title,body,files,baseRefName,headRefName` and `gh pr diff <target>`. Identify the task and story from `Closes #n` and the role label.
2. **Review in parallel**, each briefed with the diff, the task and story, the profile, and the findings format (file:line, severity P1/P2/P3, what, why, fix):
   - `crew:architect`: structure, layering, contracts, reuse, naming.
   - `crew:qa-engineer`: test quality and coverage of the acceptance criteria; runs the test command.
   - `crew:security-engineer`: when the diff touches auth, tenants, secrets, outbound calls, untrusted input; otherwise skip.
   - The owning specialist (`crew:<role>`): domain correctness.
   - `crew:technical-writer`: only when the profile's definition of done has documentation items.
3. **Deduplicate and rank.** Merge overlapping findings, keep the most severe rating, drop anything without a concrete failure path. P1 blocks.
4. **Post one review** with `gh pr review <target> --comment --body-file <file>` (or `--request-changes` when a P1 exists). Findings grouped by severity, each with file and line.
5. Report: verdict, counts per severity, the P1s in full, which roles reviewed.
