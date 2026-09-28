# Issues

AirBattery-side issues identified while auditing the 64 captures produced by the Hrost `visual-regression` fixture suite. Items caused by Hrost capture/presentation defects are tracked in the Hrost repository instead.

Both AirBattery issues below are resolved and visually validated in the `20260928T021459Z` Hrost acceptance rerun. The remaining failed captures are confined to Hrost status-item capture geometry and do not indicate an AirBattery product defect.

## AIRBATTERY-001 — Hrost fixture device types do not match production icon identifiers

**Status:** Resolved and visually validated

Several synthetic devices in `Development/AirBatteryHrost/main.swift` used human-readable `deviceType` values that did not match the identifiers consumed by `getDeviceIcon(_:)`. The production icon catalog therefore fell through to `questionmark.circle.fill` even though the relevant assets/SF Symbols were available.

The fixture vocabulary was corrected to production identifiers, including:

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

**Validation:** the `20260928T021459Z` rerun resolves the intended Mac, keyboard, mouse, generic Bluetooth, AirPods, headphone, and iPhone production icons without the previous fallback question marks across trustworthy popover, menu, dock-tile, and widget captures.

## AIRBATTERY-002 — Battery glyph treats unavailable battery data as critical 0%

**Status:** Resolved and visually validated

In the `no-battery` scenario the fixture device has `hasBattery == false`, but the original standalone `battery-glyph` surface rendered a nearly empty red battery. This visually communicated a critically low charge rather than unavailable battery information.

**Implementation:** `SurfaceBatteryGlyph` branches on `hasBattery`. Measured batteries retain the existing fill/charging behavior; unavailable batteries render a subdued battery outline with a `?` marker and an accessibility label of `Battery level unavailable`, without deriving a fill color from the synthetic `0` value.

**Validation:** both light and dark `no-battery` glyph captures in the `20260928T021459Z` rerun show the explicit subdued unknown state rather than a critical red 0% state.

## Regression observations

The latest trustworthy captures also preserve the behaviors that were already correct before these fixes:

- AirPods grouping and case/left/right presentation;
- charging indicators;
- low-battery coloring;
- long-name truncation;
- no-battery row and widget empty-state behavior;
- light/dark presentation across popovers, menus, dock tiles, settings, widgets, and standalone glyphs.

No additional AirBattery-side UI defect was identified in the 56 trustworthy captures from the `20260928T021459Z` rerun.
