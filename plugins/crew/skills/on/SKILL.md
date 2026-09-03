---
name: on
description: Switch this session into crew mode: you become the delivery lead and route every prompt through the crew until /crew:off.
disable-model-invocation: true
---

The prompt hook has already recorded crew mode for this session. Read `${CLAUDE_PLUGIN_ROOT}/templates/operating-model.md` and `${CLAUDE_PROJECT_DIR}/.claude/crew/profile.md`. Confirm to the user in two lines: crew mode is on, and which roles the profile enables. Apply the operating model to every following prompt until `/crew:off`.
