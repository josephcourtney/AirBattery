# Testing AirBattery

AirBattery has three complementary local test layers.

## Deterministic unit tests

Run:

```bash
just test
```

This runs the shared `AirBatteryTests` XCTest scheme. The test target is
hostless: it compiles the Foundation-only production logic in
`AirBattery/Supports/CoreLogic.swift` directly into the test bundle and does
not launch AirBattery, scan Bluetooth devices, or contact mobile hardware.

Current coverage includes:

- parsing `ideviceinfo` metadata and battery output;
- decoding and validating `airbattery-mobile companion-battery` JSON;
- iPhone-only companion eligibility;
- per-parent five-minute companion throttling;
- disabling companion probing after a helper signal failure;
- USB/network discovery candidate merging;
- stable iOS identity across BLE and libimobiledevice observations;
- mobile-UDID preference, BLE-ID retention, and BLE identifier rotation;
- sticky battery-readability state;
- scan serialization;
- AirPods left/right merge thresholds and charging-state requirements.

## Native runtime tests

Run:

```bash
just test-runtime
```

This builds the native vendor stack if required, verifies the helper's command
line contract, and runs `just vendor-mobile-diagnose` to check staged Mach-O
architecture, relocatable linkage, and code signatures.

This layer does not require a connected iPhone or iPad.

## Hardware integration tests

Run:

```bash
just test-hardware
```

This is intentionally opt-in. It:

1. reports libimobiledevice visibility separately for network and USB;
2. if AirBattery is already running, asks it to write a fresh in-memory snapshot
   through `airbattery://writedata`, then reports any iPhone rows with canonical,
   libimobiledevice, and BLE identifiers plus the latest battery source;
3. verifies that `ideviceinfo` can read metadata and battery state for every
   libimobiledevice-enumerated device;
4. selects an iPhone visible to libimobiledevice, if one is available;
5. repeatedly runs the AirBattery companion helper against that iPhone; and
6. validates every helper result as JSON, including Watch battery ranges and
   field types.

The default companion stress count is 100. Override it with:

```bash
AIRBATTERY_HARDWARE_STRESS_ITERATIONS=500 just test-hardware
```

The companion helper retries transient companion-proxy transport/protocol
failures up to three times with short backoff. The stress test treats an
exhausted helper status 4/5 as a transient protocol failure rather than a crash,
continues the burst, and reports the count at the end. It still fails
immediately on a child-process crash, malformed JSON from a successful helper
run, disappearance of the selected parent device, or too many exhausted
transient failures. The default transient-failure budget is 5 per stress run:

```bash
AIRBATTERY_HARDWARE_MAX_TRANSIENT_FAILURES=0 just test-hardware
```

sets strict zero-tolerance if desired.

Select a specific iPhone with:

```bash
AIRBATTERY_TEST_UDID=<udid> just test-hardware
```

If only an iPad is visible to libimobiledevice, iPad metadata/battery checks
still run and the companion stress test is skipped. AirBattery itself
intentionally probes the companion service only for devices whose
`DeviceClass` is `iPhone`.

The persisted JSON is a widget/export snapshot rather than AirBattery's primary
live store. The hardware test therefore refreshes it from a running AirBattery
before reading it. It deliberately does not launch AirBattery merely to obtain
diagnostics; when the app is not already running, the test labels any existing
snapshot as potentially stale.

An iPhone can still appear in AirBattery while being absent from both
`idevice_id -n` and `idevice_id -l`. That can happen when the current battery
observation comes from BLE or the logical device is retained from recent state.
AirBattery now persists the libimobiledevice UDID and CoreBluetooth UUID
separately. Once a mobile UDID has been learned, it remains the canonical
`deviceID`; later BLE observations update `bleDeviceID` and battery state
without replacing that UDID. The hardware test prints all three identifiers and
the latest battery source.

The script runs under Bash and uses `rc` for child exit statuses; it does not
use zsh's read-only `status` parameter.

## Full local gate

Run:

```bash
just check
```

The local gate now performs:

1. Xcode/toolchain validation;
2. Swift package resolution;
3. deterministic XCTest coverage;
4. an unsigned application build; and
5. native runtime verification.

Real-device testing remains outside `just check` because it depends on the
currently connected and paired hardware.

## Manual application checks

Automated tests do not replace a few application-level checks that depend on
macOS services and real peripherals. Before a release that changes discovery,
battery presentation, or the native mobile stack, exercise at least:

- USB → Wi-Fi and Wi-Fi → USB transitions for the same iPhone/iPad;
- battery and charging-state changes while AirBattery remains running;
- sleep/wake recovery;
- an iPhone paired with an Apple Watch, when available;
- AirPods case/left/right presentation with merging both off and on;
- Settings and menu opening while background refreshes occur; and
- an extended idle run, since mobile companion polling is background-driven.

No hosted CI is required for these checks; the supported verification path is
local.
