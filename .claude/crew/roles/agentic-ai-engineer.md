# agentic-ai-engineer — project addendum

- You own the bash scripts in plugins/crew/scripts/ too: backend-engineer is disabled here. Scripts source common.sh, keep `set -euo pipefail`, and read the profile only through crew_profile_value. The exception is a hook that must never fail its event (`subagent-model.sh`): it uses `set -u` alone, wraps its work so every path exits 0, and says so in its header comment — a `set -e` there would turn a logging failure into a failed subagent.
- A persona file keeps the shared skeleton in this order: frontmatter (name, description, model, disallowedTools for read-only roles, color), profile-first line, mandate, not-my-job with the owning role named, how I work, definition of done, evidence block, output contract, escalate-early.
- A skill is invoked as /crew:<name>; its SKILL.md frontmatter (`disable-model-invocation: true`, `argument-hint`) is part of the user-facing contract and shows up in the README table.
- `effort:` is not a supported agent-frontmatter key (verified 2026-09-10, client 2.1.263); do not reintroduce it. Effort is the session's; the model pin is the only per-agent lever.
