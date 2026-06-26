#!/usr/bin/env bash
#
# rubric-read.sh — verify /case actually READS the shared rubrics before authoring.
#
# The /case (and /refine) skills tell the architect to read
# shared/contract-rubrics.md before drafting a contract. authoring-format.sh only
# grades the *output shape*, which a planning model can approximate from memory
# without ever opening the file — so a silently-skipped (or silently-failing) read
# passes that test undetected. This harness closes that gap: it inspects the actual
# tool calls and asserts a NON-ERROR Read of contract-rubrics.md occurred.
#
# Why this matters: the skill points at the rubric by relative path
# (`../../shared/contract-rubrics.md`). A model that miscounts the `..` levels
# reads a path that does not exist, gets "File does not exist", and proceeds to
# author from memory — the rubric is effectively skipped with no visible error.
# This test catches exactly that.
#
# A trial PASSES when, in the run's tool stream, there is a Read whose file_path
# contains `contract-rubrics.md` AND whose tool_result is not an error. A trial
# FAILS when the rubric was never read, or every read of it errored (wrong path).
#
# Descriptions are greenfield and self-contained (a fresh `git init` has no
# codebase) so a planning model proceeds straight to authoring — the point in the
# flow where the rubric must already be loaded.
#
# Permission mode is bypassPermissions: the architect must Read files outside the
# temp repo (the rubric lives in the plugin dir) and may `bd init`; acceptEdits
# would prompt and stall.
#
# Usage:
#   tests/rubric-read.sh [-n TRIALS] [-m MODEL] [-v] [--no-sync]
#     -n  trials per description  (default 3)
#     -m  planning model alias    (default sonnet)
#     -v  verbose: print each trial's rubric-read verdict and raw output
#     --no-sync  skip overlaying the working tree onto the install
#
# Exit 0 only when every trial read the rubric. Calls the real model — slow,
# probabilistic.

set -u
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

TRIALS=3
MODEL=sonnet
VERBOSE=0
SYNC=1
while [ $# -gt 0 ]; do
  case "$1" in
    -n) TRIALS=$2; shift 2 ;;
    -m) MODEL=$2; shift 2 ;;
    -v) VERBOSE=1; shift ;;
    --no-sync) SYNC=0; shift ;;
    *) echo "usage: $0 [-n TRIALS] [-m MODEL] [-v] [--no-sync]" >&2; exit 2 ;;
  esac
done

DESCRIPTIONS=(
  "add a slugify utility that turns a title string into a url-safe slug: lowercase, trim, and collapse any run of non-alphanumeric characters into a single hyphen"
  "add a retry helper that re-runs a callable up to N times with a fixed delay between attempts, re-raising the last error if all attempts fail"
  "add a clamp helper that constrains a number to an inclusive min/max range"
)

PASS=0
FAIL=0
ERR=0
FAILLOG=$(mktemp)

# Inspect a stream-json transcript and classify the rubric read. Prints exactly one
# verdict token on the last line: READ_OK | READ_ERR | NO_READ — plus diagnostic
# lines above it. Reads the jsonl path as $1.
verdict() {
python3 - "$1" <<'PY'
import json, sys
path = sys.argv[1]
reads = {}        # tool_use_id -> file_path (rubric reads only)
results = {}      # tool_use_id -> is_error (bool)
for line in open(path, errors="replace"):
    line = line.strip()
    if not line:
        continue
    try:
        ev = json.loads(line)
    except Exception:
        continue
    msg = ev.get("message", {})
    content = msg.get("content")
    if not isinstance(content, list):
        continue
    for blk in content:
        if not isinstance(blk, dict):
            continue
        if blk.get("type") == "tool_use" and blk.get("name") == "Read":
            fp = (blk.get("input") or {}).get("file_path", "") or ""
            if "contract-rubrics.md" in fp:
                reads[blk.get("id")] = fp
        elif blk.get("type") == "tool_result":
            results[blk.get("tool_use_id")] = bool(blk.get("is_error"))

if not reads:
    print("rubric never read")
    print("NO_READ")
    sys.exit(0)

ok = [fp for tid, fp in reads.items() if not results.get(tid, False)]
err = [fp for tid, fp in reads.items() if results.get(tid, False)]
for fp in err:
    print("read ERRORED:", fp)
for fp in ok:
    print("read OK:", fp)
print("READ_OK" if ok else "READ_ERR")
PY
}

run_trial() {
  local desc="$1" dir jsonl out v tok
  dir=$(mktemp -d)
  jsonl="$dir/.stream.jsonl"
  ( cd "$dir" && git init -q )
  ( cd "$dir" && timeout 300 claude -p "/case $desc" \
      --model "$MODEL" --permission-mode bypassPermissions \
      --output-format stream-json --verbose >"$jsonl" 2>&1 )
  out=$(cat "$jsonl")

  local infra
  if infra=$(infra_error "$out"); then
    rm -rf "$dir"
    printf '\n--- ERROR [%s] /case %s\n    %s\n' "$MODEL" "$desc" "$infra" >>"$FAILLOG"
    [ "$VERBOSE" -eq 1 ] && printf '  ERROR: %s\n' "$infra"
    return 2
  fi

  v=$(verdict "$jsonl")
  tok=$(tail -1 <<<"$v")

  if [ "$VERBOSE" -eq 1 ]; then
    printf '    --- rubric-read verdict ---\n'
    sed 's/^/    | /' <<<"$v"
  fi
  rm -rf "$dir"

  if [ "$tok" = READ_OK ]; then
    [ "$VERBOSE" -eq 1 ] && printf '  PASS\n'
    return 0
  fi
  {
    printf '\n--- FAIL [%s] /case %s\n' "$MODEL" "$desc"
    printf '    verdict: %s\n' "$tok"
    sed 's/^/    | /' <<<"$v"
  } >>"$FAILLOG"
  [ "$VERBOSE" -eq 1 ] && printf '  FAIL: %s\n' "$tok"
  return 1
}

[ "$SYNC" -eq 1 ] && { sync_plugin || exit 1; }

echo "rubric-read: model=$MODEL trials/desc=$TRIALS  descriptions=${#DESCRIPTIONS[@]}"

for d in "${DESCRIPTIONS[@]}"; do
  printf 'case: %s\n' "$d"
  for i in $(seq 1 "$TRIALS"); do
    printf '  trial %d/%d ... ' "$i" "$TRIALS"
    run_trial "$d"; rc=$?
    case "$rc" in
      0) PASS=$((PASS+1)); [ "$VERBOSE" -eq 0 ] && echo PASS ;;
      2) ERR=$((ERR+1));  [ "$VERBOSE" -eq 0 ] && echo ERROR ;;
      *) FAIL=$((FAIL+1)); [ "$VERBOSE" -eq 0 ] && echo FAIL ;;
    esac
  done
done

TOTAL=$((PASS+FAIL+ERR))
echo
echo "result: $PASS/$TOTAL passed, $FAIL failed, $ERR inconclusive (infra)"
if [ "$FAIL" -gt 0 ]; then
  cat "$FAILLOG"; rm -f "$FAILLOG"; exit 1
fi
if [ "$ERR" -gt 0 ]; then
  cat "$FAILLOG"; rm -f "$FAILLOG"
  echo "no rubric-read FAILs, but $ERR trial(s) never reached the model — re-run after the limit/outage clears."
  exit 2
fi
rm -f "$FAILLOG"
echo "all trials read the shared rubrics."
