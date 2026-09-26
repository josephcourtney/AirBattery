#!/bin/bash
set -euo pipefail

# AirBattery GUI design capture, v10.
#
# This version separates capture control into two paths:
#   - AirBattery-owned UI: deterministic preferences + verified AX navigation.
#   - macOS-owned UI: Accessibility automation with explicit verification.
#
# It also suppresses visually redundant screenshots and never mutates
# AirBattery preferences while the app is still running.
#
# Capture selection is filename-based. With no selectors, the historical full
# capture behavior is preserved. --only and --skip accept shell-style globs and
# may be repeated; quote globs so the invoking shell does not expand them.
#
# It intentionally does NOT save a misleading screenshot when a macOS
# Accessibility interaction fails.
#
# Usage:
#   ./scripts/capture_airbattery_gui.sh [output-root]
#   ./scripts/capture_airbattery_gui.sh [output-root] --only 'widget-editor/*'
#   ./scripts/capture_airbattery_gui.sh --only 'widget-editor/02-gallery-airbattery.png'
#   ./scripts/capture_airbattery_gui.sh --skip 'widgets-in-situ/*'
#   ./scripts/capture_airbattery_gui.sh --list
#
# Options:
#   --only GLOB   Capture only matching image targets. Repeatable.
#   --skip GLOB   Exclude matching image targets. Repeatable.
#   --list        List all selectable image targets and exit.
#   -h, --help    Show usage and exit.
#
# Optional:
#   AIRBATTERY_STATUS_POINT="x,y"
#   AIRBATTERY_WIDGET_POINT="x,y"
#   GUI_CAPTURE_MUTATE_PREFS=0
#   GUI_CAPTURE_CONTEXT=0
#
# Required terminal permissions:
#   Privacy & Security -> Accessibility
#   Privacy & Security -> Screen & System Audio Recording

APP_NAME="AirBattery"
BUNDLE_ID="com.josephcourtney.AirBattery"

CAPTURE_TARGETS=(
  "menubar/01-current.png"
  "menubar/02-airbattery-glyph.png"
  "menubar/03-macos-outside.png"
  "menubar/04-ios-inside-color.png"
  "popover/01-current-collapsed.png"
  "popover/01-current-collapsed-context.png"
  "popover/02-current-airpods-expanded.png"
  "popover/03-earbuds-merged-collapsed.png"
  "popover/04-earbuds-merged-airpods-expanded.png"
  "popover/03-earbuds-split-collapsed.png"
  "popover/04-earbuds-split-airpods-expanded.png"
  "settings/general/01-top.png"
  "settings/general/02-middle.png"
  "settings/general/03-bottom.png"
  "settings/devices/01-top.png"
  "settings/devices/02-middle.png"
  "settings/devices/03-bottom.png"
  "settings/discovery/01-top.png"
  "settings/discovery/02-middle.png"
  "settings/discovery/03-bottom.png"
  "settings/nearcast/01-top.png"
  "settings/nearcast/02-middle.png"
  "settings/nearcast/03-bottom.png"
  "settings/display/01-top.png"
  "settings/display/02-middle.png"
  "settings/display/03-bottom.png"
  "settings/debug/01-top.png"
  "settings/debug/02-lower.png"
  "settings/display-configurations/01-earbud-merging-enabled.png"
  "settings/display-configurations/01-earbud-merging-off.png"
  "settings/display-preview/01-widgets.png"
  "settings/display-preview/02-large-widget.png"
  "widgets-in-situ/01-notification-center-context.png"
  "widgets-in-situ/02-airbattery-notification-center.png"
  "widgets-in-situ/03-notification-center-panel.png"
  "widgets-in-situ/04-desktop-context.png"
  "widgets-in-situ/05-airbattery-tight.png"
  "widget-editor/01-gallery.png"
  "widget-editor/02-gallery-airbattery.png"
  "widget-editor/03-gallery-airbattery-scrolled.png"
  "widget-editor/04-existing-widget-configuration-tight.png"
  "widget-editor/05-existing-widget-configuration-context.png"
)

ONLY_PATTERNS=()
SKIP_PATTERNS=()
ONLY_PATTERN_COUNT=0
SKIP_PATTERN_COUNT=0
OUT_ROOT="artifacts/gui-review"
OUT_ROOT_SET=0
LIST_TARGETS=0

usage(){
  cat <<'EOF'
Usage:
  capture_airbattery_gui.sh [output-root] [options]

Options:
  --only GLOB   Capture only targets matching GLOB. Repeatable.
  --skip GLOB   Exclude targets matching GLOB. Repeatable.
  --list        List selectable image targets and exit.
  -h, --help    Show this help.

Examples:
  capture_airbattery_gui.sh --only 'widget-editor/02-gallery-airbattery.png'
  capture_airbattery_gui.sh --only 'popover/*' --skip '*context*'
  capture_airbattery_gui.sh artifacts/gui-review --only 'settings/display/*'
EOF
}

matches_pattern(){
  value="$1"
  pattern="$2"
  case "$value" in
    $pattern) return 0 ;;
  esac
  return 1
}

pattern_matches_registry(){
  pattern="$1"
  for candidate in "${CAPTURE_TARGETS[@]}"; do
    matches_pattern "$candidate" "$pattern" && return 0
  done
  return 1
}

want_capture(){
  target="$1"

  if [ "$ONLY_PATTERN_COUNT" -gt 0 ]; then
    selected=0
    i=0
    while [ "$i" -lt "$ONLY_PATTERN_COUNT" ]; do
      pattern="${ONLY_PATTERNS[$i]}"
      if matches_pattern "$target" "$pattern"; then
        selected=1
        break
      fi
      i=$((i + 1))
    done
    [ "$selected" = "1" ] || return 1
  fi

  i=0
  while [ "$i" -lt "$SKIP_PATTERN_COUNT" ]; do
    pattern="${SKIP_PATTERNS[$i]}"
    matches_pattern "$target" "$pattern" && return 1
    i=$((i + 1))
  done

  return 0
}

want_group(){
  group_pattern="$1"
  for candidate in "${CAPTURE_TARGETS[@]}"; do
    if matches_pattern "$candidate" "$group_pattern" &&
       want_capture "$candidate"; then
      return 0
    fi
  done
  return 1
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --only)
      [ "$#" -ge 2 ] || { echo "--only requires a glob" >&2; exit 2; }
      ONLY_PATTERNS[$ONLY_PATTERN_COUNT]="$2"
      ONLY_PATTERN_COUNT=$((ONLY_PATTERN_COUNT + 1))
      shift 2
      ;;
    --only=*)
      ONLY_PATTERNS[$ONLY_PATTERN_COUNT]="${1#--only=}"
      ONLY_PATTERN_COUNT=$((ONLY_PATTERN_COUNT + 1))
      shift
      ;;
    --skip)
      [ "$#" -ge 2 ] || { echo "--skip requires a glob" >&2; exit 2; }
      SKIP_PATTERNS[$SKIP_PATTERN_COUNT]="$2"
      SKIP_PATTERN_COUNT=$((SKIP_PATTERN_COUNT + 1))
      shift 2
      ;;
    --skip=*)
      SKIP_PATTERNS[$SKIP_PATTERN_COUNT]="${1#--skip=}"
      SKIP_PATTERN_COUNT=$((SKIP_PATTERN_COUNT + 1))
      shift
      ;;
    --list)
      LIST_TARGETS=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      while [ "$#" -gt 0 ]; do
        if [ "$OUT_ROOT_SET" = "1" ]; then
          echo "Only one output-root positional argument is allowed." >&2
          exit 2
        fi
        OUT_ROOT="$1"
        OUT_ROOT_SET=1
        shift
      done
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      if [ "$OUT_ROOT_SET" = "1" ]; then
        echo "Only one output-root positional argument is allowed." >&2
        exit 2
      fi
      OUT_ROOT="$1"
      OUT_ROOT_SET=1
      shift
      ;;
  esac
done

if [ "$LIST_TARGETS" = "1" ]; then
  printf '%s\n' "${CAPTURE_TARGETS[@]}"
  exit 0
fi

i=0
while [ "$i" -lt "$ONLY_PATTERN_COUNT" ]; do
  pattern="${ONLY_PATTERNS[$i]}"
  if ! pattern_matches_registry "$pattern"; then
    echo "No capture target matches --only '$pattern'." >&2
    echo "Use --list to see selectable targets." >&2
    exit 2
  fi
  i=$((i + 1))
done

selected_count=0
for target in "${CAPTURE_TARGETS[@]}"; do
  if want_capture "$target"; then
    selected_count=$((selected_count + 1))
  fi
done
if [ "$selected_count" -eq 0 ]; then
  echo "No capture targets selected."
  exit 0
fi

STAMP="$(date +%Y%m%d-%H%M%S)"
OUT_DIR="${OUT_ROOT%/}/${STAMP}"
LOG_DIR="$OUT_DIR/_logs"
INDEX="$OUT_DIR/INDEX.md"
FAILURES="$OUT_DIR/FAILURES.md"
PREF_BACKUP=""
MUTATE_PREFS="${GUI_CAPTURE_MUTATE_PREFS:-1}"
CAPTURE_CONTEXT="${GUI_CAPTURE_CONTEXT:-1}"
STATUS_POINT="${AIRBATTERY_STATUS_POINT:-}"
WIDGET_POINT="${AIRBATTERY_WIDGET_POINT:-}"
# Distance from the right edge of the target display used by the
# coordinate fallback for Notification Center. The date/time item is
# right of the Control Center icon on the tested menu-bar layout.
NOTIFICATION_CENTER_RIGHT_INSET="${AIRBATTERY_NOTIFICATION_CENTER_RIGHT_INSET:-18}"
VISIBLE_APPS_FILE=""
APPS_HIDDEN=0
TEMP_WIDGET_ADDED=0
TEMP_WIDGET_FRAME=""
GALLERY_OWNER=""

mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_DIR/capture.log") 2>&1

log(){ printf '\n[%s] %s\n' "$(date '+%H:%M:%S')" "$*"; }
warn(){ printf 'WARNING: %s\n' "$*" >&2; }
need(){ command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1" >&2; exit 2; }; }

log "Capture selection: $selected_count of ${#CAPTURE_TARGETS[@]} selectable target(s)"

for x in xcrun osascript open defaults killall awk sed grep shasum cut cmp zip; do need "$x"; done
[ -x /usr/sbin/screencapture ] || { echo "Missing /usr/sbin/screencapture" >&2; exit 2; }

cat > "$INDEX" <<EOF
# AirBattery GUI Capture Set

Generated: $(date)

| File | Area | State | Verification |
|---|---|---|---|
EOF

cat > "$FAILURES" <<'EOF'
# Capture Failures

The script records a failure here instead of saving a screenshot under an
incorrect label when it cannot verify that the intended UI state was reached.

EOF

record(){
  printf '| `%s` | %s | %s | %s |\n' "$1" "$2" "$3" "$4" >> "$INDEX"
}

fail(){
  printf -- '- **%s** — %s\n' "$1" "$2" >> "$FAILURES"
  warn "$1: $2"
}

TMP="$(mktemp -d "${TMPDIR:-/tmp}/airbattery-gui-v8.XXXXXX")"
PREF_BACKUP="$TMP/original-defaults.plist"
HELPER_SRC="$TMP/helper.swift"
HELPER="$TMP/helper"

cat > "$HELPER_SRC" <<'SWIFT'
import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

func die(_ message: String, _ code: Int32 = 1) -> Never {
    fputs(message + "\n", stderr)
    exit(code)
}

func app(_ bundleID: String) -> NSRunningApplication? {
    NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first
}

func root(_ pid: pid_t) -> AXUIElement {
    AXUIElementCreateApplication(pid)
}

func value(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
    var result: CFTypeRef?
    let error = AXUIElementCopyAttributeValue(
        element,
        attribute as CFString,
        &result
    )
    return error == AXError.success ? result : nil
}

func string(_ element: AXUIElement, _ attribute: String) -> String? {
    if let text = value(element, attribute) as? String { return text }
    if let number = value(element, attribute) as? NSNumber {
        return number.stringValue
    }
    return nil
}

func role(_ element: AXUIElement) -> String {
    string(element, kAXRoleAttribute) ?? ""
}

func elementText(_ element: AXUIElement) -> String {
    [
        kAXTitleAttribute,
        kAXValueAttribute,
        kAXDescriptionAttribute,
        kAXIdentifierAttribute,
        kAXHelpAttribute,
        kAXRoleDescriptionAttribute,
    ]
    .compactMap { string(element, $0) }
    .joined(separator: " | ")
}

func children(_ element: AXUIElement) -> [AXUIElement] {
    (value(element, kAXChildrenAttribute) as? [AXUIElement]) ?? []
}

func parent(_ element: AXUIElement) -> AXUIElement? {
    guard let raw = value(element, kAXParentAttribute),
          CFGetTypeID(raw) == AXUIElementGetTypeID()
    else { return nil }
    return unsafeBitCast(raw, to: AXUIElement.self)
}

func frame(_ element: AXUIElement) -> CGRect? {
    guard
        let rawPosition = value(element, kAXPositionAttribute),
        let rawSize = value(element, kAXSizeAttribute),
        CFGetTypeID(rawPosition) == AXValueGetTypeID(),
        CFGetTypeID(rawSize) == AXValueGetTypeID()
    else { return nil }

    let position = unsafeBitCast(rawPosition, to: AXValue.self)
    let size = unsafeBitCast(rawSize, to: AXValue.self)
    var point = CGPoint.zero
    var dimensions = CGSize.zero

    guard
        AXValueGetValue(position, .cgPoint, &point),
        AXValueGetValue(size, .cgSize, &dimensions)
    else { return nil }

    return CGRect(origin: point, size: dimensions)
}

func descendants(
    _ element: AXUIElement,
    limit: Int = 8000
) -> [AXUIElement] {
    var queue = [element]
    var output: [AXUIElement] = []
    var index = 0
    while index < queue.count && output.count < limit {
        let current = queue[index]
        index += 1
        output.append(current)
        queue.append(contentsOf: children(current))
    }
    return output
}

func normalized(_ string: String) -> String {
    string.folding(
        options: [.caseInsensitive, .diacriticInsensitive],
        locale: .current
    )
}

func contains(_ element: AXUIElement, _ needle: String) -> Bool {
    normalized(elementText(element)).contains(normalized(needle))
}

func exact(_ element: AXUIElement, _ needle: String) -> Bool {
    let target = normalized(needle)
    let attributes = [
        kAXTitleAttribute,
        kAXValueAttribute,
        kAXDescriptionAttribute,
    ]
    return attributes.compactMap { string(element, $0) }
        .contains { normalized($0) == target }
}

func visibleFrame(_ element: AXUIElement) -> CGRect? {
    guard let f = frame(element), f.width >= 1, f.height >= 1 else {
        return nil
    }
    return f
}

func elements(bundleID: String) -> [AXUIElement] {
    guard let running = app(bundleID) else { return [] }
    return descendants(root(running.processIdentifier))
}

struct WindowInfo {
    let id: CGWindowID
    let pid: pid_t
    let layer: Int
    let bounds: CGRect
    let name: String
}

func allWindows() -> [WindowInfo] {
    guard let raw = CGWindowListCopyWindowInfo(
        [.optionOnScreenOnly, .excludeDesktopElements],
        kCGNullWindowID
    ) as? [[String: Any]]
    else { return [] }

    return raw.compactMap { item in
        guard
            let number = item[kCGWindowNumber as String] as? NSNumber,
            let pid = item[kCGWindowOwnerPID as String] as? NSNumber,
            let layer = item[kCGWindowLayer as String] as? NSNumber,
            let dict = item[kCGWindowBounds as String] as? [String: Any],
            let bounds = CGRect(
                dictionaryRepresentation: dict as CFDictionary
            )
        else { return nil }

        return WindowInfo(
            id: CGWindowID(number.uint32Value),
            pid: pid_t(pid.int32Value),
            layer: layer.intValue,
            bounds: bounds,
            name: item[kCGWindowName as String] as? String ?? ""
        )
    }
}

func appWindows(_ bundleID: String) -> [WindowInfo] {
    guard let running = app(bundleID) else { return [] }
    return allWindows().filter { $0.pid == running.processIdentifier }
}

func namedWindow(_ bundleID: String, _ needle: String) -> WindowInfo? {
    appWindows(bundleID)
        .filter { normalized($0.name).contains(normalized(needle)) }
        .max {
            $0.bounds.width * $0.bounds.height <
            $1.bounds.width * $1.bounds.height
        }
}

func menuWindow(_ bundleID: String) -> WindowInfo? {
    appWindows(bundleID)
        .filter {
            !normalized($0.name).contains("settings") &&
            $0.bounds.width >= 250 &&
            $0.bounds.width <= 700 &&
            $0.bounds.height >= 60 &&
            $0.bounds.height <= 1400
        }
        .sorted {
            if $0.layer != $1.layer { return $0.layer > $1.layer }
            return $0.bounds.width * $0.bounds.height >
                $1.bounds.width * $1.bounds.height
        }
        .first
}

func notificationPanelWindow() -> WindowInfo? {
    appWindows("com.apple.notificationcenterui")
        .filter {
            $0.bounds.width >= 280 &&
            $0.bounds.width <= 700 &&
            $0.bounds.height >= 420
        }
        .sorted {
            if $0.layer != $1.layer { return $0.layer > $1.layer }
            return $0.bounds.width * $0.bounds.height >
                $1.bounds.width * $1.bounds.height
        }
        .first
}

func mouseClick(_ p: CGPoint, right: Bool = false) {
    let source = CGEventSource(stateID: .hidSystemState)
    let button: CGMouseButton = right ? .right : .left
    let down: CGEventType = right ? .rightMouseDown : .leftMouseDown
    let up: CGEventType = right ? .rightMouseUp : .leftMouseUp

    CGEvent(
        mouseEventSource: source,
        mouseType: .mouseMoved,
        mouseCursorPosition: p,
        mouseButton: button
    )?.post(tap: .cghidEventTap)
    usleep(90_000)
    CGEvent(
        mouseEventSource: source,
        mouseType: down,
        mouseCursorPosition: p,
        mouseButton: button
    )?.post(tap: .cghidEventTap)
    usleep(70_000)
    CGEvent(
        mouseEventSource: source,
        mouseType: up,
        mouseCursorPosition: p,
        mouseButton: button
    )?.post(tap: .cghidEventTap)
}

func clickCenter(_ element: AXUIElement) -> Bool {
    guard let f = visibleFrame(element) else { return false }
    mouseClick(CGPoint(x: f.midX, y: f.midY))
    return true
}

func bestMatch(
    in source: [AXUIElement],
    needle: String,
    region: CGRect? = nil
) -> AXUIElement? {
    let candidates = source.compactMap { element -> (AXUIElement, CGRect, Int)? in
        guard
            (exact(element, needle) || contains(element, needle)),
            let f = visibleFrame(element)
        else { return nil }

        if let region, !region.intersects(f) { return nil }

        var score = 0
        if exact(element, needle) { score += 10_000 }
        if role(element) == kAXStaticTextRole { score += 500 }
        if role(element) == kAXButtonRole { score += 400 }
        score -= Int(min(f.width * f.height, 50_000) / 100)
        return (element, f, score)
    }

    return candidates.max { $0.2 < $1.2 }?.0
}

func clickText(
    bundleID: String,
    needle: String,
    region: CGRect? = nil
) -> Bool {
    guard let target = bestMatch(
        in: elements(bundleID: bundleID),
        needle: needle,
        region: region
    ) else { return false }
    return clickCenter(target)
}

func detailContains(
    bundleID: String,
    windowName: String,
    needle: String
) -> Bool {
    guard let w = namedWindow(bundleID, windowName) else { return false }
    let region = CGRect(
        x: w.bounds.minX + 221,
        y: w.bounds.minY,
        width: max(1, w.bounds.width - 221),
        height: w.bounds.height
    )
    return bestMatch(
        in: elements(bundleID: bundleID),
        needle: needle,
        region: region
    ) != nil
}

func sidebarClick(
    bundleID: String,
    windowName: String,
    label: String
) -> Bool {
    guard let w = namedWindow(bundleID, windowName) else { return false }
    let region = CGRect(
        x: w.bounds.minX,
        y: w.bounds.minY,
        width: min(220, w.bounds.width),
        height: w.bounds.height
    )
    return clickText(bundleID: bundleID, needle: label, region: region)
}

func preferredApps() -> [NSRunningApplication] {
    var seen = Set<pid_t>()
    var result: [NSRunningApplication] = []

    if let frontmost = NSWorkspace.shared.frontmostApplication,
       seen.insert(frontmost.processIdentifier).inserted {
        result.append(frontmost)
    }

    for bundle in [
        "com.apple.notificationcenterui",
        "com.apple.finder",
        "com.apple.controlcenter",
        "com.apple.SystemUIServer",
    ] {
        for running in NSRunningApplication.runningApplications(
            withBundleIdentifier: bundle
        ) where seen.insert(running.processIdentifier).inserted {
            result.append(running)
        }
    }

    return result
}

func globalBest(_ needle: String) -> AXUIElement? {
    for running in preferredApps() {
        if let found = bestMatch(
            in: descendants(root(running.processIdentifier), limit: 5000),
            needle: needle
        ) {
            return found
        }
    }
    return nil
}

func globalContains(_ needle: String) -> Bool {
    globalBest(needle) != nil
}

func bundleContains(_ bundleID: String, _ needle: String) -> Bool {
    bestMatch(in: elements(bundleID: bundleID), needle: needle) != nil
}

func frameInBundle(_ bundleID: String, _ needle: String) -> CGRect? {
    guard let found = bestMatch(
        in: elements(bundleID: bundleID),
        needle: needle
    ) else { return nil }
    return visibleFrame(found)
}

func clickGlobal(_ needle: String) -> Bool {
    guard let found = globalBest(needle) else { return false }
    return clickCenter(found)
}

func searchField(in running: NSRunningApplication) -> AXUIElement? {
    descendants(root(running.processIdentifier), limit: 5000).first {
        let r = role($0)
        let subrole = string($0, kAXSubroleAttribute) ?? ""
        guard r == kAXTextFieldRole || normalized(subrole).contains("search")
        else { return false }
        return visibleFrame($0) != nil
    }
}

func globalSearchField() -> AXUIElement? {
    for running in preferredApps() {
        if let found = searchField(in: running) { return found }
    }
    return nil
}

func bundleSearchField(_ bundleID: String) -> AXUIElement? {
    guard let running = app(bundleID) else { return nil }
    return searchField(in: running)
}

func setBundleSearch(_ bundleID: String, value newValue: String) -> Bool {
    guard let field = bundleSearchField(bundleID) else { return false }
    guard AXUIElementSetAttributeValue(
        field,
        kAXValueAttribute as CFString,
        newValue as CFTypeRef
    ) == AXError.success
    else { return false }

    _ = AXUIElementPerformAction(field, kAXConfirmAction as CFString)
    return true
}

func galleryMarkerScore(
    running: NSRunningApplication,
    allElements: [AXUIElement]
) -> Int {
    guard searchField(in: running) != nil else { return Int.min }

    func has(_ needle: String) -> Bool {
        bestMatch(in: allElements, needle: needle) != nil
    }

    var score = 0
    var markers = 0

    // These controls/content are specific to the macOS widget editor rather
    // than an arbitrary application's search field.
    for marker in [
        "Done",
        "Widgets",
        "Edit Widgets",
        "Calendar",
        "Clock",
        "Weather",
        "Photos",
        "Reminders",
        "Notes",
    ] {
        if has(marker) {
            markers += 1
            score += 18
        }
    }

    if let bundleID = running.bundleIdentifier {
        if bundleID == "com.apple.notificationcenterui" {
            score += 120
        } else if bundleID == "com.apple.finder" {
            score += 20
        }
    }

    // One generic marker is not enough for an arbitrary Apple app with a
    // search field. NotificationCenter gets a stronger prior because it owns
    // the widget editing UI on current macOS releases.
    if running.bundleIdentifier == "com.apple.notificationcenterui" {
        guard markers >= 1 else { return Int.min }
    } else {
        guard markers >= 2 else { return Int.min }
    }

    return score
}

func galleryOwnerBundleID() -> String? {
    let preferred = [
        "com.apple.notificationcenterui",
        "com.apple.finder",
        "com.apple.controlcenter",
        "com.apple.SystemUIServer",
    ]

    var seen = Set<pid_t>()
    var candidates: [(String, Int)] = []

    func consider(_ running: NSRunningApplication) {
        guard seen.insert(running.processIdentifier).inserted,
              let bundleID = running.bundleIdentifier,
              bundleID.hasPrefix("com.apple.")
        else { return }

        let allElements = descendants(
            root(running.processIdentifier),
            limit: 7000
        )
        let score = galleryMarkerScore(
            running: running,
            allElements: allElements
        )
        guard score != Int.min else { return }
        candidates.append((bundleID, score))
    }

    for bundleID in preferred {
        for running in NSRunningApplication.runningApplications(
            withBundleIdentifier: bundleID
        ) {
            consider(running)
        }
    }

    // Fallback for future macOS releases that move the gallery into another
    // Apple-owned process. The marker test above keeps this from accepting an
    // arbitrary app's search field.
    for running in NSWorkspace.shared.runningApplications {
        consider(running)
    }

    return candidates.max(by: { $0.1 < $1.1 })?.0
}

func statusItemFrame(_ bundleID: String) -> CGRect? {
    guard let running = app(bundleID) else { return nil }
    let candidates = descendants(root(running.processIdentifier), limit: 5000)
        .compactMap { element -> (CGRect, Int)? in
            guard let f = visibleFrame(element),
                  f.height > 8, f.height < 45,
                  f.width > 10, f.width < 120
            else { return nil }

            var score = 0
            if role(element) == kAXMenuBarItemRole { score += 60 }
            if role(element) == kAXButtonRole { score += 20 }
            if contains(element, "AirBattery") { score += 120 }
            if f.width >= 30 && f.width <= 60 { score += 15 }
            return score > 0 ? (f, score) : nil
        }
    return candidates.max(by: { $0.1 < $1.1 })?.0
}

func widgetContainerFrame(
    _ bundleID: String,
    _ needle: String,
    region: CGRect? = nil
) -> CGRect? {
    let matches = elements(bundleID: bundleID).filter {
        guard contains($0, needle), let f = visibleFrame($0) else {
            return false
        }
        if let region {
            return region.intersects(f)
        }
        return true
    }

    var candidates: [(CGRect, Int)] = []
    for match in matches {
        var current: AXUIElement? = match
        for depth in 0..<9 {
            guard let element = current else { break }
            if let f = visibleFrame(element),
               f.width >= 100, f.width <= 700,
               f.height >= 80, f.height <= 700 {
                if let region {
                    let center = CGPoint(x: f.midX, y: f.midY)
                    guard region.contains(center) else {
                        current = parent(element)
                        continue
                    }
                }

                let area = f.width * f.height
                var score = 0
                if area >= 12_000 && area <= 300_000 { score += 2_000 }
                if role(element) == kAXGroupRole { score += 1_000 }
                score -= depth * 60
                score -= Int(area / 800)
                candidates.append((f, score))
            }
            current = parent(element)
        }
    }
    return candidates.max(by: { $0.1 < $1.1 })?.0
}

func notificationWidgetFrame(_ needle: String) -> CGRect? {
    guard let panel = notificationPanelWindow() else { return nil }
    return widgetContainerFrame(
        "com.apple.notificationcenterui",
        needle,
        region: panel.bounds
    )
}

func searchFieldFrame() -> CGRect? {
    guard let field = globalSearchField() else { return nil }
    return visibleFrame(field)
}

func bundleSearchFieldFrame(_ bundleID: String) -> CGRect? {
    guard let field = bundleSearchField(bundleID) else { return nil }
    return visibleFrame(field)
}

func scroll(_ p: CGPoint, dy: Int32) {
    let source = CGEventSource(stateID: .hidSystemState)
    guard let event = CGEvent(
        scrollWheelEvent2Source: source,
        units: .pixel,
        wheelCount: 1,
        wheel1: dy,
        wheel2: 0,
        wheel3: 0
    ) else { return }
    event.location = p
    event.post(tap: .cghidEventTap)
}


func thumbnailRGBA(_ path: String, size: Int = 96) -> [UInt8]? {
    guard let image = NSImage(contentsOfFile: path) else { return nil }
    var proposed = CGRect(
        origin: .zero,
        size: NSSize(width: image.size.width, height: image.size.height)
    )
    guard let cgImage = image.cgImage(
        forProposedRect: &proposed,
        context: nil,
        hints: nil
    ) else { return nil }

    var pixels = [UInt8](repeating: 0, count: size * size * 4)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let ok = pixels.withUnsafeMutableBytes { raw -> Bool in
        guard let context = CGContext(
            data: raw.baseAddress,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return false }
        context.interpolationQuality = .medium
        context.draw(
            cgImage,
            in: CGRect(x: 0, y: 0, width: size, height: size)
        )
        return true
    }
    return ok ? pixels : nil
}

func imageRMSE(_ lhs: String, _ rhs: String) -> Double? {
    guard
        let a = thumbnailRGBA(lhs),
        let b = thumbnailRGBA(rhs),
        a.count == b.count
    else { return nil }

    var sum = 0.0
    var samples = 0
    var i = 0
    while i + 3 < a.count {
        for channel in 0..<3 {
            let delta = Double(Int(a[i + channel]) - Int(b[i + channel]))
            sum += delta * delta
            samples += 1
        }
        i += 4
    }
    guard samples > 0 else { return nil }
    return sqrt(sum / Double(samples)) / 255.0
}

func int32(_ value: String) -> Int32 {
    guard let result = Int32(value) else { die("invalid integer", 2) }
    return result
}

let args = Array(CommandLine.arguments.dropFirst())
guard let command = args.first else { die("missing command", 2) }

switch command {
case "ax":
    let prompt = args.dropFirst().first == "prompt"
    let options = [
        kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt
    ] as CFDictionary
    print(AXIsProcessTrustedWithOptions(options) ? "1" : "0")

case "screen":
    if CGPreflightScreenCaptureAccess() {
        print("1")
    } else if args.dropFirst().first == "prompt" {
        print(CGRequestScreenCaptureAccess() ? "1" : "0")
    } else {
        print("0")
    }

case "pid":
    guard args.count > 1, let running = app(args[1]) else { exit(1) }
    print(running.processIdentifier)

case "window":
    guard args.count > 2, let w = namedWindow(args[1], args[2])
    else { exit(1) }
    print(w.id)

case "windowFrame":
    guard args.count > 2, let w = namedWindow(args[1], args[2])
    else { exit(1) }
    print("\(Int(w.bounds.minX)),\(Int(w.bounds.minY)),\(Int(w.bounds.width)),\(Int(w.bounds.height))")

case "menu":
    guard args.count > 1, let w = menuWindow(args[1]) else { exit(1) }
    print(w.id)

case "menuFrame":
    guard args.count > 1, let w = menuWindow(args[1]) else { exit(1) }
    print("\(Int(w.bounds.minX)),\(Int(w.bounds.minY)),\(Int(w.bounds.width)),\(Int(w.bounds.height))")

case "notificationPanel":
    guard let w = notificationPanelWindow() else { exit(1) }
    print(w.id)

case "notificationPanelFrame":
    guard let w = notificationPanelWindow() else { exit(1) }
    print("\(Int(w.bounds.minX)),\(Int(w.bounds.minY)),\(Int(w.bounds.width)),\(Int(w.bounds.height))")

case "sidebar":
    guard args.count > 3,
          sidebarClick(bundleID: args[1], windowName: args[2], label: args[3])
    else { exit(1) }

case "detailHas":
    guard args.count > 3,
          detailContains(bundleID: args[1], windowName: args[2], needle: args[3])
    else { exit(1) }

case "clickAppText":
    guard args.count > 2,
          clickText(bundleID: args[1], needle: args[2])
    else { exit(1) }

case "clickGlobal":
    guard args.count > 1, clickGlobal(args[1]) else { exit(1) }

case "globalHas":
    guard args.count > 1, globalContains(args[1]) else { exit(1) }

case "bundleHas":
    guard args.count > 2, bundleContains(args[1], args[2]) else { exit(1) }

case "bundleFrame":
    guard args.count > 2, let f = frameInBundle(args[1], args[2])
    else { exit(1) }
    print("\(Int(f.minX)),\(Int(f.minY)),\(Int(f.width)),\(Int(f.height))")

case "hasSearch":
    guard globalSearchField() != nil else { exit(1) }

case "setSearch":
    guard args.count > 1, let field = globalSearchField() else { exit(1) }
    guard AXUIElementSetAttributeValue(
        field,
        kAXValueAttribute as CFString,
        args[1] as CFTypeRef
    ) == AXError.success
    else { exit(1) }
    _ = AXUIElementPerformAction(field, kAXConfirmAction as CFString)

case "galleryOwner":
    guard let bundleID = galleryOwnerBundleID() else { exit(1) }
    print(bundleID)

case "bundleHasSearch":
    guard args.count > 1, bundleSearchField(args[1]) != nil else { exit(1) }

case "bundleSetSearch":
    guard args.count > 2,
          setBundleSearch(args[1], value: args[2])
    else { exit(1) }

case "bundleSearchFrame":
    guard args.count > 1,
          let f = bundleSearchFieldFrame(args[1])
    else { exit(1) }
    print("\(Int(f.minX)),\(Int(f.minY)),\(Int(f.width)),\(Int(f.height))")

case "notificationWidgetFrame":
    guard args.count > 1,
          let f = notificationWidgetFrame(args[1])
    else { exit(1) }
    print("\(Int(f.minX)),\(Int(f.minY)),\(Int(f.width)),\(Int(f.height))")

case "scrollWindow":
    guard args.count > 3, let w = namedWindow(args[1], args[2])
    else { exit(1) }
    let dy = int32(args[3])
    let p = CGPoint(
        x: w.bounds.minX + max(260, w.bounds.width * 0.62),
        y: w.bounds.midY
    )
    for _ in 0..<5 {
        scroll(p, dy: dy / 5)
        usleep(60_000)
    }

case "click":
    guard args.count > 2 else { exit(2) }
    mouseClick(CGPoint(
        x: CGFloat(int32(args[1])),
        y: CGFloat(int32(args[2]))
    ))

case "right":
    guard args.count > 2 else { exit(2) }
    mouseClick(
        CGPoint(
            x: CGFloat(int32(args[1])),
            y: CGFloat(int32(args[2]))
        ),
        right: true
    )

case "scrollPoint":
    guard args.count > 3 else { exit(2) }
    scroll(
        CGPoint(
            x: CGFloat(int32(args[1])),
            y: CGFloat(int32(args[2]))
        ),
        dy: int32(args[3])
    )

case "mouse":
    guard let event = CGEvent(source: nil) else { exit(1) }
    print("\(Int(event.location.x)),\(Int(event.location.y))")

case "status":
    guard args.count > 1, let f = statusItemFrame(args[1]) else { exit(1) }
    print("\(Int(f.midX)),\(Int(f.midY))")

case "statusFrame":
    guard args.count > 1, let f = statusItemFrame(args[1]) else { exit(1) }
    print("\(Int(f.minX)),\(Int(f.minY)),\(Int(f.width)),\(Int(f.height))")

case "widgetFrame":
    guard args.count > 2, let f = widgetContainerFrame(args[1], args[2]) else { exit(1) }
    print("\(Int(f.minX)),\(Int(f.minY)),\(Int(f.width)),\(Int(f.height))")

case "searchFrame":
    guard let f = searchFieldFrame() else { exit(1) }
    print("\(Int(f.minX)),\(Int(f.minY)),\(Int(f.width)),\(Int(f.height))")

case "imageRMSE":
    guard args.count > 2, let result = imageRMSE(args[1], args[2])
    else { exit(1) }
    print(String(format: "%.8f", result))

case "displayCount":
    var count: UInt32 = 0
    CGGetActiveDisplayList(0, nil, &count)
    print(count)

case "displayFrame":
    guard args.count > 1, let index = Int(args[1]), index > 0
    else { exit(2) }
    var count: UInt32 = 0
    CGGetActiveDisplayList(0, nil, &count)
    var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
    CGGetActiveDisplayList(count, &ids, &count)
    guard index <= Int(count) else { exit(1) }
    let f = CGDisplayBounds(ids[index - 1])
    print("\(Int(f.minX)),\(Int(f.minY)),\(Int(f.width)),\(Int(f.height))")

case "mainFrame":
    let f = CGDisplayBounds(CGMainDisplayID())
    print("\(Int(f.minX)),\(Int(f.minY)),\(Int(f.width)),\(Int(f.height))")

default:
    die("unknown command: \(command)", 2)
}
SWIFT

log "Compiling macOS Accessibility helper"
xcrun swiftc -O \
  -framework AppKit \
  -framework ApplicationServices \
  -framework CoreGraphics \
  "$HELPER_SRC" -o "$HELPER"

if [ "$("$HELPER" ax prompt)" != "1" ]; then
  echo "Accessibility permission is required for this terminal." >&2
  exit 3
fi
if [ "$("$HELPER" screen prompt)" != "1" ]; then
  echo "Screen Recording permission is required for this terminal." >&2
  exit 3
fi

PREFS_EXISTED=0
PREFS_RESTORED=0
if defaults export "$BUNDLE_ID" "$PREF_BACKUP" >/dev/null 2>&1; then
  PREFS_EXISTED=1
fi

ORIG_TWS_MERGE_ENABLED="$(defaults read "$BUNDLE_ID" twsMergeEnabled 2>/dev/null || echo 1)"
case "$ORIG_TWS_MERGE_ENABLED" in
  0|1) ;;
  *) ORIG_TWS_MERGE_ENABLED=1 ;;
esac

save_and_hide_gui_apps(){
  [ "$APPS_HIDDEN" = "1" ] && return 0
  VISIBLE_APPS_FILE="$TMP/visible-apps.txt"
  osascript <<'APPLESCRIPT' > "$VISIBLE_APPS_FILE" 2>/dev/null || true
tell application "System Events"
  set xs to name of every application process whose visible is true and background only is false
  set AppleScript's text item delimiters to linefeed
  return xs as text
end tell
APPLESCRIPT

  while IFS= read -r app_name; do
    [ -z "$app_name" ] && continue
    case "$app_name" in
      Finder|AirBattery) continue ;;
    esac
    APP_TO_HIDE="$app_name" osascript <<'APPLESCRIPT' >/dev/null 2>&1 || true
tell application "System Events"
  set n to system attribute "APP_TO_HIDE"
  if exists application process n then set visible of application process n to false
end tell
APPLESCRIPT
  done < "$VISIBLE_APPS_FILE"
  APPS_HIDDEN=1
  sleep 0.8
}

restore_gui_apps(){
  [ "$APPS_HIDDEN" = "1" ] || return 0
  if [ -n "$VISIBLE_APPS_FILE" ] && [ -f "$VISIBLE_APPS_FILE" ]; then
    while IFS= read -r app_name; do
      [ -z "$app_name" ] && continue
      case "$app_name" in
        Finder|AirBattery) continue ;;
      esac
      APP_TO_SHOW="$app_name" osascript <<'APPLESCRIPT' >/dev/null 2>&1 || true
tell application "System Events"
  set n to system attribute "APP_TO_SHOW"
  if exists application process n then set visible of application process n to true
end tell
APPLESCRIPT
    done < "$VISIBLE_APPS_FILE"
  fi
  APPS_HIDDEN=0
}

restore(){
  [ "$PREFS_RESTORED" = "1" ] && return 0
  killall "$APP_NAME" >/dev/null 2>&1 || true
  if [ "$PREFS_EXISTED" = "1" ]; then
    defaults import "$BUNDLE_ID" "$PREF_BACKUP" >/dev/null 2>&1 || true
  else
    defaults delete "$BUNDLE_ID" >/dev/null 2>&1 || true
  fi
  PREFS_RESTORED=1
}

cleanup(){
  rc=$?
  if [ "$TEMP_WIDGET_ADDED" = "1" ] && declare -F remove_temporary_widget >/dev/null 2>&1; then
    remove_temporary_widget "cleanup" || true
  fi
  restore_gui_apps
  log "Restoring original AirBattery preferences"
  restore
  open -b "$BUNDLE_ID" >/dev/null 2>&1 || true
  rm -rf "$TMP"
  exit "$rc"
}
trap cleanup EXIT INT TERM

resetprefs(){
  PREFS_RESTORED=0
  restore
  PREFS_RESTORED=0
}

launch_fresh(){
  open -b "$BUNDLE_ID" >/dev/null 2>&1 || open -a "$APP_NAME" >/dev/null 2>&1
  sleep 3
}

restart(){
  killall "$APP_NAME" >/dev/null 2>&1 || true
  sleep 0.7
  launch_fresh
}

# Restore the user's baseline while AirBattery is NOT running. A running
# UserDefaults instance can otherwise flush its cached value while terminating
# and overwrite an immediately preceding `defaults write`.
stage_baseline_offline(){
  killall "$APP_NAME" >/dev/null 2>&1 || true
  sleep 0.7
  if [ "$PREFS_EXISTED" = "1" ]; then
    defaults import "$BUNDLE_ID" "$PREF_BACKUP" >/dev/null 2>&1
  else
    defaults delete "$BUNDLE_ID" >/dev/null 2>&1 || true
  fi
  PREFS_RESTORED=0
}

pref(){
  defaults write "$BUNDLE_ID" "$1" "$2" "$3"
}

stage_variant(){
  stage_baseline_offline
  # Arguments are groups of: key type value.
  while [ "$#" -ge 3 ]; do
    pref "$1" "$2" "$3"
    shift 3
  done
  launch_fresh
}

pref_is(){
  key="$1"; expected="$2"
  actual="$(defaults read "$BUNDLE_ID" "$key" 2>/dev/null || true)"
  [ "$actual" = "$expected" ]
}

capwin(){
  rel="$1"; id="$2"; area="$3"; state="$4"; verification="$5"
  want_capture "$rel" || return 0
  mkdir -p "$(dirname "$OUT_DIR/$rel")"
  if /usr/sbin/screencapture -x -l "$id" "$OUT_DIR/$rel" >/dev/null 2>&1; then
    record "$rel" "$area" "$state" "$verification"
    log "Captured $rel"
    return 0
  fi
  return 1
}

capreg(){
  rel="$1"; rect="$2"; area="$3"; state="$4"; verification="$5"
  want_capture "$rel" || return 0
  mkdir -p "$(dirname "$OUT_DIR/$rel")"
  if /usr/sbin/screencapture -x -R "$rect" "$OUT_DIR/$rel" >/dev/null 2>&1; then
    record "$rel" "$area" "$state" "$verification"
    log "Captured $rel"
    return 0
  fi
  return 1
}

capdisplay(){
  rel="$1"; display="$2"; area="$3"; state="$4"; verification="$5"
  want_capture "$rel" || return 0
  mkdir -p "$(dirname "$OUT_DIR/$rel")"
  if /usr/sbin/screencapture -x -D "$display" "$OUT_DIR/$rel" >/dev/null 2>&1; then
    record "$rel" "$area" "$state" "$verification"
    log "Captured $rel"
    return 0
  fi
  return 1
}

capall(){
  prefix="$1"; area="$2"; state="$3"; verification="$4"
  n="$("$HELPER" displayCount)"
  d=1
  while [ "$d" -le "$n" ]; do
    capdisplay "${prefix}-display-${d}.png" "$d" "$area" "$state" \
      "$verification; display $d" || true
    d=$((d + 1))
  done
}

capture_temp_window(){
  id="$1"; path="$2"
  /usr/sbin/screencapture -x -l "$id" "$path" >/dev/null 2>&1
}

capture_temp_display(){
  display="$1"; path="$2"
  /usr/sbin/screencapture -x -D "$display" "$path" >/dev/null 2>&1
}

display_for_point(){
  px="$1"; py="$2"
  n="$("$HELPER" displayCount)"
  d=1
  while [ "$d" -le "$n" ]; do
    f="$("$HELPER" displayFrame "$d")"
    fx="$(printf '%s' "$f" | cut -d, -f1)"
    fy="$(printf '%s' "$f" | cut -d, -f2)"
    fw="$(printf '%s' "$f" | cut -d, -f3)"
    fh="$(printf '%s' "$f" | cut -d, -f4)"
    if [ "$px" -ge "$fx" ] && [ "$px" -lt $((fx+fw)) ] &&
       [ "$py" -ge "$fy" ] && [ "$py" -lt $((fy+fh)) ]; then
      echo "$d"
      return 0
    fi
    d=$((d+1))
  done
  return 1
}

display_for_frame(){
  f="$1"
  x="$(printf '%s' "$f" | cut -d, -f1)"
  y="$(printf '%s' "$f" | cut -d, -f2)"
  w="$(printf '%s' "$f" | cut -d, -f3)"
  h="$(printf '%s' "$f" | cut -d, -f4)"
  display_for_point $((x+w/2)) $((y+h/2))
}


image_rmse(){
  "$HELPER" imageRMSE "$1" "$2" 2>/dev/null || echo 1
}

meaningfully_different(){
  a="$1"; b="$2"; threshold="${3:-0.0045}"
  score="$(image_rmse "$a" "$b")"
  awk -v s="$score" -v t="$threshold" 'BEGIN { exit !(s >= t) }'
}

save_capture(){
  source="$1"; dest="$2"; area="$3"; state="$4"; verification="$5"
  want_capture "$dest" || return 0
  mkdir -p "$(dirname "$OUT_DIR/$dest")"
  cp "$source" "$OUT_DIR/$dest"
  record "$dest" "$area" "$state" "$verification"
  log "Captured $dest"
}

save_unique(){
  source="$1"; dest="$2"; reference="$3"; area="$4"; state="$5"; verification="$6"
  want_capture "$dest" || return 0
  mkdir -p "$(dirname "$OUT_DIR/$dest")"
  if [ -n "$reference" ] && [ -f "$reference" ] &&
     ! meaningfully_different "$source" "$reference"; then
    log "Skipped visually redundant capture: $dest"
    return 1
  fi
  cp "$source" "$OUT_DIR/$dest"
  record "$dest" "$area" "$state" "$verification"
  log "Captured $dest"
}

wait_cmd(){
  attempts="$1"
  shift
  i=0
  while [ "$i" -lt "$attempts" ]; do
    if "$@" >/dev/null 2>&1; then return 0; fi
    sleep 0.2
    i=$((i + 1))
  done
  return 1
}

xy(){
  printf '%s\n' "$1" | awk -F, '{print $1, $2}'
}

closeui(){
  osascript -e 'tell application "System Events" to key code 53' >/dev/null 2>&1 || true
  sleep 0.35
}

statuspoint(){
  [ -n "$STATUS_POINT" ] && return 0
  STATUS_POINT="$("$HELPER" status "$BUNDLE_ID" 2>/dev/null || true)"
  if [ -n "$STATUS_POINT" ]; then
    log "Found status item at $STATUS_POINT"
    return 0
  fi

  if [ ! -t 0 ]; then
    fail "menu-bar calibration" "AirBattery status item was not exposed through Accessibility."
    return 1
  fi

  echo
  echo "Move the pointer to the CENTER of the AirBattery menu-bar item, then press Return."
  read -r _
  STATUS_POINT="$("$HELPER" mouse)"
  log "Calibrated status item at $STATUS_POINT"
}

capstatus(){
  label="$1"; notes="$2"
  rel="menubar/${label}.png"
  want_capture "$rel" || return 0
  statuspoint || return 0
  sf="$("$HELPER" statusFrame "$BUNDLE_ID" 2>/dev/null || true)"
  if [ -n "$sf" ]; then
    rect="$(printf '%s' "$sf" | awk -F, '{printf "%d,%d,%d,%d",$1-5,$2-5,$3+10,$4+10}')"
    capreg "$rel" "$rect" \
      "Menu bar" "$label" "verified AX status-item frame; $notes" || true
  else
    set -- $(xy "$STATUS_POINT")
    x="$1"; y="$2"
    capreg "$rel" "$((x-42)),$((y-19)),84,38" \
      "Menu bar" "$label" "calibrated status coordinate fallback; $notes" || true
  fi
}

open_popover(){
  statuspoint || return 1
  closeui
  set -- $(xy "$STATUS_POINT")
  "$HELPER" click "$1" "$2" >/dev/null 2>&1 || true
  wait_cmd 15 "$HELPER" menu "$BUNDLE_ID"
}

wait_for_airpods_ready(){
  timeout_seconds="${1:-40}"
  elapsed=0
  log "Waiting for AirPods inventory to repopulate"
  while [ "$elapsed" -lt "$timeout_seconds" ]; do
    if open_popover; then
      if "$HELPER" bundleHas "$BUNDLE_ID" "Show components" >/dev/null 2>&1; then
        closeui
        log "AirPods compound row is available"
        return 0
      fi
      closeui
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done
  return 1
}

capture_open_popover(){
  rel="$1"; state="$2"; verification="$3"
  id="$("$HELPER" menu "$BUNDLE_ID" 2>/dev/null || true)"
  if [ -z "$id" ]; then
    fail "$state" "AirBattery popover/menu window could not be verified."
    return 1
  fi
  capwin "$rel" "$id" "Popover" "$state" "$verification"
}

capture_popover_collapsed(){
  label="$1"; notes="$2"
  rel="popover/${label}.png"
  context_rel="popover/01-current-collapsed-context.png"
  want_base=0
  want_context=0
  want_capture "$rel" && want_base=1
  if [ "$CAPTURE_CONTEXT" = "1" ] &&
     [ "$label" = "01-current-collapsed" ] &&
     want_capture "$context_rel"; then
    want_context=1
  fi
  [ "$want_base" = "1" ] || [ "$want_context" = "1" ] || return 0

  if open_popover; then
    if [ "$want_base" = "1" ]; then
      capture_open_popover "$rel" "$label" \
        "AirBattery menu window exists; $notes" || true
    fi
    if [ "$want_context" = "1" ]; then
      mf="$("$HELPER" menuFrame "$BUNDLE_ID" 2>/dev/null || true)"
      if [ -n "$mf" ]; then
        d="$(display_for_frame "$mf" 2>/dev/null || true)"
        [ -n "$d" ] && capdisplay "$context_rel" "$d" \
          "Popover" "current collapsed / in situ" \
          "display containing the verified AirBattery menu window" || true
      fi
    fi
  else
    fail "$label" "Could not open AirBattery popover."
  fi
  closeui
}

capture_popover_airpods_expanded(){
  label="$1"; notes="$2"
  rel="popover/${label}-airpods-expanded.png"
  want_capture "$rel" || return 0
  if ! open_popover; then
    fail "$label expanded" "Could not open AirBattery popover."
    return 0
  fi

  before="$("$HELPER" menuFrame "$BUNDLE_ID" 2>/dev/null || true)"
  before_h="$(printf '%s' "$before" | cut -d, -f4)"

  # The compound AirPods row is not itself the disclosure control. Click the
  # actual SwiftUI disclosure button, which is exposed through its help text.
  if ! "$HELPER" clickAppText "$BUNDLE_ID" "Show components" >/dev/null 2>&1; then
    fail "$label expanded" \
      "The AirPods row was present, but its 'Show components' disclosure button was not exposed."
    closeui
    return 0
  fi

  sleep 0.8
  after="$("$HELPER" menuFrame "$BUNDLE_ID" 2>/dev/null || true)"
  after_h="$(printf '%s' "$after" | cut -d, -f4)"

  if ! "$HELPER" bundleHas "$BUNDLE_ID" "Collapse components" >/dev/null 2>&1 &&
     { [ -z "$after_h" ] || [ "$after_h" -le $((before_h + 12)) ]; }; then
    fail "$label expanded" \
      "Disclosure was clicked but neither 'Collapse components' nor a larger menu frame was observed."
    closeui
    return 0
  fi

  capture_open_popover "$rel" \
    "$label / AirPods expanded" \
    "clicked the real 'Show components' disclosure and verified expansion; $notes" || true
  closeui
}

open_settings(){
  open 'airbattery://settings' >/dev/null 2>&1 || true
  if wait_cmd 20 "$HELPER" window "$BUNDLE_ID" "AirBattery Settings"; then
    return 0
  fi

  osascript \
    -e 'tell application "AirBattery" to activate' \
    -e 'tell application "System Events" to tell process "AirBattery" to keystroke "," using command down' \
    >/dev/null 2>&1 || true

  wait_cmd 20 "$HELPER" window "$BUNDLE_ID" "AirBattery Settings"
}

settings_id(){
  "$HELPER" window "$BUNDLE_ID" "AirBattery Settings" 2>/dev/null || true
}

scrolltop(){
  "$HELPER" scrollWindow "$BUNDLE_ID" "AirBattery Settings" 2600 >/dev/null 2>&1 || true
  "$HELPER" scrollWindow "$BUNDLE_ID" "AirBattery Settings" 2600 >/dev/null 2>&1 || true
  sleep 0.25
}

scrolldown(){
  "$HELPER" scrollWindow "$BUNDLE_ID" "AirBattery Settings" "${1:--1050}" >/dev/null 2>&1 || true
  sleep 0.3
}

navigate_settings(){
  label="$1"; verify="$2"
  if ! "$HELPER" sidebar "$BUNDLE_ID" "AirBattery Settings" "$label" >/dev/null 2>&1; then
    fail "Settings / $label" "Sidebar label could not be clicked by its actual screen frame."
    return 1
  fi

  if ! wait_cmd 15 "$HELPER" detailHas "$BUNDLE_ID" "AirBattery Settings" "$verify"; then
    fail "Settings / $label" \
      "Sidebar click occurred, but destination text '$verify' did not appear in the detail pane."
    return 1
  fi

  log "Verified Settings section: $label"
  return 0
}

capsettings(){
  rel="$1"; section="$2"; state="$3"; verification="$4"
  id="$(settings_id)"
  [ -n "$id" ] || return 1
  capwin "$rel" "$id" "Settings / $section" "$state" "$verification"
}

capture_settings_sweep(){
  section="$1"; slug="$2"; verify="$3"
  top_rel="settings/$slug/01-top.png"
  middle_rel="settings/$slug/02-middle.png"
  bottom_rel="settings/$slug/03-bottom.png"

  want_top=0
  want_middle=0
  want_bottom=0
  want_capture "$top_rel" && want_top=1
  want_capture "$middle_rel" && want_middle=1
  want_capture "$bottom_rel" && want_bottom=1
  [ "$want_top" = "1" ] || [ "$want_middle" = "1" ] || [ "$want_bottom" = "1" ] || return 0

  navigate_settings "$section" "$verify" || return 0
  scrolltop

  first="$TMP/${slug}-top.png"
  second="$TMP/${slug}-middle.png"
  third="$TMP/${slug}-bottom.png"
  id="$(settings_id)"

  capture_temp_window "$id" "$first"
  if [ "$want_top" = "1" ]; then
    save_capture "$first" "$top_rel" \
      "Settings / $section" "top" "verified detail text: $verify"
  fi

  if [ "$want_middle" = "1" ] || [ "$want_bottom" = "1" ]; then
    scrolldown -1050
    capture_temp_window "$id" "$second"
    if [ "$want_middle" = "1" ]; then
      save_unique "$second" "$middle_rel" "$first" \
        "Settings / $section" "middle" \
        "verified detail text; perceptually distinct from top" || true
    fi
  fi

  if [ "$want_bottom" = "1" ]; then
    scrolldown -1900
    capture_temp_window "$id" "$third"
    if meaningfully_different "$third" "$first" &&
       meaningfully_different "$third" "$second"; then
      save_capture "$third" "$bottom_rel" \
        "Settings / $section" "bottom" \
        "verified detail text; perceptually distinct lower state"
    else
      log "Skipped visually redundant lower Settings capture: $section"
    fi
  fi
}

capture_display_variant(){
  slug="$1"; notes="$2"; verify_present="${3:-}"; verify_absent="${4:-}"
  rel="settings/display-configurations/${slug}.png"
  want_capture "$rel" || return 0
  if ! open_settings; then
    fail "Display variant $slug" "Settings did not open after staged preference change."
    return 0
  fi
  if ! navigate_settings "Display" "Choose where AirBattery appears"; then
    return 0
  fi

  if [ -n "$verify_present" ] &&
     ! "$HELPER" detailHas "$BUNDLE_ID" "AirBattery Settings" "$verify_present" >/dev/null 2>&1; then
    fail "Display variant $slug" "Expected visible control '$verify_present' did not appear."
    return 0
  fi
  if [ -n "$verify_absent" ] &&
     "$HELPER" detailHas "$BUNDLE_ID" "AirBattery Settings" "$verify_absent" >/dev/null 2>&1; then
    fail "Display variant $slug" "Control '$verify_absent' was expected hidden but remained visible."
    return 0
  fi

  scrolltop
  id="$(settings_id)"
  tmp="$TMP/display-variant-${slug}.png"
  capture_temp_window "$id" "$tmp"

  reference="$OUT_DIR/settings/display/01-top.png"
  if [ -f "$reference" ] && ! meaningfully_different "$tmp" "$reference" 0.0035; then
    fail "Display variant $slug" \
      "Preference was staged, but resulting Settings image is visually redundant with the reference."
  else
    save_capture "$tmp" "$rel" \
      "Settings / Display" "$slug" \
      "offline-staged UserDefaults; $notes"
  fi

  osascript -e 'tell application "System Events" to tell process "AirBattery" to keystroke "w" using command down' \
    >/dev/null 2>&1 || true
  sleep 0.3
}

main_frame(){
  "$HELPER" mainFrame
}

main_display_index(){
  # Determine which numbered active display has the same origin/size as CGMainDisplayID.
  mf="$(main_frame)"
  n="$("$HELPER" displayCount)"
  d=1
  while [ "$d" -le "$n" ]; do
    [ "$("$HELPER" displayFrame "$d")" = "$mf" ] && { echo "$d"; return 0; }
    d=$((d + 1))
  done
  echo 1
}

notification_center_verified(){
  # Prefer a semantic control inside NotificationCenter. WindowServer geometry
  # remains a secondary proof because the exact panel geometry can change.
  "$HELPER" bundleHas "com.apple.notificationcenterui" "Edit Widgets" >/dev/null 2>&1 ||
    "$HELPER" notificationPanel >/dev/null 2>&1
}

open_notification_center(){
  closeui

  # Primary route: address the exact menu-bar clock object. This is more
  # reliable than searching all AX text and avoids accidentally clicking the
  # adjacent Control Center icon.
  if osascript <<'APPLESCRIPT' >/dev/null 2>&1
 tell application "System Events"
   tell process "ControlCenter"
     click menu bar item "Clock" of menu bar 1
   end tell
 end tell
APPLESCRIPT
  then
    if wait_cmd 20 notification_center_verified; then return 0; fi
  fi

  # Secondary semantic routes for localized/variant AX trees.
  for label in "Clock" "Date and Time" "Notification Center"; do
    "$HELPER" clickAppText "com.apple.controlcenter" "$label" >/dev/null 2>&1 || true
    if wait_cmd 12 notification_center_verified; then return 0; fi
  done

  # Last-resort coordinate route. Keep this only as a diagnostic fallback; the
  # exact Clock object above should normally handle the interaction.
  if statuspoint; then
    set -- $(xy "$STATUS_POINT")
    sd="$(display_for_point "$1" "$2" 2>/dev/null || true)"
    if [ -n "$sd" ]; then
      sf="$("$HELPER" displayFrame "$sd")"
      sx="$(printf '%s' "$sf" | cut -d, -f1)"
      sy="$(printf '%s' "$sf" | cut -d, -f2)"
      sw="$(printf '%s' "$sf" | cut -d, -f3)"
      "$HELPER" click \
        "$((sx + sw - NOTIFICATION_CENTER_RIGHT_INSET))" \
        "$((sy + 14))" \
        >/dev/null 2>&1 || true
      if wait_cmd 15 notification_center_verified; then return 0; fi
    fi
  fi

  return 1
}

wait_for_gallery_owner(){
  attempts="${1:-30}"
  i=0
  while [ "$i" -lt "$attempts" ]; do
    owner="$("$HELPER" galleryOwner 2>/dev/null || true)"
    if [ -n "$owner" ] &&
       "$HELPER" bundleHasSearch "$owner" >/dev/null 2>&1; then
      GALLERY_OWNER="$owner"
      log "Verified widget gallery owner: $GALLERY_OWNER"
      return 0
    fi
    sleep 0.25
    i=$((i + 1))
  done
  return 1
}

open_widget_gallery(){
  GALLERY_OWNER=""

  # Primary route: click Notification Center's own Edit Widgets control.
  if open_notification_center; then
    if "$HELPER" clickAppText \
      "com.apple.notificationcenterui" \
      "Edit Widgets" \
      >/dev/null 2>&1; then
      if wait_for_gallery_owner 80; then
        return 0
      fi
    fi
  fi

  closeui
  GALLERY_OWNER=""

  # Secondary route: desktop context menu. The interaction itself may be owned
  # by another system process, but success is accepted only after a distinct
  # Apple-owned gallery host with gallery markers and a search field appears.
  mf="$(main_frame)"
  mx="$(printf '%s' "$mf" | cut -d, -f1)"
  my="$(printf '%s' "$mf" | cut -d, -f2)"
  "$HELPER" right "$((mx + 130))" "$((my + 160))" >/dev/null 2>&1 || true
  sleep 0.4

  if "$HELPER" clickGlobal "Edit Widgets" >/dev/null 2>&1; then
    if wait_for_gallery_owner 80; then
      return 0
    fi
  fi

  return 1
}

find_desktop_airbattery_widget(){
  "$HELPER" widgetFrame "com.apple.notificationcenterui" "AirBattery" 2>/dev/null || true
}

wait_for_desktop_airbattery_widget(){
  seconds="${1:-20}"
  i=0
  while [ "$i" -lt "$seconds" ]; do
    frame="$(find_desktop_airbattery_widget)"
    if [ -n "$frame" ]; then
      printf '%s\n' "$frame"
      return 0
    fi
    sleep 1
    i=$((i + 1))
  done
  return 1
}

close_widget_gallery(){
  if [ -n "$GALLERY_OWNER" ]; then
    "$HELPER" clickAppText "$GALLERY_OWNER" "Done" >/dev/null 2>&1 || true
  fi
  sleep 0.8
  closeui
  GALLERY_OWNER=""
  osascript -e 'tell application "Finder" to activate' >/dev/null 2>&1 || true
  sleep 0.5
}

filter_gallery_to_airbattery(){
  [ -n "$GALLERY_OWNER" ] || return 1

  "$HELPER" bundleSetSearch \
    "$GALLERY_OWNER" \
    "AirBattery" \
    >/dev/null 2>&1 ||
    return 1

  sleep 1.2

  # Require an AirBattery-specific configuration display name in the same
  # process that owns the verified gallery. Merely seeing "AirBattery"
  # somewhere in another AX tree is no longer accepted.
  "$HELPER" bundleHas "$GALLERY_OWNER" "Battery Overview" >/dev/null 2>&1 ||
    "$HELPER" bundleHas "$GALLERY_OWNER" "Single Battery" >/dev/null 2>&1
}

add_temporary_airbattery_widget_from_gallery(){
  [ -n "$GALLERY_OWNER" ] || return 1

  # Click an AirBattery widget preview only inside the already-verified gallery
  # owner. Prefer Battery Overview, whose supported families are small/medium/
  # large, then fall back to Single Battery.
  candidate=""
  for title in "Battery Overview" "Single Battery"; do
    candidate="$("$HELPER" widgetFrame "$GALLERY_OWNER" "$title" 2>/dev/null || true)"
    [ -n "$candidate" ] && break
  done

  [ -n "$candidate" ] || return 1

  cx="$(printf '%s' "$candidate" | awk -F, '{print int($1+$3/2)}')"
  cy="$(printf '%s' "$candidate" | awk -F, '{print int($2+$4/2)}')"
  "$HELPER" click "$cx" "$cy" >/dev/null 2>&1 || true
  sleep 1.5

  close_widget_gallery

  TEMP_WIDGET_FRAME="$(wait_for_desktop_airbattery_widget 20 2>/dev/null || true)"
  if [ -n "$TEMP_WIDGET_FRAME" ]; then
    TEMP_WIDGET_ADDED=1
    log "Verified temporary AirBattery desktop widget at $TEMP_WIDGET_FRAME"
    return 0
  fi

  return 1
}

remove_temporary_widget(){
  reason="${1:-normal cleanup}"
  [ "$TEMP_WIDGET_ADDED" = "1" ] || return 0

  closeui
  osascript -e 'tell application "Finder" to activate' >/dev/null 2>&1 || true
  sleep 0.4

  frame="$(find_desktop_airbattery_widget)"
  [ -n "$frame" ] || frame="$TEMP_WIDGET_FRAME"
  [ -n "$frame" ] || return 1

  wx="$(printf '%s' "$frame" | cut -d, -f1)"
  wy="$(printf '%s' "$frame" | cut -d, -f2)"
  ww="$(printf '%s' "$frame" | cut -d, -f3)"
  wh="$(printf '%s' "$frame" | cut -d, -f4)"

  "$HELPER" right "$((wx + ww/2))" "$((wy + wh/2))" >/dev/null 2>&1 || true
  sleep 0.5
  if "$HELPER" clickGlobal "Remove Widget" >/dev/null 2>&1 ||
     "$HELPER" clickGlobal "Remove" >/dev/null 2>&1; then
    sleep 1
    if [ -z "$(find_desktop_airbattery_widget)" ]; then
      TEMP_WIDGET_ADDED=0
      TEMP_WIDGET_FRAME=""
GALLERY_OWNER=""
      log "Removed temporary AirBattery widget ($reason)"
      return 0
    fi
  fi

  fail "Temporary widget cleanup" \
    "A temporary AirBattery widget was added but automatic removal could not be verified ($reason)."
  return 1
}

# -----------------------------------------------------------------------------
# Launch and status/popover capture
# -----------------------------------------------------------------------------
if want_group 'menubar/*' || want_group 'popover/*'; then
  open -b "$BUNDLE_ID" >/dev/null 2>&1 || open -a "$APP_NAME" >/dev/null 2>&1
  sleep 3

  log "Menu-bar/status and popover captures"
  capstatus "01-current" "current user configuration"
  capture_popover_collapsed "01-current-collapsed" "current user configuration"
  capture_popover_airpods_expanded "02-current" "current user configuration"

  if [ "$MUTATE_PREFS" = "1" ]; then
    did_stage_variant=0

    if want_capture "menubar/02-airbattery-glyph.png"; then
      stage_variant intBattOnStatusBar -bool false
      did_stage_variant=1
      capstatus "02-airbattery-glyph" "built-in Mac battery hidden from status item"
    fi

    if want_capture "menubar/03-macos-outside.png"; then
      stage_variant \
        intBattOnStatusBar -bool true \
        iosBatteryStyle -bool false \
        colorfulBattery -bool false \
        batteryPercent -string outside
      did_stage_variant=1
      capstatus "03-macos-outside" "macOS battery style; outside percentage"
    fi

    if want_capture "menubar/04-ios-inside-color.png"; then
      stage_variant \
        intBattOnStatusBar -bool true \
        iosBatteryStyle -bool true \
        colorfulBattery -bool true \
        batteryPercent -string inside
      did_stage_variant=1
      capstatus "04-ios-inside-color" "iOS style; inside percentage; colors"
    fi

    capture_merged_variant(){
      stage_variant twsMergeEnabled -bool true twsMerge -int 99
      did_stage_variant=1
      if wait_for_airpods_ready 40; then
        capture_popover_collapsed "03-earbuds-merged-collapsed" \
          "earbud merging enabled at 99%; live AirPods inventory verified"
        capture_popover_airpods_expanded "04-earbuds-merged" \
          "earbud merging enabled at 99%; live AirPods inventory verified"
      else
        fail "Merged AirPods popover" \
          "AirPods did not reappear within 40 seconds after restarting AirBattery; no truncated startup-state screenshot was saved."
      fi
    }

    capture_split_variant(){
      stage_variant twsMergeEnabled -bool false
      did_stage_variant=1
      if wait_for_airpods_ready 40; then
        capture_popover_collapsed "03-earbuds-split-collapsed" \
          "earbud merging disabled; live AirPods inventory verified"
        capture_popover_airpods_expanded "04-earbuds-split" \
          "earbud merging disabled; live AirPods inventory verified"
      else
        fail "Split AirPods popover" \
          "AirPods did not reappear within 40 seconds after restarting AirBattery; no truncated startup-state screenshot was saved."
      fi
    }

    if [ "$ONLY_PATTERN_COUNT" -gt 0 ]; then
      # Explicit selection makes either structural state addressable regardless
      # of the user's current merge preference.
      want_group 'popover/*earbuds-merged*' && capture_merged_variant
      want_group 'popover/*earbuds-split*' && capture_split_variant
    elif [ "$ORIG_TWS_MERGE_ENABLED" = "0" ]; then
      want_group 'popover/*earbuds-merged*' && capture_merged_variant
    else
      want_group 'popover/*earbuds-split*' && capture_split_variant
    fi

    if [ "$did_stage_variant" = "1" ]; then
      stage_baseline_offline
      launch_fresh
    fi
  fi
fi

# -----------------------------------------------------------------------------
# Settings
# -----------------------------------------------------------------------------
if want_group 'settings/general/*' ||
   want_group 'settings/devices/*' ||
   want_group 'settings/discovery/*' ||
   want_group 'settings/nearcast/*' ||
   want_group 'settings/display/*'; then
  log "Settings captures with navigation verification"

  if open_settings; then
    capture_settings_sweep \
      "General" "general" \
      "Configure startup behavior, command-line tools, and software updates"

    capture_settings_sweep \
      "Devices" "devices" \
      "Manage known devices and inspect battery, connection, and discovery information"

    capture_settings_sweep \
      "Discovery" "discovery" \
      "Control which device sources AirBattery monitors and when active battery queries are allowed"

    capture_settings_sweep \
      "Nearcast" "nearcast" \
      "Share battery information securely with other Macs on your local network"

    capture_settings_sweep \
      "Display" "display" \
      "Choose where AirBattery appears and how battery information is presented"
  else
    fail "Settings" "AirBattery Settings window could not be opened."
  fi
fi

# Debug is hidden normally. Make it visible only when one of its captures is
# selected, then restore the user's baseline before any later workflow.
if want_group 'settings/debug/*' && [ "$MUTATE_PREFS" = "1" ]; then
  osascript -e 'tell application "System Events" to tell process "AirBattery" to keystroke "w" using command down' \
    >/dev/null 2>&1 || true
  stage_variant showDebug -bool true

  if open_settings && navigate_settings "Debug" "Debug Mode"; then
    scrolltop
    id="$(settings_id)"
    debug_top="$TMP/debug-top.png"
    debug_lower="$TMP/debug-lower.png"
    capture_temp_window "$id" "$debug_top"

    if want_capture "settings/debug/01-top.png"; then
      save_capture "$debug_top" "settings/debug/01-top.png" \
        "Settings / Debug" "top" \
        "verified Debug Mode control in detail pane"
    fi

    if want_capture "settings/debug/02-lower.png"; then
      scrolldown -1300
      capture_temp_window "$id" "$debug_lower"
      save_unique "$debug_lower" "settings/debug/02-lower.png" "$debug_top" \
        "Settings / Debug" "lower" \
        "saved only if scrolling visibly changed the Debug page" || true
    fi
  fi

  osascript -e 'tell application "System Events" to tell process "AirBattery" to keystroke "w" using command down' \
    >/dev/null 2>&1 || true
  stage_baseline_offline
  launch_fresh
fi

# Capture structural Device Rows variants. With no --only selector, preserve the
# historical behavior of capturing only the state opposite the user's baseline.
if want_group 'settings/display-configurations/*' && [ "$MUTATE_PREFS" = "1" ]; then
  osascript -e 'tell application "System Events" to tell process "AirBattery" to keystroke "w" using command down' \
    >/dev/null 2>&1 || true

  capture_merging_enabled(){
    stage_variant twsMergeEnabled -bool true twsMerge -int 99
    capture_display_variant \
      "01-earbud-merging-enabled" \
      "threshold row visible" \
      "Merge threshold (%)" ""
  }

  capture_merging_off(){
    stage_variant twsMergeEnabled -bool false
    capture_display_variant \
      "01-earbud-merging-off" \
      "threshold row absent" \
      "" "Merge threshold (%)"
  }

  if [ "$ONLY_PATTERN_COUNT" -gt 0 ]; then
    want_capture "settings/display-configurations/01-earbud-merging-enabled.png" &&
      capture_merging_enabled
    want_capture "settings/display-configurations/01-earbud-merging-off.png" &&
      capture_merging_off
  elif [ "$ORIG_TWS_MERGE_ENABLED" = "0" ]; then
    want_capture "settings/display-configurations/01-earbud-merging-enabled.png" &&
      capture_merging_enabled
  else
    want_capture "settings/display-configurations/01-earbud-merging-off.png" &&
      capture_merging_off
  fi

  stage_baseline_offline
  launch_fresh
fi

# Live Display preview: this state is @State rather than persisted, so drive the
# actual Show button and verify the preview-specific "Preview options" text.
if want_group 'settings/display-preview/*'; then
  if open_settings && navigate_settings "Display" "Choose where AirBattery appears"; then
    scrolltop
    scrolldown -2600
    if "$HELPER" clickAppText "$BUNDLE_ID" "Show" >/dev/null 2>&1 &&
       wait_cmd 15 "$HELPER" detailHas "$BUNDLE_ID" "AirBattery Settings" "Preview options"; then
      scrolldown -1200
      id="$(settings_id)"
      preview_base="$TMP/display-preview-widgets.png"
      capture_temp_window "$id" "$preview_base"

      if want_capture "settings/display-preview/01-widgets.png"; then
        save_capture "$preview_base" "settings/display-preview/01-widgets.png" \
          "Settings / Display" "live preview / widgets" \
          "clicked Show and verified Preview options"
      fi

      if want_capture "settings/display-preview/02-large-widget.png"; then
        if "$HELPER" clickAppText "$BUNDLE_ID" "Battery Overview — Large" >/dev/null 2>&1 ||
           "$HELPER" clickAppText "$BUNDLE_ID" "Battery Overview - Large" >/dev/null 2>&1; then
          sleep 0.5
          scrolldown -900
          preview_large="$TMP/display-preview-large.png"
          capture_temp_window "$id" "$preview_large"
          save_unique "$preview_large" \
            "settings/display-preview/02-large-widget.png" "$preview_base" \
            "Settings / Display" "live preview / large widget expanded" \
            "large disclosure clicked and image materially changed" || true
        fi
      fi
    else
      fail "Display live preview" \
        "The Show button was not activated or Preview options did not appear."
    fi

    osascript -e 'tell application "System Events" to tell process "AirBattery" to keystroke "w" using command down' \
      >/dev/null 2>&1 || true
  fi
fi

# -----------------------------------------------------------------------------
# Widgets in situ + Notification Center + gallery + widget configuration
# -----------------------------------------------------------------------------
if want_group 'widgets-in-situ/*' || want_group 'widget-editor/*'; then
  log "Restoring real preferences before widget capture"
  resetprefs
  restart
  open 'airbattery://reloadwingets' >/dev/null 2>&1 || true
  sleep 4

  # System widget capture is easiest to reason about with an unobscured desktop.
  log "Preparing an unobscured desktop for widget capture"
  osascript -e 'tell application "Finder" to activate' >/dev/null 2>&1 || true
  save_and_hide_gui_apps
  closeui
  sleep 1

  need_desktop_widget=0
  need_widget_configuration=0
  if want_capture "widgets-in-situ/04-desktop-context.png" ||
     want_capture "widgets-in-situ/05-airbattery-tight.png" ||
     want_capture "widget-editor/04-existing-widget-configuration-tight.png" ||
     want_capture "widget-editor/05-existing-widget-configuration-context.png"; then
    need_desktop_widget=1
  fi
  if want_capture "widget-editor/04-existing-widget-configuration-tight.png" ||
     want_capture "widget-editor/05-existing-widget-configuration-context.png"; then
    need_widget_configuration=1
  fi

  desktop_widget_frame=""
  if [ "$need_desktop_widget" = "1" ]; then
    desktop_widget_frame="$(find_desktop_airbattery_widget)"
  fi

  if want_capture "widgets-in-situ/01-notification-center-context.png" ||
     want_capture "widgets-in-situ/02-airbattery-notification-center.png" ||
     want_capture "widgets-in-situ/03-notification-center-panel.png"; then
    log "Opening Notification Center through ControlCenter -> Clock"
    if open_notification_center; then
      edit_frame="$("$HELPER" bundleFrame "com.apple.notificationcenterui" "Edit Widgets" 2>/dev/null || true)"
      panel_frame="$("$HELPER" notificationPanelFrame 2>/dev/null || true)"
      panel_id="$("$HELPER" notificationPanel 2>/dev/null || true)"

      if [ -n "$panel_frame" ]; then
        pd="$(display_for_frame "$panel_frame" 2>/dev/null || main_display_index)"
      elif [ -n "$edit_frame" ]; then
        pd="$(display_for_frame "$edit_frame" 2>/dev/null || main_display_index)"
      else
        pd="$(main_display_index)"
      fi

      capdisplay "widgets-in-situ/01-notification-center-context.png" "$pd" \
        "Widgets in situ" "Notification Center / context" \
        "opened through ControlCenter Clock and verified NotificationCenter Edit Widgets or panel" || true

      if want_capture "widgets-in-situ/02-airbattery-notification-center.png"; then
        nc_widget_frame=""
        for nc_label in "AirBattery" "Battery Overview"; do
          nc_widget_frame="$("$HELPER" notificationWidgetFrame "$nc_label" 2>/dev/null || true)"
          [ -n "$nc_widget_frame" ] && break
        done

        if [ -n "$nc_widget_frame" ]; then
          nc_widget_rect="$(printf '%s' "$nc_widget_frame" | awk -F, \
            '{printf "%d,%d,%d,%d",$1-10,$2-10,$3+20,$4+20}')"
          capreg "widgets-in-situ/02-airbattery-notification-center.png" "$nc_widget_rect" \
            "Widgets in situ" "AirBattery widget in Notification Center" \
            "widget container is inside the verified Notification Center panel" || true
        else
          fail "AirBattery widget in Notification Center" \
            "Notification Center opened, but no AirBattery/Battery Overview widget container could be isolated inside its panel."
        fi
      fi

      if want_capture "widgets-in-situ/03-notification-center-panel.png" &&
         [ -n "$panel_id" ]; then
        capwin "widgets-in-situ/03-notification-center-panel.png" "$panel_id" \
          "Widgets in situ" "Notification Center panel" \
          "captured verified Notification Center WindowServer panel" || true
      fi
    else
      fail "Notification Center" \
        "The exact ControlCenter Clock action and semantic fallbacks did not expose Notification Center."
    fi
    closeui
  fi

  gallery_open=0
  gallery_filtered=0
  gallery_display=""
  search_frame=""

  need_gallery=0
  if want_capture "widget-editor/01-gallery.png" ||
     want_capture "widget-editor/02-gallery-airbattery.png" ||
     want_capture "widget-editor/03-gallery-airbattery-scrolled.png" ||
     { [ "$need_desktop_widget" = "1" ] && [ -z "$desktop_widget_frame" ]; }; then
    need_gallery=1
  fi

  if [ "$need_gallery" = "1" ]; then
    log "Opening macOS widget gallery"
    if open_widget_gallery; then
      gallery_open=1
      search_frame="$("$HELPER" bundleSearchFrame "$GALLERY_OWNER" 2>/dev/null || true)"
      gallery_display="$(display_for_frame "$search_frame" 2>/dev/null || main_display_index)"

      capdisplay "widget-editor/01-gallery.png" "$gallery_display" \
        "Widget editor" "widget gallery" \
        "verified Apple-owned gallery host '$GALLERY_OWNER' exposes both gallery markers and its own search field" || true

      need_filter=0
      if want_capture "widget-editor/02-gallery-airbattery.png" ||
         want_capture "widget-editor/03-gallery-airbattery-scrolled.png" ||
         { [ "$need_desktop_widget" = "1" ] && [ -z "$desktop_widget_frame" ]; }; then
        need_filter=1
      fi

      if [ "$need_filter" = "1" ]; then
        if filter_gallery_to_airbattery; then
          gallery_filtered=1

          if want_capture "widget-editor/02-gallery-airbattery.png" ||
             want_capture "widget-editor/03-gallery-airbattery-scrolled.png"; then
            gallery_base="$TMP/gallery-airbattery.png"
            capture_temp_display "$gallery_display" "$gallery_base"

            if want_capture "widget-editor/02-gallery-airbattery.png"; then
              save_capture "$gallery_base" "widget-editor/02-gallery-airbattery.png" \
                "Widget editor" "gallery filtered to AirBattery" \
                "search was set in the verified gallery owner and Battery Overview or Single Battery appeared in that same AX tree"
            fi

            if want_capture "widget-editor/03-gallery-airbattery-scrolled.png" &&
               [ -n "$search_frame" ]; then
              gallery_scrolled="$TMP/gallery-airbattery-scrolled.png"
              gx="$(printf '%s' "$search_frame" | cut -d, -f1)"
              gy="$(printf '%s' "$search_frame" | cut -d, -f2)"
              gw="$(printf '%s' "$search_frame" | cut -d, -f3)"
              "$HELPER" scrollPoint "$((gx + gw/2))" "$((gy + 260))" -1000 >/dev/null 2>&1 || true
              sleep 0.5
              capture_temp_display "$gallery_display" "$gallery_scrolled"
              save_unique "$gallery_scrolled" \
                "widget-editor/03-gallery-airbattery-scrolled.png" "$gallery_base" \
                "Widget editor" "AirBattery gallery scrolled" \
                "saved only if scrolling reveals materially different AirBattery gallery content" || true
            fi
          fi
        else
          fail "Widget gallery / AirBattery" \
            "The gallery opened, but AirBattery widget results could not be verified after filtering."
        fi
      fi
    else
      fail "Widget gallery" \
        "Neither route produced a positively identified Apple-owned widget gallery with its own search field and gallery-specific markers."
    fi
  fi

  # A real widget is needed only for desktop/configuration targets. If none
  # exists, use the already filtered gallery to create a temporary one.
  if [ "$need_desktop_widget" = "1" ] && [ -z "$desktop_widget_frame" ]; then
    if [ "$gallery_open" = "1" ] && [ "$gallery_filtered" = "1" ]; then
      log "No existing AirBattery desktop widget; adding a temporary Battery Overview widget"
      if add_temporary_airbattery_widget_from_gallery; then
        desktop_widget_frame="$TEMP_WIDGET_FRAME"
        gallery_open=0
      else
        fail "Temporary AirBattery desktop widget" \
          "The filtered gallery was visible, but clicking an AirBattery widget preview did not produce a verifiable desktop widget."
        gallery_open=0
      fi
    else
      fail "AirBattery desktop widget" \
        "No pre-existing widget was found and the AirBattery gallery was not available to create a temporary one."
    fi
  fi

  if [ "$gallery_open" = "1" ]; then
    close_widget_gallery
    gallery_open=0
  else
    closeui
  fi

  if [ "$need_desktop_widget" = "1" ]; then
    if [ -n "$desktop_widget_frame" ]; then
      widget_display="$(display_for_frame "$desktop_widget_frame" 2>/dev/null || true)"
      widget_rect="$(printf '%s' "$desktop_widget_frame" | awk -F, '{printf "%d,%d,%d,%d",$1-12,$2-12,$3+24,$4+24}')"

      if [ -n "$widget_display" ]; then
        capdisplay "widgets-in-situ/04-desktop-context.png" "$widget_display" \
          "Widgets in situ" "AirBattery desktop widget / context" \
          "GUI applications hidden; verified AirBattery desktop widget container" || true
      fi

      capreg "widgets-in-situ/05-airbattery-tight.png" "$widget_rect" \
        "Widgets in situ" "AirBattery desktop widget" \
        "tight crop of verified AirBattery desktop widget container" || true

      if [ "$need_widget_configuration" = "1" ]; then
        log "Opening AirBattery widget configuration"
        wx="$(printf '%s' "$desktop_widget_frame" | cut -d, -f1)"
        wy="$(printf '%s' "$desktop_widget_frame" | cut -d, -f2)"
        ww="$(printf '%s' "$desktop_widget_frame" | cut -d, -f3)"
        wh="$(printf '%s' "$desktop_widget_frame" | cut -d, -f4)"
        cx=$((wx + ww/2)); cy=$((wy + wh/2))
        [ -n "$WIDGET_POINT" ] && { set -- $(xy "$WIDGET_POINT"); cx="$1"; cy="$2"; }

        before_widget="$TMP/widget-before-edit.png"
        after_widget="$TMP/widget-after-edit.png"
        /usr/sbin/screencapture -x -R "$widget_rect" "$before_widget" >/dev/null 2>&1 || true

        "$HELPER" right "$cx" "$cy" >/dev/null 2>&1 || true
        sleep 0.55
        if "$HELPER" clickGlobal "Edit AirBattery" >/dev/null 2>&1 ||
           "$HELPER" clickGlobal "Edit Widget" >/dev/null 2>&1; then
          sleep 1.2
          /usr/sbin/screencapture -x -R "$widget_rect" "$after_widget" >/dev/null 2>&1 || true

          if "$HELPER" globalHas "Show Percentages" >/dev/null 2>&1 ||
             "$HELPER" globalHas "Show Labels" >/dev/null 2>&1 ||
             "$HELPER" globalHas "Enter Device Name" >/dev/null 2>&1 ||
             { [ -s "$before_widget" ] && [ -s "$after_widget" ] &&
               meaningfully_different "$before_widget" "$after_widget" 0.018; }; then
            save_capture "$after_widget" \
              "widget-editor/04-existing-widget-configuration-tight.png" \
              "Widget editor" "existing AirBattery widget configuration" \
              "Edit Widget invoked; AppIntent controls or material widget-region transition verified"

            if [ -n "${widget_display:-}" ]; then
              capdisplay "widget-editor/05-existing-widget-configuration-context.png" "$widget_display" \
                "Widget editor" "existing widget configuration / context" \
                "verified AirBattery widget entered configuration state" || true
            fi
          else
            fail "Existing widget configuration" \
              "Edit Widget was invoked, but neither AppIntent controls nor a material widget-region change was observed."
          fi
        else
          fail "Existing widget configuration" \
            "The verified AirBattery widget context menu exposed no Edit Widget action."
        fi
        closeui
      fi
    else
      fail "AirBattery desktop widget" \
        "No pre-existing widget was found and no temporary widget could be added from the gallery."
    fi
  fi

  # Remove only the widget this script added. A pre-existing user widget is never
  # removed or repositioned.
  if [ "$TEMP_WIDGET_ADDED" = "1" ]; then
    remove_temporary_widget "normal completion" || true
  fi

  restore_gui_apps
fi

cat >> "$INDEX" <<'EOF'

## Notes

- `--only` and `--skip` are evaluated against the output paths shown by
  `--list`. Unselected workflows are skipped before their UI automation runs.
- Settings captures are written only after a destination-specific detail-pane
  string proves that navigation succeeded.
- Settings scroll captures use perceptual image comparison; visually
  redundant near-duplicates are suppressed.
- Temporary preference variants are staged only while AirBattery is stopped,
  preventing its in-process UserDefaults cache from overwriting them.
- AirPods expansion clicks the actual `Show components` disclosure button and
  verifies `Collapse components` or a larger popover frame before capture.
- After a restart used for an alternate earbud state, the script waits for the
  live AirPods compound row to reappear before taking any popover screenshot.
- Notification Center is opened first through the exact `Clock` menu-bar item
  of the `ControlCenter` process and verified by Notification Center's own
  `Edit Widgets` control or its WindowServer panel. Coordinate clicking is only
  a final fallback.
- Widget-gallery automation never uses a global search field. After `Edit
  Widgets`, the helper identifies one Apple-owned gallery host only when that
  same process exposes a visible search field plus gallery-specific markers.
  Search, result verification, preview clicks, and `Done` are then scoped to
  that single process.
- AirBattery gallery filtering requires `Battery Overview` or `Single Battery`
  to appear inside that verified gallery owner's AX tree.
- If an AirBattery widget is already visible in Notification Center, it is
  captured independently of desktop-widget installation.
- If no AirBattery widget already exists on the desktop, the script clicks an
  AirBattery gallery preview to add a temporary widget, verifies it, captures
  and edits it, then removes it. Existing user widgets are never removed.
- Desktop-widget captures hide foreground GUI applications first and restore
  their prior visibility during cleanup.
- Existing-widget configuration is driven from a verified desktop widget and
  accepted only when AppIntent controls or a material visual transition appear.
- See `FAILURES.md` for any state that macOS did not expose reliably during this
  run. Failed states are intentionally not represented by misleading PNGs.
EOF

ARCHIVE="${OUT_ROOT%/}/${STAMP}.zip"

log "Capture complete"
echo "Output:   $OUT_DIR"
echo "Index:    $INDEX"
echo "Failures: $FAILURES"
echo "Log:      $LOG_DIR/capture.log"

# Package the timestamped capture directory as a metadata-free portable ZIP.
# `-X` omits extended attributes and the excludes prevent AppleDouble/.DS_Store
# entries from entering the archive. The temporary preference backup lives
# outside OUT_DIR and is therefore never archived.
log "Creating capture archive: $ARCHIVE"
rm -f "$ARCHIVE"
(
  cd "$(dirname "$OUT_DIR")"
  zip -q -r -X "$(basename "$ARCHIVE")" "$(basename "$OUT_DIR")" \
    -x '*/._*' '*/.DS_Store'
)

echo "Archive:  $ARCHIVE"
