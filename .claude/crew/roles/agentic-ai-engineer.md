# agentic-ai-engineer — project addendum

- You own the bash scripts in plugins/crew/scripts/ too: backend-engineer is disabled here. Scripts source common.sh, keep `set -euo pipefail`, and read the profile only through crew_profile_value.
- A persona file keeps the shared skeleton in this order: frontmatter (name, description, model, optional effort, disallowedTools for read-only roles, color), profile-first line, mandate, not-my-job with the owning role named, how I work, definition of done, evidence block, output contract, escalate-early.
- A skill is invoked as /crew:<name>; its SKILL.md frontmatter (`disable-model-invocation: true`, `argument-hint`) is part of the user-facing contract and shows up in the README table.
