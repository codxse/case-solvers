#!/usr/bin/env bash
#
# lib.sh — host-agnostic helpers for the case-solvers test harness.
#
# Host-specific pieces (where the plugin is installed, how to sync the working
# tree onto it) live in claude/lib.sh and kimi/lib.sh; each test sources the
# lib.sh next to it, which in turn sources this file.

# Absolute path to the working-tree plugin root (the dir holding skills/, shared/,
# tests/). Resolved from this file's location (tests/lib.sh) so it works from any CWD.
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Absolute path to the working-tree repository root (the Kimi install copies the
# whole repo, not just the plugin dir).
REPO_ROOT="$(cd "$PLUGIN_ROOT/.." && pwd)"

# Classify output that means the trial never actually reached the model — a session
# or rate limit, an overloaded/API error, or empty output. Such a run proves nothing
# about the guard or the format, so the caller scores it ERROR (inconclusive), not a
# FAIL. Without this a mid-run usage-limit turns every remaining trial into a false
# guard failure. Prints a short reason and returns 0 when it IS an infra error.
infra_error() {
  local out="$1"
  [ -z "${out//[[:space:]]/}" ] && { printf 'empty output (no model response)'; return 0; }
  local re='session limit|usage limit|rate limit|(^|[^0-9])429([^0-9]|$)|overloaded|api error|service unavailable|temporarily unavailable|invalid api key|authentication_error|credit balance'
  if grep -qiE "$re" <<<"$out"; then
    printf 'availability/infra error: %s' "$(grep -ioE "$re" <<<"$out" | head -1)"
    return 0
  fi
  return 1
}
