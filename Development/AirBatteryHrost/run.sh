#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

PREPARE_ONLY=0
if [[ "${1:-}" == "--prepare-only" ]]; then
    PREPARE_ONLY=1
    shift
fi

PRODUCT="${AIRBATTERY_HROST_PRODUCT:-AirBatteryHrost}"

export AIRBATTERY_HROST=1
export HROST_PATH="${HROST_PATH:-../hrost}"

[[ -f "$HROST_PATH/Package.swift" ]] || {
    echo "$PRODUCT: Hrost checkout not found at '$HROST_PATH'." >&2
    echo "Set HROST_PATH=/path/to/hrost to override the default ../hrost." >&2
    exit 2
}
command -v xcrun >/dev/null 2>&1 || {
    echo "$PRODUCT: xcrun is required to compile AirBattery assets." >&2
    exit 2
}

swift build --product "$PRODUCT"
BIN_DIR="$(swift build --show-bin-path)"
APP_DIR="$BIN_DIR/$PRODUCT.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
FRAMEWORKS="$CONTENTS/Frameworks"

# The production AirBattery views resolve named images, adaptive colors, and
# localized strings from Bundle.main. A bare SwiftPM executable does not provide
# the application-bundle resource layout those APIs expect, so stage the harness
# as a minimal development-only .app around the already-built executable.
rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RESOURCES" "$FRAMEWORKS"
cp "$BIN_DIR/$PRODUCT" "$MACOS/$PRODUCT"
chmod +x "$MACOS/$PRODUCT"

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$PRODUCT</string>
    <key>CFBundleIdentifier</key>
    <string>com.josephcourtney.AirBattery.$PRODUCT</string>
    <key>CFBundleName</key>
    <string>$PRODUCT</string>
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

# Preserve dynamic SwiftPM products inside the app so the harness remains
# runnable after it is copied into the isolated Screen Sharing account.
shopt -s nullglob
for framework in "$BIN_DIR"/*.framework; do
    /usr/bin/ditto "$framework" "$FRAMEWORKS/$(basename "$framework")"
done
for dylib in "$BIN_DIR"/*.dylib; do
    cp -p "$dylib" "$FRAMEWORKS/$(basename "$dylib")"
done
for resource_bundle in "$BIN_DIR"/*.bundle; do
    /usr/bin/ditto "$resource_bundle" "$RESOURCES/$(basename "$resource_bundle")"
done
shopt -u nullglob

[[ -f "$RESOURCES/Assets.car" ]] || {
    echo "$PRODUCT: actool did not produce $RESOURCES/Assets.car." >&2
    exit 2
}

if (( PREPARE_ONLY )); then
    printf '%s\n' "$APP_DIR"
    exit 0
fi

# SwiftPM may leave dynamic products beside the original executable. Prefer the
# self-contained app copy, with the build directory retained as a local fallback.
export DYLD_FRAMEWORK_PATH="$FRAMEWORKS:$BIN_DIR${DYLD_FRAMEWORK_PATH:+:$DYLD_FRAMEWORK_PATH}"
export DYLD_LIBRARY_PATH="$FRAMEWORKS:$BIN_DIR${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"

exec "$MACOS/$PRODUCT" "$@"
