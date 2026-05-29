#!/usr/bin/env bash
# Path-agnostic Git Bash launcher for Arclen hooks.
#
# WHY: Claude Code runs hook commands via `bash -c "<command>"`. On this Windows
# machine the bare `bash` on PATH is C:\Windows\System32\bash.exe (WSL), which
# (a) has NO jq — every Arclen hook needs jq — and (b) silently differs from the
# Git Bash the scripts assume. Git Bash has jq. So: if the shell running this
# launcher lacks jq, re-exec the target script under Git Bash.
#
# Path-agnostic across both PCs: probes Git Bash at system-level (Program Files)
# and user-level (LOCALAPPDATA\Programs\Git, any username via glob), under BOTH
# the Git-Bash mount prefix (/c/...) and the WSL mount prefix (/mnt/c/...).
#
# Forward slashes ONLY in the settings.json command that calls this — `bash -c`
# strips backslashes (`.claude\hooks\run.sh` -> `.claudehooksrun.sh`).
#
# Usage (.claude/settings.json):
#   "command": "bash .claude/hooks/run.sh .claude/hooks/<script>.sh"
# stdin (the hook JSON), args, and exit code pass through transparently.

set -u
target="${1:-}"
[ -z "$target" ] && { echo "run.sh: no target script given" >&2; exit 0; }
shift

# Current shell already has jq (i.e. we're in Git Bash) -> just run it.
if command -v jq >/dev/null 2>&1; then
  exec bash "$target" "$@"
fi

# No jq here (WSL). Re-exec under Git Bash. Guard against an exec loop.
if [ "${ARCLEN_HOOK_REEXEC:-}" = "1" ]; then
  echo "run.sh: jq still unavailable after re-exec into Git Bash" >&2
  exit 0
fi
export ARCLEN_HOOK_REEXEC=1

for gb in \
  "/c/Program Files/Git/bin/bash.exe" \
  "/mnt/c/Program Files/Git/bin/bash.exe" \
  /c/Users/*/AppData/Local/Programs/Git/bin/bash.exe \
  /mnt/c/Users/*/AppData/Local/Programs/Git/bin/bash.exe ; do
  if [ -x "$gb" ]; then
    exec "$gb" "$target" "$@"
  fi
done

echo "run.sh: Git Bash (with jq) not found; hook skipped" >&2
exit 0
