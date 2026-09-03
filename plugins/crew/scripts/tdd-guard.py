#!/usr/bin/env python3
"""PreToolUse guard for Write/Edit: production code may only change when a test file has
changed first (modified, untracked, or in the last commit). Configured by the project profile:

    tdd: strict | advisory | off
    tdd-production: <comma-separated globs, ** supported>
    tdd-tests: <comma-separated globs>

strict denies the edit with a reason; advisory lets it through with a warning in context."""
import json, os, re, subprocess, sys

inp = json.load(sys.stdin)
cwd = inp.get("cwd") or os.getcwd()
file_path = (inp.get("tool_input") or {}).get("file_path") or ""
if not file_path:
    sys.exit(0)

profile = os.path.join(cwd, ".claude", "crew", "profile.md")
if not os.path.isfile(profile):
    sys.exit(0)


def value(key):
    with open(profile, encoding="utf-8") as f:
        for line in f:
            if line.startswith(key + ":"):
                return re.sub(r"\s+#.*$", "", line.split(":", 1)[1]).strip()
    return ""


mode = value("tdd") or "off"
if mode not in ("strict", "advisory"):
    sys.exit(0)


def globs(key):
    return [g.strip() for g in value(key).split(",") if g.strip()]


def matches(path, patterns):
    for p in patterns:
        rx = re.escape(p).replace(r"\*\*/", "(?:.*/)?").replace(r"\*\*", ".*").replace(r"\*", "[^/]*")
        if re.fullmatch(rx, path):
            return True
    return False


production, tests = globs("tdd-production"), globs("tdd-tests")
rel = os.path.relpath(os.path.abspath(file_path), cwd).replace(os.sep, "/")
if rel.startswith("..") or matches(rel, tests) or not matches(rel, production):
    sys.exit(0)


def git(*args):
    r = subprocess.run(["git", "-C", cwd, *args], capture_output=True, text=True)
    return r.stdout.splitlines() if r.returncode == 0 else []


changed = {l[3:].strip().strip('"') for l in git("status", "--porcelain", "--untracked-files=all")}
changed |= set(git("diff", "--name-only", "HEAD~1", "HEAD"))
if any(matches(c, tests) for c in changed):
    sys.exit(0)

reason = (
    f"TDD guard ({mode}): '{rel}' is production code, but no test file matching "
    f"[{', '.join(tests)}] is modified, untracked, or in the last commit. "
    "RED first: write the failing test, run it and quote the failure, then implement. "
    "The `tdd:` line in .claude/crew/profile.md controls this guard (/crew:tdd strict|advisory|off)."
)
out = {"hookSpecificOutput": {"hookEventName": "PreToolUse"}}
if mode == "strict":
    out["hookSpecificOutput"].update(permissionDecision="deny", permissionDecisionReason=reason)
else:
    out["hookSpecificOutput"]["additionalContext"] = reason
print(json.dumps(out))
