# Implementation Simplification Issues

This file tracks implementation complexity, outdated patterns, and macOS GUI architecture issues found during the September 2026 full-codebase survey.

The goal is to simplify AirBattery without materially changing its user-visible behavior. AppKit is not considered a problem by itself: the preferred architecture is SwiftUI for declarative presentation, with small AppKit controllers where macOS-specific status-item, Dock, window, or application-lifecycle behavior requires them.

## P0 — Architecture and ownership

### [x] 1. Periodic application work is owned by SwiftUI views

`MultiBatteryView` currently drives battery alerts, widget refreshes, iDevice scans, snapshot writes, Nearcast broadcasts, and Dock refreshes through global Combine timer publishers. A rendering view should not be responsible for application scheduling.

**Fix:** Introduce a single application-owned monitoring/scheduling coordinator. Views render observable state; the coordinator owns periodic work and can restart interval-dependent schedules when settings change.

### [x] 2. Settings persistence is scattered across UI and service code

`@AppStorage` is used directly in views, `AppDelegate`, Bluetooth scanners, Nearcast, log reading, and free functions. This couples otherwise non-UI code to SwiftUI and hides dependencies. Several arrays are also read from `UserDefaults` with force casts.

**Fix:** Introduce typed settings/defaults access. Keep `@AppStorage` only where a direct SwiftUI binding is useful; services and functions should use the typed settings/defaults API. Remove force-cast defaults reads.

### [x] 3. Application lifecycle code has too many responsibilities

`AirBatteryApp.swift` currently owns application lifecycle, status-item setup, status-menu rebuilding, Dock-window geometry, URL handling, notification handling, login-item behavior, pinned status items, and several global services.

**Fix:** Extract coherent controllers/services, especially status-bar and Dock-surface management. Keep `AppDelegate` as a thin lifecycle adapter.

### [x] 4. Surface selection side effects are duplicated

Startup and `DisplayView.applySurfaceSelection` separately manipulate the status item, pinned items, Dock activation policy, and user notifications.

**Fix:** Put menu-bar/Dock/both/none behavior behind one surface controller and call it from both startup and settings.

## P1 — macOS GUI modernization

### [x] 5. The main status item repeatedly recreates its hosting view

`setStatusBar(width:)` removes all status-button subviews and creates a fresh `NSHostingView<mainBatteryView>` whenever the width changes. The SwiftUI view itself also polls every second.

**Fix:** Create the status-item host once. Drive it from observable state and change only `NSStatusItem.length` when layout requires a different width.

### [x] 6. Menu and Dock-popover heights are manually reconstructed

Status-menu and Dock-popover sizing duplicate row-count logic and use several magic constants for local rows, AirPods rows, hidden rows, toolbar height, and Nearcast sections.

**Fix:** Let the hosted SwiftUI hierarchy report/fits its size and use that measurement instead of reconstructing the layout externally.

### [x] 7. Settings controls reimplement native macOS form behavior

`GroupForm.swift` defines `SForm`, `SGroupBox`, `SButton`, `SField`, `SPicker`, `SToggle`, and `SSteper`. Several wrappers manually scale and position native controls.

**Fix:** Prefer native `Form`, `Section`, `LabeledContent`, `Toggle`, `Picker`, `TextField`, and `Stepper`. Retain only genuinely useful small helpers such as an information button.

### [x] 8. Settings window ownership was duplicated

The app declared a native SwiftUI `Settings` scene but then overrode the Settings command and presented a separately constructed `NSWindow` through `SettingsWindowController`.

**Fix:** Use the AppKit application lifecycle and register the SwiftUI `Settings` scene with `NSHostingSceneRepresentation`. All Settings entry points now call the scene environment's `openSettings()` action, so SwiftUI exclusively owns creation and presentation of the Settings window. A small lifecycle observer only applies window configuration and keeps the application's activation policy synchronized while the SwiftUI-owned window is visible.

### [x] 9. Local-device and Nearcast rows duplicate interaction logic

Alert editing, pin/unpin, copy actions, hover state, battery rendering, and row chrome are separately implemented for local and Nearcast devices.

**Fix:** Reuse a common logical-device row/action component and parameterize the few source-specific differences.

### [x] 10. `DevicesView` performs inventory aggregation inside the SwiftUI view

The view repeatedly merges built-in, BLE, iDevice, Nearcast, and current-device data in a large computed property. It mutates a dummy refresh date from a global timer to trigger recomputation.

**Fix:** Move inventory aggregation into an observable inventory model/service. The view should consume ready-to-render snapshots.

### [x] 11. Large source files obscure boundaries

`SettingsView.swift`, `ContentView.swift`, `SurfaceRenderers.swift`, `AirBatteryApp.swift`, and `Supports.swift` each combine several unrelated responsibilities.

**Fix:** Split by responsibility after state ownership is simplified. Avoid splitting merely to reduce line count; file boundaries should follow architectural boundaries.

## P1 — Platform integration

### [x] 12. Launch at login retains a legacy helper application

`AirBatteryHelper.app` exists only to relaunch the containing application. The main application already uses ServiceManagement.

**Fix:** Use `SMAppService.mainApp` as the login item and remove the helper target, helper sources/entitlements, copy phase, helper-process status detection, and helper-specific signing/install logic.

### [x] 13. App/widget data sharing relies on another target's sandbox path

The main app and command-line tool construct paths under `~/Library/Containers/<widget-bundle-id>/Data/Documents` directly.

**Fix:** Use an App Group shared container for widget snapshots and Nearcast files, with a one-time migration/fallback for existing data.

### [x] 14. Widget rendering depends on whether the host process is currently running

Widget providers inspect `NSWorkspace.shared.runningApplications` and refuse normal rendering when AirBattery is not currently running.

**Fix:** Treat stored snapshots as the widget's data contract. If stale/running state remains useful, persist an explicit heartbeat/update timestamp rather than inspecting processes.

### [x] 15. Appearance monitoring observes the wrong notification

`AppearanceMonitor` listens for `NSWorkspace.accessibilityDisplayOptionsDidChangeNotification`, which is about accessibility display settings rather than normal light/dark appearance changes.

**Fix:** Use SwiftUI's `colorScheme` environment for rendered surfaces and combine it with AirBattery's explicit appearance override. Remove the custom monitor if no non-SwiftUI consumer needs it.

## P2 — API and implementation cleanup

### [x] 16. Deprecated AppKit/SwiftUI/Foundation APIs remain

The code contains deprecated `NSApplication.activate(ignoringOtherApps:)`, one-argument `onChange(of:perform:)`, `Process.launchPath`, and `Process.launch()` usage.

**Fix:** Use current APIs without changing semantics.

### [x] 17. Background work uses a mixture of legacy concurrency mechanisms

`Thread.detachNewThread`, selector-based timers, `DispatchQueue`, locks, and Swift tasks coexist.

**Fix:** After ownership is clear, use structured concurrency/actors where it materially simplifies the implementation. Do not perform a broad concurrency rewrite solely for style.

### [x] 18. Project language mode migrated to Swift 6

All Swift target configurations now use `SWIFT_VERSION = 6.0`.

**Fix:** Resolve Swift 6 concurrency diagnostics explicitly: isolate UI-owned state to `MainActor`, synchronize genuinely shared mutable stores with locks, make immutable shared configuration constant, and remove shared non-`Sendable` Foundation convenience globals. Narrow `nonisolated(unsafe)` and `@unchecked Sendable` uses remain only where external synchronization or main-queue confinement is explicit.

### [x] 19. Small redundant compatibility/dead-code fragments remain

Examples include a macOS 26 branch that repeats the already-applied transparent-window settings and commented-out legacy implementation fragments.

**Fix:** Remove redundant branches and obsolete commented code when touched.

### [x] 20. Several global singletons and mutable globals are implicit dependencies

Examples include `statusBarItem`, `pinnedItems`, `dockWindow`, `netcastService`, scan services, timers, `ud`, and `fd`.

**Fix:** Reduce mutable globals by making ownership explicit in application-level controllers/services. Stable immutable process-wide utilities may remain global where doing so is simpler.

## Implementation status

All identified simplification issues have been implemented. AirBattery now targets macOS 26 and later, builds in Swift 6 language mode, and uses a single SwiftUI-owned Settings scene hosted from the AppKit lifecycle.

## Explicit non-issues / design decisions to retain

- **Keep `NSStatusItem` / `NSMenu` rather than rewriting the app around `MenuBarExtra`.** The current traditional API is appropriate for multiple pinned status items, exact status-item sizing, explicit menu rebuilding, and multi-display behavior.
- **Keep an AppKit Dock popover/window boundary.** The custom floating surface positioned relative to the Dock is a legitimate AppKit use case.
- **Keep the pure presentation/policy direction in `CoreLogic.swift` and `SurfaceRenderers.swift`.** The refactor should move more logic toward explicit value types and testable policies, not add another framework layer.
