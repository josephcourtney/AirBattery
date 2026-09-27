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

The runner builds `AirBatteryHrost`, compiles AirBattery's production `Assets.xcassets` into the SwiftPM executable directory with `actool`, and then launches the harness. Compiling the catalog is necessary because production views resolve named images and adaptive colors from `Bundle.main`.

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
