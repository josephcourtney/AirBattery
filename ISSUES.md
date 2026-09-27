# Issues

Open AirBattery-side issues identified while auditing the 64 captures produced by the Hrost `visual-regression` fixture suite. Items caused by Hrost capture/presentation defects are tracked in the Hrost repository instead.

## AIRBATTERY-001 — Hrost fixture device types do not match production icon identifiers

**Status:** Open

Several synthetic devices in `Development/AirBatteryHrost/main.swift` use human-readable `deviceType` values that do not match the identifiers consumed by `getDeviceIcon(_:)`. The production icon catalog therefore falls through to `questionmark.circle.fill` even though the relevant assets/SF Symbols are available.

Known mismatches from the audited fixtures include:

| Fixture value | Production identifier expected by icon catalog |
|---|---|
| `MacBook` | `macbook` |
| `Magic Keyboard` | `Keyboard` |
| `Magic Mouse` | `MMouse` |
| `Bluetooth` | `general_bt` |
| `Apple Watch` | `Watch` |

The correctly specified iPhone, AirPods, headphones, and iPad fixtures render their intended icons, confirming that this is synthetic-data vocabulary drift rather than missing icon assets.

**Expected:** Hrost fixtures should use the same canonical device-type vocabulary as production device discovery/state.

**Observed:** multiple otherwise-correct popover, menu, dock-tile, and widget captures display fallback question-mark icons.

**Fix direction:** centralize fixture construction around canonical production device-type identifiers rather than reproducing string values ad hoc in the Hrost manifest.

## AIRBATTERY-002 — Battery glyph treats unavailable battery data as critical 0%

**Status:** Open

In the `no-battery` scenario the fixture device has `hasBattery == false`, but the standalone `battery-glyph` surface renders a nearly empty red battery. This visually communicates a critically low charge rather than unavailable battery information.

Other audited AirBattery surfaces handle this state more appropriately: the main row omits a fabricated percentage/bar and the overview widget reports that there are no battery devices.

**Expected:** a battery glyph should not present `hasBattery == false` as a real 0% measurement. The surface should either render an explicit unavailable/unknown state or omit the battery glyph, depending on its production contract.

**Observed:** the light-mode `no-battery` battery-glyph capture renders a red near-empty battery.

## Validation after fixes

Re-run the Hrost visual-regression fixtures after the Hrost capture defects are fixed and verify:

- fixture devices resolve the intended production icons without fallback question marks;
- `hasBattery == false` never appears as an actual critical 0% measurement;
- AirPods grouping, charging indicators, low-battery coloring, long-name truncation, and no-battery empty states remain unchanged, since those behaviors appeared correct in trustworthy captures.
