#!/usr/bin/env bash
# Shared helpers for crew scripts. Source it; do not execute.

crew_data_dir() { echo "${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/crew}"; }
crew_profile_path() { echo "${1:-$PWD}/.claude/crew/profile.md"; }

# crew_profile_value <profile-file> <key>  -> value with trailing "# comment" stripped
crew_profile_value() {
  [ -f "$1" ] || return 0
  grep -E "^$2:" "$1" | head -1 | sed -E "s/^$2:[[:space:]]*//; s/[[:space:]]+#.*$//; s/[[:space:]]+$//"
}

crew_marker() { echo "$(crew_data_dir)/sessions/$1"; }
crew_mode_is_on() { [ -n "$1" ] && [ -f "$(crew_marker "$1")" ]; }
