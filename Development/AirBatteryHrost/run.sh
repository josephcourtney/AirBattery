#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

export AIRBATTERY_HROST=1
export HROST_PATH="${HROST_PATH:-../hrost}"

[[ -f "$HROST_PATH/Package.swift" ]] || {
    echo "AirBatteryHrost: Hrost checkout not found at '$HROST_PATH'." >&2
    echo "Set HROST_PATH=/path/to/hrost to override the default ../hrost." >&2
    exit 2
}
command -v xcrun >/dev/null 2>&1 || {
    echo "AirBatteryHrost: xcrun is required to compile AirBattery assets." >&2
    exit 2
}

swift build --product AirBatteryHrost
BIN_DIR="$(swift build --show-bin-path)"

# AirBattery's production UI resolves named images and adaptive colors from the
# main bundle. A SwiftPM executable's main bundle is its bin directory, so put
# the compiled production asset catalog there before launching the harness.
xcrun actool \
    "$ROOT/AirBattery/Assets.xcassets" \
    --compile "$BIN_DIR" \
    --output-format human-readable-text \
    --notices \
    --warnings \
    --errors \
    --platform macosx \
    --target-device mac \
    --minimum-deployment-target 26.0

[[ -f "$BIN_DIR/Assets.car" ]] || {
    echo "AirBatteryHrost: actool did not produce $BIN_DIR/Assets.car." >&2
    exit 2
}

exec "$BIN_DIR/AirBatteryHrost" "$@"
