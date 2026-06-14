#!/usr/bin/env bash
#
# lib.sh — shared helpers for the case-solvers test harness.
#
# Headless `claude -p` loads the *installed* plugin copy (under
# ~/.claude/plugins/cache/...), never this working tree. Rather than make the
# operator remember to `cp` each edited SKILL.md into the cache, the harness
# syncs the whole working-tree plugin into the active install before every run.
# That is what `sync_plugin` does — call it once at the top of a test.

# Absolute path to the working-tree plugin root (the dir holding skills/, shared/,
# tests/). Resolved from this file's location (tests/lib.sh) so it works from any CWD.
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Resolve the install path that `claude -p` actually loads for this plugin, from
# the user's plugin registry. Falls back to the highest version dir in the cache.
resolve_install_path() {
  local reg="$HOME/.claude/plugins/installed_plugins.json"
  local p=""
  if [ -f "$reg" ] && command -v jq >/dev/null 2>&1; then
    p=$(jq -r '.plugins["case-solvers@case-solvers"][0].installPath // empty' "$reg" 2>/dev/null)
  fi
  if [ -z "$p" ]; then
    p=$(ls -d "$HOME"/.claude/plugins/cache/case-solvers/case-solvers/*/ 2>/dev/null | sort -V | tail -1)
  fi
  printf '%s' "${p%/}"
}

# Overlay the working tree onto the active install so the next `claude -p` run
# exercises the edits in this checkout. Overlay (no --delete) keeps Claude's own
# .in_use bookkeeping intact; every current skill/shared file is overwritten.
sync_plugin() {
  local dst
  dst="$(resolve_install_path)"
  if [ -z "$dst" ] || [ ! -d "$dst" ]; then
    echo "sync_plugin: cannot find an installed case-solvers copy to sync into." >&2
    echo "  install it once with the Claude plugin manager, then re-run." >&2
    return 1
  fi
  rsync -a --exclude='.in_use' --exclude='.git' "$PLUGIN_ROOT/" "$dst/" || return 1
  echo "synced working tree → $dst"
}

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
