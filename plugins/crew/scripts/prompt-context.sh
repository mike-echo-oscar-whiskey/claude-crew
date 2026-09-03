#!/usr/bin/env bash
# UserPromptSubmit hook: handles /crew:on and /crew:off, and while crew mode is on adds a
# short routing reminder to every prompt.
set -euo pipefail
. "$(dirname "$0")/common.sh"
input=$(cat)
sid=$(jq -r '.session_id // empty' <<<"$input")
prompt=$(jq -r '.prompt // empty' <<<"$input")
root=$(cd "$(dirname "$0")/.." && pwd)
[ -n "$sid" ] || exit 0

case "$prompt" in
  /crew:on*)  "$root/scripts/crew-mode.sh" on "$sid" >/dev/null
              echo "Crew mode is now ON for this session. Read the operating model at $root/templates/operating-model.md and the project profile at .claude/crew/profile.md, confirm to the user in two lines, and apply the model to every following prompt."
              exit 0 ;;
  /crew:off*) "$root/scripts/crew-mode.sh" off "$sid" >/dev/null
              echo "Crew mode is now OFF for this session. Confirm to the user in one line and work normally from here."
              exit 0 ;;
esac

if crew_mode_is_on "$sid"; then
  echo "Crew mode ON: you are the delivery lead. First line of your reply names the role(s) you engage (subagent type crew:<role>) and why, sized by the profile's triage table. Do not do specialist work yourself. Complete briefs (template in the operating model). Claim tracker issues before working them."
fi
