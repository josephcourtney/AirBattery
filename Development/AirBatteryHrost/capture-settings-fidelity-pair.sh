#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$ROOT"

CASES="$ROOT/Development/AirBatteryHrost/fidelity-settings.screen-sharing.txt"
CANDIDATE="$ROOT/Development/AirBatteryHrost/capture-screen-sharing.sh"
REFERENCE="$ROOT/Development/AirBatteryHrost/capture-production-screen-sharing.sh"
COMPARE_EXEC="$ROOT/.build/out/Products/Debug/AirBatteryHrost.app/Contents/MacOS/AirBatteryHrost"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
PAIR_ROOT="${AIRBATTERY_HROST_PAIR_OUTPUT:-$ROOT/.hrost/fidelity-pairs/$STAMP}"
CANDIDATE_DIR="$PAIR_ROOT/candidate"
REFERENCE_DIR="$PAIR_ROOT/reference"
COMPARISON_DIR="$PAIR_ROOT/comparison"
ARCHIVE="$PAIR_ROOT.zip"

mkdir -p "$CANDIDATE_DIR" "$REFERENCE_DIR" "$COMPARISON_DIR"

printf '\n=== Hrost host (candidate) ===\n'
AIRBATTERY_HROST_CASES="$CASES" \
    bash "$CANDIDATE" "$@" --output-dir "$CANDIDATE_DIR"

printf '\n=== Production host (reference) ===\n'
AIRBATTERY_HROST_CASES="$CASES" \
    bash "$REFERENCE" "$@" --output-dir "$REFERENCE_DIR"

[[ -x "$COMPARE_EXEC" ]] || {
    printf 'AirBatteryHrost: comparison executable not found: %s\n' "$COMPARE_EXEC" >&2
    exit 2
}

printf '\n=== Comparisons ===\n'
shopt -s nullglob
candidate_files=("$CANDIDATE_DIR"/*.hrostcapture)
(( ${#candidate_files[@]} > 0 )) || {
    printf 'AirBatteryHrost: no candidate captures found in %s\n' "$CANDIDATE_DIR" >&2
    exit 2
}

for candidate_file in "${candidate_files[@]}"; do
    name="$(basename "$candidate_file")"
    stem="${name%.hrostcapture}"
    reference_file="$REFERENCE_DIR/$name"
    [[ -f "$reference_file" ]] || {
        printf 'AirBatteryHrost: matching reference capture not found: %s\n' "$reference_file" >&2
        exit 2
    }

    printf '\n%s\n' "$name"
    "$COMPARE_EXEC" compare \
        --candidate "$candidate_file" \
        --reference "$reference_file"
    "$COMPARE_EXEC" compare \
        --candidate "$candidate_file" \
        --reference "$reference_file" \
        --json > "$COMPARISON_DIR/$stem.json"
done

rm -f "$ARCHIVE"
/usr/bin/ditto -c -k --keepParent "$PAIR_ROOT" "$ARCHIVE"

printf '\n=== Fidelity pair ===\n'
printf 'candidate:  %s\n' "$CANDIDATE_DIR"
printf 'reference:  %s\n' "$REFERENCE_DIR"
printf 'comparison: %s\n' "$COMPARISON_DIR"
printf 'archive:    %s\n' "$ARCHIVE"
