#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$ROOT"

CASES="$ROOT/Development/AirBatteryHrost/fidelity-settings.screen-sharing.txt"
CANDIDATE="$ROOT/Development/AirBatteryHrost/capture-screen-sharing.sh"
REFERENCE="$ROOT/Development/AirBatteryHrost/capture-production-screen-sharing.sh"

printf '\n=== Hrost host (candidate) ===\n'
AIRBATTERY_HROST_CASES="$CASES" \
    bash "$CANDIDATE" "$@"

printf '\n=== Production host (reference) ===\n'
AIRBATTERY_HROST_CASES="$CASES" \
    bash "$REFERENCE" "$@"
