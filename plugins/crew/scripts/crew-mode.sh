#!/usr/bin/env bash
# Purpose: switch crew mode on/off for one Claude Code session (marker per session id).
# Usage:   crew-mode.sh on|off|status <session-id>
set -euo pipefail
. "$(dirname "$0")/common.sh"
cmd=${1:-status}; sid=${2:-}
[ -n "$sid" ] || { echo "usage: crew-mode.sh on|off|status <session-id>" >&2; exit 1; }
m=$(crew_marker "$sid")
case "$cmd" in
  on)  mkdir -p "$(dirname "$m")"; date -Is > "$m"; echo "crew mode ON for session $sid" ;;
  off) rm -f "$m"; echo "crew mode OFF for session $sid" ;;
  status) if crew_mode_is_on "$sid"; then echo on; else echo off; fi ;;
  *) echo "unknown command: $cmd" >&2; exit 1 ;;
esac
