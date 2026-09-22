#!/usr/bin/env bash
set -euo pipefail

label="${1:-Xcode}"
shift || true
if [[ "${1:-}" == "--" ]]; then
  shift
fi

mkdir -p .build/logs
slug="$(printf '%s' "$label" | tr '[:upper:] ' '[:lower:]-' | tr -cd '[:alnum:]_-')"
log=".build/logs/${slug:-xcode}.log"
start=$SECONDS

printf '      %s\n' "$label"

set +e
if [[ "${AIRBATTERY_XCODE_VERBOSE:-0}" == "1" ]]; then
  xcodebuild "$@" 2>&1 | tee "$log"
  status=${PIPESTATUS[0]}
elif [[ "${AIRBATTERY_XCODE_BEAUTIFY:-0}" == "1" ]] &&
     command -v xcbeautify >/dev/null 2>&1; then
  xcodebuild "$@" 2>&1 | tee "$log" | xcbeautify
  status=${PIPESTATUS[0]}
else
  xcodebuild "$@" 2>&1 | tee "$log" | awk '
    /:[[:space:]]*(error|warning):/ ||
    /^error:/ || /^warning:/ ||
    /^Test Suite .* (passed|failed) at/ ||
    /^Test Case .* failed/ ||
    /^Executed [0-9]+ test/ ||
    /^\*\* (BUILD|TEST) (SUCCEEDED|FAILED) \*\*/ {
      print
      fflush()
      next
    }
    /^Build Timing Summary/ {
      timing = 1
      print
      fflush()
      next
    }
    timing && /seconds/ {
      print
      fflush()
    }
  '
  status=${PIPESTATUS[0]}
fi
set -e

elapsed=$((SECONDS - start))
if [[ "$status" -eq 0 ]]; then
  printf '      ✓ %s (%ss)\n' "$label" "$elapsed"
else
  printf '      ✗ %s failed (%ss)\n' "$label" "$elapsed" >&2
  printf '        Full log: %s\n' "$log" >&2
  if [[ "${AIRBATTERY_XCODE_VERBOSE:-0}" != "1" ]]; then
    printf '%s\n' '        Last diagnostics:' >&2
    grep -E ':[[:space:]]*(error|warning):|^error:|^warning:|\*\* (BUILD|TEST) FAILED \*\*' "$log" | tail -n 40 >&2 || true
  fi
  exit "$status"
fi
