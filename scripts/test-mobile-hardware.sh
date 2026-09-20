#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/AirBattery/libimobiledevice/bin"
ITERATIONS="${AIRBATTERY_HARDWARE_STRESS_ITERATIONS:-100}"
MAX_TRANSIENT_FAILURES="${AIRBATTERY_HARDWARE_MAX_TRANSIENT_FAILURES:-5}"
REQUESTED_UDID="${AIRBATTERY_TEST_UDID:-}"
AIRBATTERY_DATA="$HOME/Library/Containers/com.josephcourtney.AirBattery.widget/Data/Documents/data.json"

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'Missing required command: %s\n' "$1" >&2
    exit 2
  }
}

for command in jq awk sed tr; do
  require_command "$command"
done

for tool in idevice_id ideviceinfo airbattery-mobile; do
  if [[ ! -x "$BIN/$tool" ]]; then
    printf 'Missing built vendor tool: %s\n' "$BIN/$tool" >&2
    printf '%s\n' 'Run: just vendor-mobile' >&2
    exit 2
  fi
done

case "$ITERATIONS" in
  ''|*[!0-9]*)
    printf 'AIRBATTERY_HARDWARE_STRESS_ITERATIONS must be a positive integer.\n' >&2
    exit 2
    ;;
esac
if [[ "$ITERATIONS" -lt 1 ]]; then
  printf 'AIRBATTERY_HARDWARE_STRESS_ITERATIONS must be at least 1.\n' >&2
  exit 2
fi

case "$MAX_TRANSIENT_FAILURES" in
  ''|*[!0-9]*)
    printf 'AIRBATTERY_HARDWARE_MAX_TRANSIENT_FAILURES must be a non-negative integer.\n' >&2
    exit 2
    ;;
esac

short_id() {
  printf '%s' "$1" | sed 's/^\(.\{8\}\).*/\1…/'
}

info_value() {
  local key="$1"
  awk -v key="$key" 'index($0, key ":") == 1 { sub("^[^:]*:[[:space:]]*", ""); print; exit }'
}

query_device() {
  local udid="$1"
  local transport="$2"
  local info battery name class level charging

  if [[ "$transport" == "network" ]]; then
    info="$("$BIN/ideviceinfo" -n -u "$udid")" || {
      printf 'FAIL %s (%s): ideviceinfo failed\n' "$(short_id "$udid")" "$transport" >&2
      return 1
    }
  else
    info="$("$BIN/ideviceinfo" -u "$udid")" || {
      printf 'FAIL %s (%s): ideviceinfo failed\n' "$(short_id "$udid")" "$transport" >&2
      return 1
    }
  fi

  name="$(printf '%s\n' "$info" | info_value DeviceName)"
  class="$(printf '%s\n' "$info" | info_value DeviceClass)"
  if [[ -z "$name" || -z "$class" ]]; then
    printf 'FAIL %s (%s): missing DeviceName/DeviceClass\n' "$(short_id "$udid")" "$transport" >&2
    return 1
  fi

  if [[ "$transport" == "network" ]]; then
    battery="$("$BIN/ideviceinfo" -n -u "$udid" -q com.apple.mobile.battery)" || {
      printf 'FAIL %s %s (%s): battery query failed\n' "$class" "$name" "$transport" >&2
      return 1
    }
  else
    battery="$("$BIN/ideviceinfo" -u "$udid" -q com.apple.mobile.battery)" || {
      printf 'FAIL %s %s (%s): battery query failed\n' "$class" "$name" "$transport" >&2
      return 1
    }
  fi

  level="$(printf '%s\n' "$battery" | info_value BatteryCurrentCapacity)"
  charging="$(printf '%s\n' "$battery" | info_value BatteryIsCharging)"

  case "$level" in
    ''|*[!0-9]*)
      printf 'FAIL %s %s (%s): invalid battery level %q\n' "$class" "$name" "$transport" "$level" >&2
      return 1
      ;;
  esac
  if [[ "$level" -lt 0 || "$level" -gt 100 ]]; then
    printf 'FAIL %s %s (%s): battery level out of range: %s\n' "$class" "$name" "$transport" "$level" >&2
    return 1
  fi

  case "$(printf '%s' "$charging" | tr '[:upper:]' '[:lower:]')" in
    true|false|yes|no|0|1) ;;
    *)
      printf 'FAIL %s %s (%s): invalid charging value %q\n' "$class" "$name" "$transport" "$charging" >&2
      return 1
      ;;
  esac

  printf 'PASS %-7s %-8s %-24s battery=%s charging=%s id=%s\n' \
    "$transport" "$class" "$name" "$level" "$charging" "$(short_id "$udid")"
}

find_iphone() {
  local transport="$1"
  local ids="$2"
  local udid info class

  while IFS= read -r udid; do
    [[ -n "$udid" ]] || continue
    if [[ "$transport" == "network" ]]; then
      info="$("$BIN/ideviceinfo" -n -u "$udid" 2>/dev/null || true)"
    else
      info="$("$BIN/ideviceinfo" -u "$udid" 2>/dev/null || true)"
    fi
    class="$(printf '%s\n' "$info" | info_value DeviceClass)"
    if [[ "$class" == "iPhone" ]]; then
      printf '%s' "$udid"
      return 0
    fi
  done <<<"$ids"
  return 1
}

print_id_list() {
  local label="$1"
  local ids="$2"
  local count=0
  local udid

  printf '%s\n' "$label"
  while IFS= read -r udid; do
    [[ -n "$udid" ]] || continue
    printf '  %s\n' "$udid"
    count=$((count + 1))
  done <<<"$ids"

  if [[ "$count" -eq 0 ]]; then
    printf '%s\n' '  (none)'
  fi
}

airbattery_iphone_rows() {
  [[ -f "$AIRBATTERY_DATA" ]] || return 0
  jq -r '
    .[]
    | select(
        ((.deviceType // "") | test("^iPhone"; "i")) or
        ((.deviceModel // "") | test("^iPhone"; "i"))
      )
    | [
        (.deviceName // "iPhone"),
        (.deviceType // "unknown"),
        (.deviceModel // ""),
        (.deviceID // "")
      ]
    | @tsv
  ' "$AIRBATTERY_DATA" 2>/dev/null || true
}

print_airbattery_visibility() {
  local rows="$1"
  local name type model id

  printf '%s\n' 'AirBattery persisted iPhone rows (discovery source is not persisted):'
  if [[ -z "$rows" ]]; then
    if [[ -f "$AIRBATTERY_DATA" ]]; then
      printf '%s\n' '  (none)'
    else
      printf '  unavailable: %s does not exist\n' "$AIRBATTERY_DATA"
    fi
    return
  fi

  while IFS="$(printf '\t')" read -r name type model id; do
    [[ -n "$name" ]] || continue
    [[ -n "$model" ]] || model="-"
    [[ -n "$id" ]] || id="-"
    printf '  %-24s type=%-12s model=%-14s id=%s\n' \
      "$name" "$type" "$model" "$id"
  done <<<"$rows"
}

printf '%s\n' '--- Native helper CLI smoke test ---'
set +e
"$BIN/airbattery-mobile" >/dev/null 2>&1
rc=$?
set -e
if [[ "$rc" -ne 2 ]]; then
  printf 'FAIL airbattery-mobile usage exit status: expected 2, got %s\n' "$rc" >&2
  exit 1
fi
printf '%s\n' 'PASS airbattery-mobile rejects missing arguments with status 2'

printf '%s\n' '--- Device visibility ---'
network_ids="$("$BIN/idevice_id" -n 2>/dev/null || true)"
usb_ids="$("$BIN/idevice_id" -l 2>/dev/null || true)"
airbattery_iphones="$(airbattery_iphone_rows)"

print_id_list 'libimobiledevice network (-n):' "$network_ids"
print_id_list 'libimobiledevice USB (-l):' "$usb_ids"
print_airbattery_visibility "$airbattery_iphones"

printf '%s\n' '--- Mobile battery reads ---'
device_count=0
while IFS= read -r udid; do
  [[ -n "$udid" ]] || continue
  query_device "$udid" network
  device_count=$((device_count + 1))
done <<<"$network_ids"

while IFS= read -r udid; do
  [[ -n "$udid" ]] || continue
  query_device "$udid" usb
  device_count=$((device_count + 1))
done <<<"$usb_ids"

if [[ "$device_count" -eq 0 ]]; then
  printf '%s\n' 'SKIP no USB or network mobile devices are currently visible'
fi

printf '%s\n' '--- Companion proxy stress test ---'
iphone_udid=""
if [[ -n "$REQUESTED_UDID" ]]; then
  iphone_udid="$REQUESTED_UDID"
elif iphone_udid="$(find_iphone network "$network_ids")"; then
  :
elif iphone_udid="$(find_iphone usb "$usb_ids")"; then
  :
else
  iphone_udid=""
fi

if [[ -z "$iphone_udid" ]]; then
  printf '%s\n' 'SKIP no iPhone is visible to libimobiledevice over network or USB.'
  if [[ -n "$airbattery_iphones" ]]; then
    printf '%s\n' \
      'AirBattery does have a persisted iPhone row, but its discovery source is not recorded.' \
      'Because libimobiledevice cannot currently see that iPhone, the row may be BLE-derived' \
      'or retained from an earlier observation; it cannot drive the companion-proxy Watch test.'
  else
    printf '%s\n' \
      'AirBattery can still show iPhones discovered over BLE or retained from recent state,' \
      'but those rows cannot drive the companion-proxy Watch test.'
  fi
  exit 0
fi

printf 'Using iPhone id=%s for %s companion queries\n' "$(short_id "$iphone_udid")" "$ITERATIONS"
successes=0
transient_failures=0
for ((i = 1; i <= ITERATIONS; i++)); do
  set +e
  output="$("$BIN/airbattery-mobile" companion-battery "$iphone_udid" 2>&1)"
  rc=$?
  set -e

  if [[ "$rc" -gt 128 ]]; then
    printf 'FAIL companion query %d/%d crashed (status %d):\n%s\n' \
      "$i" "$ITERATIONS" "$rc" "$output" >&2
    exit 1
  fi

  if [[ "$rc" -eq 4 || "$rc" -eq 5 ]]; then
    transient_failures=$((transient_failures + 1))
    printf 'WARN companion query %d/%d exhausted transient retries (status %d): %s\n' \
      "$i" "$ITERATIONS" "$rc" "$output" >&2
    if [[ "$transient_failures" -gt "$MAX_TRANSIENT_FAILURES" ]]; then
      printf 'FAIL transient companion failures exceeded limit %s\n' \
        "$MAX_TRANSIENT_FAILURES" >&2
      exit 1
    fi
    continue
  fi

  if [[ "$rc" -ne 0 ]]; then
    printf 'FAIL companion query %d/%d exited %d:\n%s\n' "$i" "$ITERATIONS" "$rc" "$output" >&2
    exit 1
  fi

  if ! jq -e '
      (.watches | type == "array") and
      all(.watches[];
        (.id | type == "string") and
        (.name | type == "string") and
        (.productType | type == "string") and
        (.batteryLevel | type == "number" and . >= 0 and . <= 100) and
        (.isCharging | type == "boolean")
      )
    ' >/dev/null <<<"$output"; then
    printf 'FAIL companion query %d/%d returned invalid JSON:\n%s\n' "$i" "$ITERATIONS" "$output" >&2
    exit 1
  fi

  successes=$((successes + 1))
  if ((i == 1 || i % 10 == 0 || i == ITERATIONS)); then
    printf 'PASS companion query %d/%d watches=%s\n' \
      "$i" "$ITERATIONS" "$(jq '.watches | length' <<<"$output")"
  fi
done

if [[ "$successes" -eq 0 ]]; then
  printf '%s\n' 'FAIL no companion query completed successfully' >&2
  exit 1
fi

printf 'PASS companion stress: attempts=%s successes=%s transient_failures=%s crashes=0 malformed=0\n' \
  "$ITERATIONS" "$successes" "$transient_failures"
