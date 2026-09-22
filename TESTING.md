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
- shared full/compact presentation naming for Mac, iPhone, Watch, and AirPods;
- AirPods left/right merge thresholds and charging-state requirements;
- Nearcast v2 Group ID / Sharing Key validation and setup-code round trips;
- legacy Nearcast credential compatibility for migration;
- sticky battery-readability state; and
- scan serialization.

## Native runtime tests

Run:

```bash
just test-runtime
```

This builds the native vendor stack if required and verifies the staged helper's
loader/command-line contract. Full Mach-O architecture, linkage, and signature
inspection remains available explicitly through `just vendor-mobile-diagnose`
without slowing the normal gate.

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

The local gate is optimized for the edit/test loop:

1. validate or reuse the fingerprinted native runtime;
2. run one Xcode invocation that compiles the complete app graph and executes
   the deterministic hostless XCTest suite using the committed package lock;
3. smoke-test the staged native helper.

Use `just doctor` for explicit toolchain/project diagnostics and `just resolve`
when package resolution itself needs to be refreshed. Use `just build-verbose`
for the complete Xcode stream or `just build-profile` for Xcode's build timing
summary. Full Xcode logs from concise builds are retained under
`.build/logs/`.

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
- logical-device consistency across the popover, Dock, widgets, and Devices;
- intentional compact names in constrained surfaces (`Mac`, `iPhone`, `Watch`, `AirPods`);
- AirPods with case + L/R, L/R without the case currently visible, merge off,
  merge within threshold, and charging-state mismatch;
- Devices progressive disclosure, confirming identifiers/raw RSSI/query state
  remain under Technical Details rather than the primary device view;
- BLE battery-access policy inheritance and an identity-specific override;
- Display previews while changing light/dark mode, menu-bar battery style,
  earbud merging, Dock visibility, and widget ordering;
- renderer parity: compare Display previews against the live menu bar, popover,
  Dock tile, Battery Overview Small/Medium, and Single Battery Small using
  the same fixture state; differences should be limited to system host sizing,
  margins, chrome, and compositing;
- Battery Overview configuration: exercise all four combinations of Show
  Percentages and Show Labels and verify each placed widget updates without
  changing its family or device ordering;
- Battery Overview ring geometry: percentage-enabled cells use the open/split
  ring with the numeric value beneath it; percentage-disabled cells use a full
  ring. Small/Medium annotation-heavy layouts must not clip; Small should keep
  visually balanced margins around its 2×2 grid;
- widget gallery inventory on every supported macOS release: only Battery
  Overview and Single Battery are offered;
- Display preview host geometry: the Popover preview stays at the production
  352-point width; widget previews show a visible rounded host boundary, do not
  clip charging indicators or rings, and AirPods `Case/L/R` percentages never
  wrap the `%` onto a separate line;
- popover shell parity: the Display preview includes the same toolbar region as
  the live popover; the live toolbar shows About, Settings, and a non-focus-ring
  Quit `×`, and quitting requires explicit confirmation;
- Nearcast migration from an existing legacy credential, plus a newly generated
  Group ID / Sharing Key exchanged between two Macs when available;
- repeatedly switch to Nearcast and back to other Settings pages, then close and
  reopen Settings, confirming the sidebar/detail hierarchy never becomes blank;
- Settings and popover opening while background refreshes occur;
- keyboard navigation and VoiceOver labels for popover/settings controls;
- Increase Contrast and Reduce Transparency, confirming panels remain legible;
- non-default accent colors and common color-vision simulations; and
- an extended idle run, since mobile companion polling is background-driven.

No hosted CI is required for these checks; the supported verification path is
local.
