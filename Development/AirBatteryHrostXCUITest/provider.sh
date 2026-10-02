#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
AIRBATTERY_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"

: "${HROST_REFERENCE_SESSION:?missing HROST_REFERENCE_SESSION}"
AGENT_ROOT="$(cd "$HROST_REFERENCE_SESSION/../.." && pwd -P)"
PROVIDER_EXECUTABLE="$AGENT_ROOT/providers/.hrost-tools/HrostXCUITestProvider"

export HROST_XCUITEST_CONFIGURATION_FILE="$SCRIPT_DIR/UITests/.hrost-environment"
export HROST_XCUITEST_RELAY_EXECUTABLE="$AIRBATTERY_ROOT/.hrost-tools/HrostXCUITestBrokerRelay"
export HROST_XCUITEST_DERIVED_DATA="$AIRBATTERY_ROOT/.hrost-xcuitest-derived-data"
export HROST_XCUITEST_ONLY_TESTING="AirBatteryHrostUITests/AirBatteryHrostUITests/testDisplaySettingsCheckpoint"
export HROST_XCUITEST_RESULT_BUNDLE_NAME="airbattery-hrost-xcuitest.xcresult"
export HROST_XCUITEST_XCODE_TIMEOUT_SECONDS="45"

[[ -x "$PROVIDER_EXECUTABLE" ]] || {
  printf 'missing installed Hrost XCUITest provider executable: %s\n' "$PROVIDER_EXECUTABLE" >&2
  printf '%s\n' 'run hrost/scripts/hrost-install-xcuitest-provider for the controlled GUI user first' >&2
  exit 66
}

exec "$PROVIDER_EXECUTABLE"
