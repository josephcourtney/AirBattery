#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$ROOT"

COMPARE_ONLY=0
if [[ "${1:-}" == "--compare-only" ]]; then
    COMPARE_ONLY=1
    shift
fi

CASES="$ROOT/Development/AirBatteryHrost/fidelity-settings.screen-sharing.txt"
CANDIDATE="$ROOT/Development/AirBatteryHrost/capture-screen-sharing.sh"
REFERENCE="$ROOT/Development/AirBatteryHrost/capture-production-screen-sharing.sh"
RUNNER="$ROOT/Development/AirBatteryHrost/run.sh"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
PAIR_ROOT="${AIRBATTERY_HROST_PAIR_OUTPUT:-$ROOT/.hrost/fidelity-pairs/$STAMP}"
CANDIDATE_DIR="$PAIR_ROOT/candidate"
REFERENCE_DIR="$PAIR_ROOT/reference"
COMPARISON_DIR="$PAIR_ROOT/comparison"
ARCHIVE="$PAIR_ROOT.zip"

if (( ! COMPARE_ONLY )); then
    mkdir -p "$CANDIDATE_DIR" "$REFERENCE_DIR" "$COMPARISON_DIR"

    printf '\n=== Hrost host (candidate) ===\n'
    AIRBATTERY_HROST_CASES="$CASES" \
        bash "$CANDIDATE" "$@" --output-dir "$CANDIDATE_DIR"

    printf '\n=== Production host (reference) ===\n'
    AIRBATTERY_HROST_CASES="$CASES" \
        bash "$REFERENCE" "$@" --output-dir "$REFERENCE_DIR"
else
    [[ -d "$CANDIDATE_DIR" ]] || {
        printf 'AirBatteryHrost: candidate directory not found: %s\n' "$CANDIDATE_DIR" >&2
        exit 2
    }
    [[ -d "$REFERENCE_DIR" ]] || {
        printf 'AirBatteryHrost: reference directory not found: %s\n' "$REFERENCE_DIR" >&2
        exit 2
    }
    mkdir -p "$COMPARISON_DIR"
fi

# The development app is intentionally self-contained, but its SwiftPM-built
# executable still uses @rpath for dynamic products such as Sparkle. The normal
# run.sh path supplies these search paths; do the same here rather than executing
# the app binary with a bare dyld environment.
COMPARE_APP="$ROOT/.build/out/Products/Debug/AirBatteryHrost.app"
COMPARE_EXEC="$COMPARE_APP/Contents/MacOS/AirBatteryHrost"
if [[ ! -x "$COMPARE_EXEC" ]]; then
    HROST_PATH="${HROST_PATH:-../hrost}" bash "$RUNNER" --prepare-only >/dev/null
fi
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
    artifact_dir="$COMPARISON_DIR/$stem"
    [[ -f "$reference_file" ]] || {
        printf 'AirBatteryHrost: matching reference capture not found: %s\n' "$reference_file" >&2
        exit 2
    }

    rm -rf "$artifact_dir"
    mkdir -p "$artifact_dir"

    compare_args=(
        compare
        --candidate "$candidate_file"
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

printf '\n=== Fidelity pair ===\n'
printf 'candidate:  %s\n' "$CANDIDATE_DIR"
printf 'reference:  %s\n' "$REFERENCE_DIR"
printf 'comparison: %s\n' "$COMPARISON_DIR"
printf 'archive:    %s\n' "$ARCHIVE"
