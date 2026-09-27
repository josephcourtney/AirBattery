#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

export AIRBATTERY_HROST=1
export HROST_PATH="${HROST_PATH:-../hrost}"

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

exec "$BIN_DIR/AirBatteryHrost" "$@"
