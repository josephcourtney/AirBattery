#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

export AIRBATTERY_HROST=1
export HROST_PATH="${HROST_PATH:-../hrost}"

[[ -f "$HROST_PATH/Package.swift" ]] || {
    echo "AirBatteryHrost: Hrost checkout not found at '$HROST_PATH'." >&2
    echo "Set HROST_PATH=/path/to/hrost to override the default ../hrost." >&2
    exit 2
}
command -v xcrun >/dev/null 2>&1 || {
    echo "AirBatteryHrost: xcrun is required to compile AirBattery assets." >&2
    exit 2
}

swift build --product AirBatteryHrost
BIN_DIR="$(swift build --show-bin-path)"
APP_DIR="$BIN_DIR/AirBatteryHrost.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

# The production AirBattery views resolve named images, adaptive colors, and
# localized strings from Bundle.main. A bare SwiftPM executable does not provide
# the application-bundle resource layout those APIs expect, so stage the harness
# as a minimal development-only .app around the already-built executable.
rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RESOURCES"
cp "$BIN_DIR/AirBatteryHrost" "$MACOS/AirBatteryHrost"
chmod +x "$MACOS/AirBatteryHrost"

cat > "$CONTENTS/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>AirBatteryHrost</string>
    <key>CFBundleIdentifier</key>
    <string>com.josephcourtney.AirBattery.Hrost</string>
    <key>CFBundleName</key>
    <string>AirBattery Hrost</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>26.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

xcrun actool \
    "$ROOT/AirBattery/Assets.xcassets" \
    --compile "$RESOURCES" \
    --output-format human-readable-text \
    --notices \
    --warnings \
    --errors \
    --platform macosx \
    --target-device mac \
    --minimum-deployment-target 26.0

for localization in "$ROOT"/AirBattery/*.lproj; do
    [[ -d "$localization" ]] || continue
    /usr/bin/ditto "$localization" "$RESOURCES/$(basename "$localization")"
done

[[ -f "$RESOURCES/Assets.car" ]] || {
    echo "AirBatteryHrost: actool did not produce $RESOURCES/Assets.car." >&2
    exit 2
}

# SwiftPM may leave dynamic products beside the original executable. Preserve
# that lookup location after staging the executable inside the development app.
export DYLD_FRAMEWORK_PATH="$BIN_DIR${DYLD_FRAMEWORK_PATH:+:$DYLD_FRAMEWORK_PATH}"
export DYLD_LIBRARY_PATH="$BIN_DIR${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"

exec "$MACOS/AirBatteryHrost" "$@"
