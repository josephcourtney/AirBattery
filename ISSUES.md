# Issues

AirBattery-side issues identified while auditing the 64 captures produced by the Hrost `visual-regression` fixture suite. Items caused by Hrost capture/presentation defects are tracked in the Hrost repository instead.

The implementation work below is complete. Final closure requires rerunning the Hrost visual-regression preset after pulling the corresponding Hrost fixes.

## AIRBATTERY-001 — Hrost fixture device types do not match production icon identifiers

**Status:** Implemented; pending visual validation

Several synthetic devices in `Development/AirBatteryHrost/main.swift` used human-readable `deviceType` values that did not match the identifiers consumed by `getDeviceIcon(_:)`. The production icon catalog therefore fell through to `questionmark.circle.fill` even though the relevant assets/SF Symbols were available.

The fixture vocabulary has been corrected to production identifiers, including:

| Previous fixture value | Production identifier |
|---|---|
| `MacBook` | `macbook` |
| `Magic Keyboard` | `Keyboard` |
| `Magic Mouse` | `MMouse` |
| `Magic Trackpad` | `Trackpad` |
| `Bluetooth` | `general_bt` |
| `Apple Watch` | `Watch` |
| `Mac` | `mac` |

The correctly specified iPhone, AirPods, headphones, and iPad fixture identifiers were left unchanged.

**Expected validation:** popover, menu, dock-tile, and widget captures should resolve the intended production device icons without fallback question marks.

## AIRBATTERY-002 — Battery glyph treats unavailable battery data as critical 0%

**Status:** Implemented; pending visual validation

In the `no-battery` scenario the fixture device has `hasBattery == false`, but the standalone `battery-glyph` surface rendered a nearly empty red battery. This visually communicated a critically low charge rather than unavailable battery information.

**Implementation:** `SurfaceBatteryGlyph` now branches on `hasBattery`. Measured batteries retain the existing fill/charging behavior; unavailable batteries render a subdued battery outline with a `?` marker and an accessibility label of `Battery level unavailable`, without deriving a fill color from the synthetic `0` value.

**Expected validation:** the no-battery glyph should read as unknown/unavailable rather than critical, in both light and dark appearances.

## Validation after fixes

Re-run the Hrost `visual-regression` fixtures and verify:

- fixture devices resolve the intended production icons without fallback question marks;
- `hasBattery == false` renders as an unavailable/unknown state, not an actual critical 0% measurement;
- AirPods grouping, charging indicators, low-battery coloring, long-name truncation, and no-battery empty states remain unchanged, since those behaviors appeared correct in trustworthy captures.
