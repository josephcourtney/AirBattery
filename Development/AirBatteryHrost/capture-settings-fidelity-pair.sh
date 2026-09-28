#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$ROOT"

CASES="$ROOT/Development/AirBatteryHrost/fidelity-settings.screen-sharing.txt"
CANDIDATE="$ROOT/Development/AirBatteryHrost/capture-screen-sharing.sh"
REFERENCE="$ROOT/Development/AirBatteryHrost/capture-production-screen-sharing.sh"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
PAIR_ROOT="${AIRBATTERY_HROST_PAIR_OUTPUT:-$ROOT/.hrost/fidelity-pairs/$STAMP}"
CANDIDATE_DIR="$PAIR_ROOT/candidate"
REFERENCE_DIR="$PAIR_ROOT/reference"
ARCHIVE="$PAIR_ROOT.zip"

mkdir -p "$CANDIDATE_DIR" "$REFERENCE_DIR"

printf '\n=== Hrost host (candidate) ===\n'
AIRBATTERY_HROST_CASES="$CASES" \
    bash "$CANDIDATE" "$@" --output-dir "$CANDIDATE_DIR"

printf '\n=== Production host (reference) ===\n'
AIRBATTERY_HROST_CASES="$CASES" \
    bash "$REFERENCE" "$@" --output-dir "$REFERENCE_DIR"

rm -f "$ARCHIVE"
/usr/bin/ditto -c -k --keepParent "$PAIR_ROOT" "$ARCHIVE"

printf '\n=== Fidelity pair ===\n'
printf 'candidate: %s\n' "$CANDIDATE_DIR"
printf 'reference: %s\n' "$REFERENCE_DIR"
printf 'archive:   %s\n' "$ARCHIVE"
