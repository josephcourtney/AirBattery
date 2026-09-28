#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$ROOT"

HROST_PATH="${HROST_PATH:-../hrost}"
HROST_PATH="$(cd "$HROST_PATH" && pwd -P)"
PREPARE="$ROOT/Development/AirBatteryHrost/run.sh"
CASES="${AIRBATTERY_HROST_CASES:-$ROOT/Development/AirBatteryHrost/visual-regression.screen-sharing.txt}"
if [[ "$CASES" != /* ]]; then
    CASES="$ROOT/$CASES"
fi
APP_CAPTURE="$HROST_PATH/scripts/hrost-screen-share-capture-app"

[[ -f "$HROST_PATH/Package.swift" ]] || {
    printf 'AirBatteryHrost: Hrost checkout not found at %s\n' "$HROST_PATH" >&2
    exit 2
}
[[ -x "$PREPARE" ]] || {
    printf 'AirBatteryHrost: prepare runner is not executable: %s\n' "$PREPARE" >&2
    exit 2
}
[[ -f "$CASES" ]] || {
    printf 'AirBatteryHrost: acceptance case file not found: %s\n' "$CASES" >&2
    exit 2
}
[[ -f "$APP_CAPTURE" ]] || {
    printf 'AirBatteryHrost: app capture helper not found: %s\n' "$APP_CAPTURE" >&2
    exit 2
}

TMP_OUTPUT="$(mktemp /tmp/airbattery-hrost-prepare.XXXXXX)"
cleanup() { rm -f "$TMP_OUTPUT"; }
trap cleanup EXIT INT TERM HUP

HROST_PATH="$HROST_PATH" bash "$PREPARE" --prepare-only | tee "$TMP_OUTPUT"
APP_DIR="$(tail -n 1 "$TMP_OUTPUT")"
[[ -d "$APP_DIR" ]] || {
    printf 'AirBatteryHrost: prepared app bundle not found: %s\n' "$APP_DIR" >&2
    exit 2
}

exec bash "$APP_CAPTURE" \
    --app-bundle "$APP_DIR" \
    --cases "$CASES" \
    "$@"
