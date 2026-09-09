# claude-crew

## Crew

- Crew profile: `.claude/crew/profile.md` (roles, commands, definition of done, triage); role addenda in `.claude/crew/roles/`.
- Enter crew mode with `/crew:on` (leave with `/crew:off`); the session then acts as delivery lead and delegates to `crew:<role>` agents.
- Pipeline: `/crew:refine` → `/crew:plan #story` → `/crew:work #task` → `/crew:review <pr>`; `/crew:next` and `/crew:status` for the board.
- Personas live in `plugins/crew/agents/`; this repository is the plugin itself, so the installed cache copy is not the checkout.
- The profile wins over persona defaults on every point.
