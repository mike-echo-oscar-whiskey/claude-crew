#!/usr/bin/env bash
# SessionStart hook: injects the crew operating model when crew mode is on (per-session
# marker, or profile `mode: always`), otherwise a one-line availability note.
set -euo pipefail
. "$(dirname "$0")/common.sh"
input=$(cat)
sid=$(jq -r '.session_id // empty' <<<"$input")
cwd=$(jq -r '.cwd // empty' <<<"$input"); cwd=${cwd:-$PWD}
profile=$(crew_profile_path "$cwd")
root=$(cd "$(dirname "$0")/.." && pwd)

if [ ! -f "$profile" ]; then
  echo "Crew plugin: no .claude/crew/profile.md in this project. Run /crew:init to create one; until then personas fall back to what the repository shows."
  exit 0
fi

mode=$(crew_profile_value "$profile" mode)
if [ "$mode" = "always" ] && [ -n "$sid" ] && ! crew_mode_is_on "$sid"; then
  "$root/scripts/crew-mode.sh" on "$sid" >/dev/null
fi

if crew_mode_is_on "$sid"; then
  cat "$root/templates/operating-model.md"
  echo
  echo "## Project profile (.claude/crew/profile.md)"
  echo
  cat "$profile"
else
  echo "Crew plugin available (profile present, crew mode off). /crew:on = full delivery-lead mode for this session; /crew:refine, /crew:plan #n, /crew:work #n, /crew:review <pr>, /crew:next, /crew:status = pipeline steps; mention @agent-crew:<role> for a single specialist consult. Roles and stack bindings: .claude/crew/profile.md."
fi
