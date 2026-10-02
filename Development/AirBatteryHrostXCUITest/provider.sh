#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
AIRBATTERY_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
HROST_ROOT="$(cd "$AIRBATTERY_ROOT/../hrost" && pwd -P)"

export HROST_XCUITEST_CONFIGURATION_FILE="$SCRIPT_DIR/UITests/.hrost-environment"
export HROST_XCUITEST_RELAY_EXECUTABLE="$AIRBATTERY_ROOT/.hrost-tools/HrostXCUITestBrokerRelay"
export HROST_XCUITEST_DERIVED_DATA="$AIRBATTERY_ROOT/.hrost-xcuitest-derived-data"
export HROST_XCUITEST_ONLY_TESTING="AirBatteryHrostUITests/AirBatteryHrostUITests/testDisplaySettingsCheckpoint"
export HROST_XCUITEST_RESULT_BUNDLE_NAME="airbattery-hrost-xcuitest.xcresult"
export HROST_XCUITEST_XCODE_TIMEOUT_SECONDS="45"

GENERIC_PROVIDER="$HROST_ROOT/scripts/hrost-xcuitest-provider"
[[ -f "$GENERIC_PROVIDER" ]] || {
  printf 'missing reusable Hrost XCUITest provider: %s\n' "$GENERIC_PROVIDER" >&2
  exit 66
}

exec /bin/bash "$GENERIC_PROVIDER"
