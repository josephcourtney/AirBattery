#!/bin/bash
set -euo pipefail

PROGRAM="${0##*/}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
AIRBATTERY_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
HROST_ROOT="${HROST_PATH:-$AIRBATTERY_ROOT/../hrost}"
HROST_ROOT="$(cd "$HROST_ROOT" && pwd -P)"
SESSION_TOOL="$HROST_ROOT/scripts/hrost-screen-share-session"
BROKER_TOOL="$HROST_ROOT/scripts/hrost-screen-share-broker"
CAPTURE_APP="$HROST_ROOT/scripts/hrost-screen-share-capture-app"

usage() {
  cat <<'USAGE'
Usage:
  validate.sh --user USER [--shared-dir DIR]

Validates the first real-host Hrost/XCUITest vertical slice against AirBattery.
Both UI-bearing sides run through already-accepted GUI-session launch paths:

  production reference:
    controlled reference request
      -> prebuilt AirBattery XCUITest
      -> XCTest sandbox relay
      -> stable Hrost acquisition broker
      -> production-host reference

  candidate:
    hrost-screen-share-capture-app
      -> LaunchServices in the same dedicated GUI session
      -> AirBatteryHrost capture
      -> hrost-host candidate

  then:
    non-UI Hrost comparison

The selected coordinate is fixed for P13:
  display-settings / airpods / default / light

Compilation and staging occur before the timing-sensitive GUI runs. No native UI
is launched in the invoking account's GUI session.
USAGE
}

timestamp() { date '+%Y-%m-%dT%H:%M:%S%z'; }
note() { printf '[%s] [%s] %s\n' "$(timestamp)" "$PROGRAM" "$*"; }
die() {
  printf '[%s] %s: %s\n' "$(timestamp)" "$PROGRAM" "$*" >&2
  exit 1
}

TEST_USER="${HROST_SCREEN_USER:-}"
SHARED_DIR="${HROST_SHARED_DIR:-}"
SHARED_DIR_SET=0
while (( $# > 0 )); do
  case "$1" in
    --user)
      (( $# >= 2 )) || die "--user requires a value"
      TEST_USER="$2"
      shift 2
      ;;
    --shared-dir)
      (( $# >= 2 )) || die "--shared-dir requires a value"
      SHARED_DIR="$2"
      SHARED_DIR_SET=1
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
done

[[ -n "$TEST_USER" ]] || die "missing --user USER"
id "$TEST_USER" >/dev/null 2>&1 || die "no such local user: $TEST_USER"
TEST_UID="$(id -u "$TEST_USER")"

if ! id -Gn "$TEST_USER" | tr ' ' '\n' | grep -qx admin; then
  die "XCUITest GUI-session user '$TEST_USER' must be an administrator"
fi

AUTOMATION_MODE_TOOL="$(/usr/bin/xcrun --find automationmodetool 2>/dev/null || true)"
[[ -n "$AUTOMATION_MODE_TOOL" && -x "$AUTOMATION_MODE_TOOL" ]] || die \
  "Xcode automationmodetool was not found"
AUTOMATION_MODE_STATUS="$($AUTOMATION_MODE_TOOL 2>&1 || true)"
printf '%s\n' "$AUTOMATION_MODE_STATUS"
grep -Fq 'DOES NOT REQUIRE user authentication to enable Automation Mode' \
  <<< "$AUTOMATION_MODE_STATUS" || die \
  "this Mac still requires interactive XCUITest authentication; run the Hrost XCUITest smoke with --authorize first"

STATE_DIR="${HROST_SCREEN_STATE_DIR:-$HOME/.hrost/screen-share/$TEST_USER}"
if (( ! SHARED_DIR_SET )) && [[ -f "$STATE_DIR/shared-dir" ]]; then
  IFS= read -r SHARED_DIR < "$STATE_DIR/shared-dir" || true
fi
SHARED_DIR="${SHARED_DIR:-/Users/Shared/hrost-probe}"
AGENT_ROOT="$SHARED_DIR/agent"
PROVIDER_ROOT="$AGENT_ROOT/providers"
READY_FILE="$AGENT_ROOT/ready"
BROKER_SOCKET="$SHARED_DIR/broker/runtime/broker.sock"
WORKSPACE="$PROVIDER_ROOT/AirBatteryP13Workspace"
STAGED_AIRBATTERY="$WORKSPACE/AirBattery"
STAGED_HROST="$WORKSPACE/hrost"
STAGED_PROJECT_DIR="$STAGED_AIRBATTERY/Development/AirBatteryHrostXCUITest"
STAGED_PROJECT="$STAGED_PROJECT_DIR/AirBatteryHrostXCUITest.xcodeproj"
STAGED_PROVIDER="$STAGED_PROJECT_DIR/provider.sh"
PREBUILT_DERIVED_DATA="$STAGED_AIRBATTERY/.hrost-xcuitest-derived-data"
STAGED_RELAY="$STAGED_AIRBATTERY/.hrost-tools/HrostXCUITestBrokerRelay"
PROFILE="$STAGED_AIRBATTERY/Development/AirBatteryHrost/xcuitest-fidelity-profile.json"
LOCAL_LOG_DIR="$AIRBATTERY_ROOT/.build/hrost-p13"
REFERENCE_LOCAL="$LOCAL_LOG_DIR/reference.hrostcapture"
CANDIDATE_DIR="$LOCAL_LOG_DIR/candidate"
COMPARISON_DIR="$LOCAL_LOG_DIR/comparison"
COMPARE_JSON="$LOCAL_LOG_DIR/compare.json"
COMPARE_STDERR="$LOCAL_LOG_DIR/compare.stderr.log"
REFERENCE_PROBE_LOG="$LOCAL_LOG_DIR/reference-probe.log"

[[ -f "$AIRBATTERY_ROOT/Package.swift" ]] || die "AirBattery checkout is incomplete"
[[ -f "$HROST_ROOT/Package.swift" ]] || die "Hrost checkout is incomplete: $HROST_ROOT"
[[ -f "$HROST_ROOT/scripts/hrost-xcuitest-provider" ]] || die \
  "Hrost checkout predates the reusable XCUITest provider runner"
[[ -x "$CAPTURE_APP" ]] || die "Hrost Screen Sharing app capture helper is missing: $CAPTURE_APP"
command -v xcodegen >/dev/null 2>&1 || die "xcodegen is required"
XCODEGEN="$(command -v xcodegen)"

bash "$SESSION_TOOL" ensure --user "$TEST_USER" --shared-dir "$SHARED_DIR" --quiet || die \
  "dedicated GUI session is not ready"
bash "$BROKER_TOOL" status --user "$TEST_USER" >/dev/null || die \
  "stable acquisition broker is not ready"

[[ -f "$READY_FILE" ]] || die "GUI-session agent ready file is missing"
AGENT_UID="$(awk -F= '$1 == "uid" {print $2; exit}' "$READY_FILE")"
[[ "$AGENT_UID" == "$TEST_UID" ]] || die "GUI-session agent belongs to unexpected user"

developer_dir="$(xcode-select -p 2>/dev/null || true)"
[[ "$developer_dir" == */Contents/Developer ]] || die "a full Xcode installation is not selected"

note "building developer-side reference probe and reusable XCUITest broker relay"
cd "$HROST_ROOT"
swift build --product HrostScreenShareReferenceProbe
swift build --product HrostXCUITestBrokerRelay
HROST_BIN_DIR="$(swift build --show-bin-path)"
PROBE="$HROST_BIN_DIR/HrostScreenShareReferenceProbe"
RELAY="$HROST_BIN_DIR/HrostXCUITestBrokerRelay"
[[ -x "$PROBE" ]] || die "HrostScreenShareReferenceProbe was not built"
[[ -x "$RELAY" ]] || die "HrostXCUITestBrokerRelay was not built"

note "staging AirBattery and Hrost source under the controlled provider root"
sudo -v
sudo rm -rf "$WORKSPACE"
sudo mkdir -p \
  "$STAGED_AIRBATTERY" \
  "$STAGED_HROST/Sources" \
  "$STAGED_HROST/Tests" \
  "$STAGED_HROST/scripts" \
  "$STAGED_AIRBATTERY/.hrost-tools"

sudo cp "$AIRBATTERY_ROOT/Package.swift" "$STAGED_AIRBATTERY/Package.swift"
[[ ! -f "$AIRBATTERY_ROOT/Package.resolved" ]] || \
  sudo cp "$AIRBATTERY_ROOT/Package.resolved" "$STAGED_AIRBATTERY/Package.resolved"
for directory in Sources abt AirBatteryTests Development Packaging; do
  [[ -d "$AIRBATTERY_ROOT/$directory" ]] || die "AirBattery staging source is missing: $directory"
  sudo cp -R "$AIRBATTERY_ROOT/$directory" "$STAGED_AIRBATTERY/$directory"
done
sudo mkdir -p "$STAGED_AIRBATTERY/AirBattery"
for path in \
  App Preferences Services Shared UI Assets.xcassets Base.lproj en.lproj Supports \
  Info.plist AirBattery.entitlements; do
  [[ -e "$AIRBATTERY_ROOT/AirBattery/$path" ]] || continue
  sudo cp -R "$AIRBATTERY_ROOT/AirBattery/$path" "$STAGED_AIRBATTERY/AirBattery/$path"
done
sudo mkdir -p \
  "$STAGED_AIRBATTERY/AirBattery/Preview Content" \
  "$STAGED_AIRBATTERY/AirBattery/libimobiledevice"

sudo cp "$HROST_ROOT/Package.swift" "$STAGED_HROST/Package.swift"
sudo cp -R "$HROST_ROOT/Sources/." "$STAGED_HROST/Sources/"
sudo cp -R "$HROST_ROOT/Tests/." "$STAGED_HROST/Tests/"
sudo cp "$HROST_ROOT/scripts/hrost-xcuitest-provider" \
  "$STAGED_HROST/scripts/hrost-xcuitest-provider"
sudo cp "$RELAY" "$STAGED_RELAY"
sudo chmod +x "$STAGED_PROVIDER" "$STAGED_RELAY"
sudo chown -R "$TEST_USER":staff "$WORKSPACE"
sudo chmod -R u+rwX,go+rX "$WORKSPACE"

note "generating the development-only AirBattery Hrost UI-test project"
sudo -u "$TEST_USER" /bin/bash -c \
  'cd "$1" && exec "$2" generate --spec project.yml' \
  _ "$STAGED_PROJECT_DIR" "$XCODEGEN"
[[ -d "$STAGED_PROJECT" ]] || die "xcodegen did not create the AirBattery Hrost UI-test project"

NATIVE_ARCH="$(uname -m)"
case "$NATIVE_ARCH" in
  arm64|x86_64) ;;
  *) die "unsupported native architecture: $NATIVE_ARCH" ;;
esac

note "validating the staged Xcode project without launching UI"
sudo -u "$TEST_USER" /usr/bin/xcrun xcodebuild \
  -project "$STAGED_PROJECT" \
  -scheme AirBatteryHrostXCUITest \
  -list >/dev/null

note "building AirBattery UI tests outside the controlled GUI-session deadline"
sudo -u "$TEST_USER" /bin/rm -rf "$PREBUILT_DERIVED_DATA"
sudo -u "$TEST_USER" /usr/bin/xcrun xcodebuild \
  -project "$STAGED_PROJECT" \
  -scheme AirBatteryHrostXCUITest \
  -configuration Debug \
  -destination "platform=macOS,arch=$NATIVE_ARCH" \
  -derivedDataPath "$PREBUILT_DERIVED_DATA" \
  -only-testing:AirBatteryHrostUITests/AirBatteryHrostUITests/testDisplaySettingsCheckpoint \
  ARCHS="$NATIVE_ARCH" \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY=- \
  DEVELOPMENT_TEAM= \
  build-for-testing >/dev/null
[[ -d "$PREBUILT_DERIVED_DATA/Build/Products" ]] || die \
  "build-for-testing completed without producing the expected DerivedData products"

note "preparing the AirBattery Hrost host outside the controlled GUI-session deadline"
set +e
PREPARE_OUTPUT="$(sudo -u "$TEST_USER" /usr/bin/env \
  HROST_PATH="$STAGED_HROST" \
  AIRBATTERY_HROST=1 \
  /bin/bash "$STAGED_AIRBATTERY/Development/AirBatteryHrost/run.sh" --prepare-only 2>&1)"
PREPARE_STATUS=$?
set -e
if (( PREPARE_STATUS != 0 )); then
  printf '%s\n' "$PREPARE_OUTPUT" >&2
  die "AirBatteryHrost preparation failed with status $PREPARE_STATUS"
fi
HROST_APP="$(printf '%s\n' "$PREPARE_OUTPUT" | /usr/bin/tail -n 1)"
HROST_EXEC="$HROST_APP/Contents/MacOS/AirBatteryHrost"
HROST_FRAMEWORKS="$HROST_APP/Contents/Frameworks"
HROST_BIN_DIRECTORY="$(dirname "$HROST_APP")"
[[ -d "$HROST_APP" && -x "$HROST_EXEC" ]] || die "prepared AirBatteryHrost app is missing: $HROST_APP"
[[ -f "$PROFILE" ]] || die "XCUITest fidelity profile is missing"

rm -rf "$LOCAL_LOG_DIR"
mkdir -p "$LOCAL_LOG_DIR" "$CANDIDATE_DIR"

cleanup_fixture_processes() {
  local pids
  pids="$(/bin/ps -axww -o uid=,pid=,command= 2>/dev/null | /usr/bin/awk -v uid="$TEST_UID" -v root="$WORKSPACE" '
    $1 == uid && (index($0, root) || index($0, "AirBatteryHrostUITests") || index($0, "HrostXCUITestBrokerRelay")) { print $2 }
  ')"
  [[ -z "$pids" ]] || kill -TERM $pids >/dev/null 2>&1 || true
}

note "acquiring the real AirBattery production reference through controlled XCUITest"
REQUEST_ID="airbattery-p13-$(date +%s)-$$"
set +e
REFERENCE_OUTPUT="$($PROBE \
  --agent-root "$AGENT_ROOT" \
  --provider "$STAGED_PROVIDER" \
  --request-id "$REQUEST_ID" \
  --application AirBattery \
  --surface display-settings \
  --scenario airpods \
  --variant default \
  --appearance light \
  --no-pairing-key \
  --timeout 55 2>&1)"
REFERENCE_STATUS=$?
set -e
printf '%s\n' "$REFERENCE_OUTPUT" | tee "$REFERENCE_PROBE_LOG"
if (( REFERENCE_STATUS != 0 )); then
  cleanup_fixture_processes
  die "AirBattery controlled XCUITest reference acquisition failed with status $REFERENCE_STATUS"
fi

grep -qx 'driver=hrost-xcuitest' <<< "$REFERENCE_OUTPUT" || die \
  "AirBattery reference did not use the hrost-xcuitest driver"
for capability in pixels geometry accessibility trace; do
  grep -qx "$capability=available" <<< "$REFERENCE_OUTPUT" || die \
    "AirBattery production reference did not provide $capability evidence"
done

REFERENCE_REMOTE="$(awk -F= '$1 == "archive" {print substr($0, index($0, "=") + 1); exit}' <<< "$REFERENCE_OUTPUT")"
REFERENCE_SESSION="$(awk -F= '$1 == "session" {print substr($0, index($0, "=") + 1); exit}' <<< "$REFERENCE_OUTPUT")"
REFERENCE_METRICS="$(awk -F= '$1 == "metrics" {print substr($0, index($0, "=") + 1); exit}' <<< "$REFERENCE_OUTPUT")"
[[ -f "$REFERENCE_REMOTE" ]] || die "controlled production-reference archive is missing"
[[ -d "$REFERENCE_SESSION" ]] || die "controlled production-reference session is missing"
[[ -f "$REFERENCE_METRICS" ]] || die "controlled production-reference metrics are missing"
grep -qx 'timed_out=0' "$REFERENCE_METRICS" || die "AirBattery XCUITest provider timed out"
grep -qx 'cancelled=0' "$REFERENCE_METRICS" || die "AirBattery XCUITest provider was cancelled"
grep -qx 'orphaned_workers=0' "$REFERENCE_METRICS" || die "AirBattery XCUITest provider leaked process-group workers"
grep -Fxq "broker_socket=$BROKER_SOCKET" "$REFERENCE_METRICS" || die \
  "AirBattery XCUITest provider did not receive the stable broker socket"
[[ -f "$REFERENCE_SESSION/provider.stdout.log" ]] || die "reference-provider stdout log is missing"
grep -Fq '** TEST EXECUTE SUCCEEDED **' "$REFERENCE_SESSION/provider.stdout.log" || die \
  "AirBattery XCUITest execution did not report success"
[[ -f "$REFERENCE_SESSION/xcuitest-relay.log" ]] || die "AirBattery XCUITest relay log is missing"

# Retain a developer-owned copy so subsequent non-UI comparison never depends
# on permissions inside the provider session tree.
sudo /bin/cp "$REFERENCE_REMOTE" "$REFERENCE_LOCAL"
sudo /usr/sbin/chown "$(id -u):$(id -g)" "$REFERENCE_LOCAL"

note "capturing the Hrost-host candidate through the accepted LaunchServices path"
"$CAPTURE_APP" \
  --app-bundle "$HROST_APP" \
  --user "$TEST_USER" \
  --shared-dir "$SHARED_DIR" \
  --output-dir "$CANDIDATE_DIR" \
  --no-confirm \
  'display-settings,airpods,light,default'

CANDIDATE="$(/usr/bin/find "$CANDIDATE_DIR" -maxdepth 1 -type f -name '*.hrostcapture' -print | /usr/bin/head -n 1)"
[[ -n "$CANDIDATE" && -f "$CANDIDATE" ]] || die "Hrost-host candidate archive is missing"

note "comparing production reference and Hrost-host candidate outside the GUI session"
rm -rf "$COMPARISON_DIR"
set +e
/usr/bin/env \
  DYLD_FRAMEWORK_PATH="$HROST_FRAMEWORKS:$HROST_BIN_DIRECTORY" \
  DYLD_LIBRARY_PATH="$HROST_FRAMEWORKS:$HROST_BIN_DIRECTORY" \
  "$HROST_EXEC" compare \
    --reference "$REFERENCE_LOCAL" \
    --candidate "$CANDIDATE" \
    --profile "$PROFILE" \
    --output-dir "$COMPARISON_DIR" \
    --json \
    > "$COMPARE_JSON" 2> "$COMPARE_STDERR"
COMPARE_STATUS=$?
set -e
cat "$COMPARE_JSON"
[[ ! -s "$COMPARE_STDERR" ]] || cat "$COMPARE_STDERR" >&2
(( COMPARE_STATUS == 0 )) || die "AirBattery P13 comparison failed with status $COMPARE_STATUS"
[[ -d "$COMPARISON_DIR" ]] || die "comparison evidence directory is missing"

REFERENCE_METADATA="$LOCAL_LOG_DIR/reference-capture.json"
CANDIDATE_METADATA="$LOCAL_LOG_DIR/candidate-capture.json"
/usr/bin/unzip -p "$REFERENCE_LOCAL" capture.json > "$REFERENCE_METADATA" || die \
  "could not read production-reference capture metadata"
/usr/bin/unzip -p "$CANDIDATE" capture.json > "$CANDIDATE_METADATA" || die \
  "could not read candidate capture metadata"

REFERENCE_ROLE="$(/usr/bin/plutil -extract role raw -o - "$REFERENCE_METADATA")"
CANDIDATE_ROLE="$(/usr/bin/plutil -extract role raw -o - "$CANDIDATE_METADATA")"
REFERENCE_PAIRING="$(/usr/bin/plutil -extract pairingKey raw -o - "$REFERENCE_METADATA")"
CANDIDATE_PAIRING="$(/usr/bin/plutil -extract pairingKey raw -o - "$CANDIDATE_METADATA")"
REFERENCE_APP="$(/usr/bin/plutil -extract application.name raw -o - "$REFERENCE_METADATA")"
CANDIDATE_APP="$(/usr/bin/plutil -extract application.name raw -o - "$CANDIDATE_METADATA")"
[[ "$REFERENCE_ROLE" == "production-host" ]] || die \
  "production reference has unexpected role: $REFERENCE_ROLE"
[[ "$CANDIDATE_ROLE" == "hrost-host" ]] || die \
  "candidate has unexpected role: $CANDIDATE_ROLE"
[[ "$REFERENCE_APP" == "AirBattery" && "$CANDIDATE_APP" == "AirBattery" ]] || die \
  "production reference and candidate do not share the AirBattery application identity"
[[ -n "$REFERENCE_PAIRING" && "$REFERENCE_PAIRING" == "$CANDIDATE_PAIRING" ]] || die \
  "production reference and candidate pairing keys do not match"

for capability in pixels geometry accessibility trace; do
  availability="$(/usr/bin/plutil -extract "evidenceCapabilities.$capability" raw -o - "$REFERENCE_METADATA" 2>/dev/null || true)"
  [[ "$availability" == "available" ]] || die \
    "production reference capability '$capability' is '$availability', expected available"
done

# XCTest/LaunchServices workers can outlive their immediate shell parent briefly.
# Require that the production AUT, test runner, relay, and staged Hrost host all
# leave the controlled session before accepting the vertical slice.
remaining=""
for _ in {1..50}; do
  remaining="$(/bin/ps -axww -o uid=,pid=,stat=,command= 2>/dev/null | /usr/bin/awk -v uid="$TEST_UID" -v root="$WORKSPACE" '
    $1 == uid && (index($0, root) || index($0, "AirBatteryHrostUITests") || index($0, "HrostXCUITestBrokerRelay")) { print }
  ')"
  [[ -z "$remaining" ]] && break
  sleep 0.1
done
if [[ -n "$remaining" ]]; then
  printf '%s\n' '--- remaining controlled AirBattery fixture processes ---' >&2
  printf '%s\n' "$remaining" >&2
  cleanup_fixture_processes
  die "controlled AirBattery P13 run leaked a fixture process"
fi

bash "$BROKER_TOOL" status --user "$TEST_USER" >/dev/null || die \
  "stable acquisition broker is unhealthy after AirBattery P13 run"

note "AirBattery P13 controlled XCUITest/reference/candidate validation passed"
printf 'reference:  %s\n' "$REFERENCE_LOCAL"
printf 'candidate:  %s\n' "$CANDIDATE"
printf 'comparison: %s\n' "$COMPARISON_DIR"
printf 'session:    %s\n' "$REFERENCE_SESSION"
printf 'compare:    %s\n' "$COMPARE_JSON"
