# AirBattery Hrost harness

`AirBatteryHrost` is a development-only deterministic UI harness. It renders AirBattery's production UI components against synthetic device fixtures without starting Bluetooth, iPhone discovery, Nearcast, Sparkle, persistence, or the normal `AppEnvironment` service graph.

The target is intentionally absent from normal SwiftPM resolution. Set `AIRBATTERY_HROST=1` to enable it. The runner does this automatically.

## Run the Lab

From the AirBattery repository root:

```sh
bash Development/AirBatteryHrost/run.sh
```

By default Hrost is expected at the sibling checkout `../hrost`. Override that when needed:

```sh
HROST_PATH=/path/to/hrost bash Development/AirBatteryHrost/run.sh
```

The runner builds `AirBatteryHrost`, stages the executable inside a minimal development-only `AirBatteryHrost.app`, compiles AirBattery's production `Assets.xcassets` into `Contents/Resources` with `actool`, copies the app's `.lproj` localization directories and SwiftPM runtime products, and then launches the bundled executable. Running from an application bundle is necessary because production views resolve named images, adaptive colors, and localized strings from `Bundle.main`.

## Commands

All normal Hrost commands can be passed through the runner:

```sh
bash Development/AirBatteryHrost/run.sh list
bash Development/AirBatteryHrost/run.sh validate
bash Development/AirBatteryHrost/run.sh capture \
  --surface main-popover \
  --scenario airpods \
  --appearance dark
```

The Lab also exposes **Capture Set…**. Its faceted builder selects surfaces, scenarios, compatible variants, and appearances independently, shows the resolved capture count, and allows explicit per-coordinate additions/exclusions under **Preview & Exceptions**. Capture progress is shown in the Lab with completed/total count and the current coordinate.

AirBattery provides these capture presets:

- **Smoke** — every surface, single-device fixture, default variants, System appearance
- **Visual Regression** — AirPods, charging, long names, and missing battery data across Light/Dark, plus the medium widget variant
- **Edge Cases** — empty, many devices, long names, and missing battery data across Light/Dark
- **AirPods** — AirPods across the battery-bearing surfaces in Light/Dark
- **Everything** — the complete compatible surface × scenario × variant × appearance matrix

`Visual Regression` is the normal evidence-gathering preset; `Everything` is intentionally much larger and is mainly useful for exhaustive checks.

## Isolated visual-regression acceptance

The checked-in `visual-regression.screen-sharing.txt` file expands the Visual Regression preset into the same 64 explicit coordinates used for acceptance review. To run them in Hrost's dedicated same-Mac Screen Sharing GUI session:

```sh
bash Development/AirBatteryHrost/capture-screen-sharing.sh \
  --user testymctestface
```

The wrapper prepares a self-contained `AirBatteryHrost.app`, including AirBattery assets, localizations, SwiftPM frameworks/dylibs, and resource bundles. Hrost stages and code-signs that app under the same persistent capture identity, leases it to the GUI-session agent for the duration of the run, and delegates readiness checks, TCC handling, retries, and result collection to `hrost-screen-share-capture`.

If the Hrost Screen Sharing agent has changed since initial setup, upgrade it once before the acceptance run:

```sh
../hrost/scripts/hrost-screen-share-session setup --user testymctestface
```

The normal runner fails rather than capturing when that GUI session is locked or logged out. Pass `--wait-for-desktop SEC` through the wrapper when bounded waiting is preferable.

## Scenarios

The fixture matrix currently covers:

- `empty`
- `single-device`
- `airpods`
- `charging`
- `many-devices`
- `long-names`
- `no-battery`

Each scenario drives every compatible surface from the same deterministic `Device` values.

## Surfaces

The harness currently exposes:

- `main-popover` — native Hrost `NSPopover` containing AirBattery's production toolbar and device-row surface components
- `status-menu` — native `NSMenu` using AirBattery's production popover surface content
- `status-item` — native `NSStatusItem` using `StatusBarBatteryContent`
- `dock-tile` — production `DockTileSurfaceContent`
- `display-settings` — production `DisplayView` in a native window
- `overview-widget` — production shared widget overview content in small, medium, and large variants
- `battery-glyph` — production `BatteryView`

The package-only factories in `AirBatteryDevelopmentSurfaces` and `AirBatteryWidgetDevelopmentSurfaces` are the integration seam. They contain no Hrost dependency and do not expand the shipping module's public API.

## Boundary

Hrost replaces the environment around AirBattery UI, not the UI itself. Fixture construction belongs here; production layout and presentation components remain in their normal modules. Hardware discovery, WidgetKit registration, persistence, updater behavior, and other full-app integration behavior still belong to the real AirBattery app and its integration tests.
