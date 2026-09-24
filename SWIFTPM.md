# SwiftPM-first build

`Package.swift` is the source of truth for the reusable Swift build graph.
`project.yml` is the source of truth for Apple bundle packaging.
`AirBattery.xcodeproj` is generated and disposable.

## Package products

- `AirBatteryKit` — the macOS application implementation.
- `airbattery` — the command-line executable.
- `AirBatteryTests` — the SwiftPM test target.

The app target itself is a tiny entry point in `Packaging/App` that imports
`AirBatteryKit`.

The WidgetKit extension remains an XcodeGen target. It compiles only the
extension-safe domain/snapshot/widget source slice instead of linking the full
app implementation. This keeps `APPLICATION_EXTENSION_API_ONLY=YES` while
leaving bundle creation, entitlements, App Intents metadata extraction, and
signing in Xcode's packaging layer.

The `abt` command is also represented by a generated Xcode tool target so the
copy embedded in the app can retain `abt/abt.entitlements`. The same source is
still an ordinary SwiftPM executable for development and testing.

## Prerequisites

```sh
brew install xcodegen
```

`xcbeautify` is also required by the `justfile` build output.

## Normal workflow

```sh
just check
```

This performs:

1. `swift package resolve`
2. `xcodegen generate`
3. Xcode package resolution for the generated packaging project
4. `swift test`
5. an unsigned app + widget integration build with `xcodebuild`

The integration build disables code signing so CI and local checks do not need
a Development Team. Normal Xcode Run/Archive builds still use the entitlements
from `project.yml` and therefore need your usual signing configuration.

## Source control

Add these entries to the repository's `.gitignore`:

```gitignore
/.build/
/.swiftpm/
/AirBattery.xcodeproj/
```

Remove the old checked-in `.xcodeproj` after applying the migration. Do not
edit `project.pbxproj` directly after that point. Change `Package.swift` for
SwiftPM composition and `project.yml` for app/widget/CLI packaging settings.
