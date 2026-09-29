#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$ROOT"

CASES="$ROOT/Development/AirBatteryHrost/fidelity-settings.screen-sharing.txt"
REPLAY="$ROOT/Development/AirBatteryHrost/capture-screen-sharing.sh"
REFERENCE="$ROOT/Development/AirBatteryHrost/capture-production-screen-sharing.sh"
RUNNER="$ROOT/Development/AirBatteryHrost/run.sh"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
PAIR_ROOT="${AIRBATTERY_HROST_REPLAY_OUTPUT:-$ROOT/.hrost/replay-pairs/$STAMP}"
REPLAY_DIR="$PAIR_ROOT/replay"
REFERENCE_DIR="$PAIR_ROOT/reference"
COMPARISON_DIR="$PAIR_ROOT/comparison"
ARCHIVE="$PAIR_ROOT.zip"

mkdir -p "$REPLAY_DIR" "$REFERENCE_DIR" "$COMPARISON_DIR"

printf '\n=== Production host (record presentation state) ===\n'
AIRBATTERY_HROST_CASES="$CASES" \
    bash "$REFERENCE" "$@" \
    --capture-arg --record-state \
    --output-dir "$REFERENCE_DIR"

printf '\n=== Hrost host (replay recorded state) ===\n'
AIRBATTERY_HROST_CASES="$CASES" \
    bash "$REPLAY" "$@" \
    --replay-reference-dir "$REFERENCE_DIR" \
    --output-dir "$REPLAY_DIR"

# Prepare a fresh local Hrost host for comparison. The isolated replay app has
# already been built above, but refreshing here also makes this script robust to
# future changes in how capture-screen-sharing stages its app bundle.
COMPARE_APP="$ROOT/.build/out/Products/Debug/AirBatteryHrost.app"
COMPARE_EXEC="$COMPARE_APP/Contents/MacOS/AirBatteryHrost"
HROST_PATH="${HROST_PATH:-../hrost}" bash "$RUNNER" --prepare-only >/dev/null
[[ -x "$COMPARE_EXEC" ]] || {
    printf 'AirBatteryHrost: comparison executable not found: %s\n' "$COMPARE_EXEC" >&2
    exit 2
}
COMPARE_FRAMEWORKS="$COMPARE_APP/Contents/Frameworks"
COMPARE_BIN_DIR="$(dirname "$COMPARE_APP")"

run_compare() {
    DYLD_FRAMEWORK_PATH="$COMPARE_FRAMEWORKS:$COMPARE_BIN_DIR${DYLD_FRAMEWORK_PATH:+:$DYLD_FRAMEWORK_PATH}" \
    DYLD_LIBRARY_PATH="$COMPARE_FRAMEWORKS:$COMPARE_BIN_DIR${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}" \
        "$COMPARE_EXEC" "$@"
}

printf '\n=== Replay comparisons ===\n'
shopt -s nullglob
replay_files=("$REPLAY_DIR"/*.hrostcapture)
(( ${#replay_files[@]} > 0 )) || {
    printf 'AirBatteryHrost: no replay captures found in %s\n' "$REPLAY_DIR" >&2
    exit 2
}

for replay_file in "${replay_files[@]}"; do
    name="$(basename "$replay_file")"
    stem="${name%.hrostcapture}"
    reference_file="$REFERENCE_DIR/$name"
    artifact_dir="$COMPARISON_DIR/$stem"
    [[ -f "$reference_file" ]] || {
        printf 'AirBatteryHrost: matching recorded reference not found: %s\n' "$reference_file" >&2
        exit 2
    }

    rm -rf "$artifact_dir"
    mkdir -p "$artifact_dir"

    compare_args=(
        compare
        --candidate "$replay_file"
        --reference "$reference_file"
        --output-dir "$artifact_dir"
    )
    if [[ -n "${AIRBATTERY_HROST_COMPARISON_PROFILE:-}" ]]; then
        compare_args+=(--profile "$AIRBATTERY_HROST_COMPARISON_PROFILE")
    fi

    printf '\n%s\n' "$name"
    run_compare "${compare_args[@]}"
done

rm -f "$ARCHIVE"
/usr/bin/ditto -c -k --keepParent "$PAIR_ROOT" "$ARCHIVE"

printf '\n=== Record/replay pair ===\n'
printf 'replay:     %s\n' "$REPLAY_DIR"
printf 'reference:  %s\n' "$REFERENCE_DIR"
printf 'comparison: %s\n' "$COMPARISON_DIR"
printf 'archive:    %s\n' "$ARCHIVE"
