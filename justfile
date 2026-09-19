set shell := ["bash", "-euo", "pipefail", "-c"]

project := "AirBattery.xcodeproj"
scheme := "AirBattery"
derived_data := ".build/xcode"
xcode_app := env("XCODE_APP", "/Applications/Xcode.app")
signing_identity := env("SIGNING_IDENTITY", "")
app_bundle_id := "com.josephcourtney.AirBattery"
widget_bundle_id := "com.josephcourtney.AirBattery.widget"
helper_bundle_id := "com.josephcourtney.AirBatteryHelper"

# List available recipes.
default:
    @just --list

# Install Xcode from the command line using xcodes.
install-xcode version="27":
    @command -v brew >/dev/null 2>&1 || { echo "Homebrew is required to install xcodes." >&2; exit 1; }
    @if ! command -v xcodes >/dev/null 2>&1; then brew install xcodesorg/made/xcodes; fi
    xcodes install "{{version}}"
    @echo
    @xcodes installed
    @echo
    @echo "Select the installed Xcode with:"
    @echo "  just setup-xcode /Applications/<Xcode.app>"

# List Xcode installations known to xcodes.
installed-xcodes:
    @command -v xcodes >/dev/null 2>&1 || { echo "xcodes is not installed. Run 'just install-xcode' first." >&2; exit 1; }
    xcodes installed

# Select a full Xcode installation and perform its first-run setup.
setup-xcode app=xcode_app:
    @test -d "{{app}}/Contents/Developer" || { echo "Not a full Xcode application: {{app}}" >&2; exit 1; }
    sudo xcode-select --switch "{{app}}/Contents/Developer"
    sudo xcodebuild -license accept
    sudo xcodebuild -runFirstLaunch
    just doctor

# Show and validate the active macOS/Xcode toolchain.
doctor:
    @printf '%s\n' '--- macOS ---'
    @sw_vers
    @printf '%s\n' '--- Developer directory ---'
    @developer_dir="$(xcode-select -p 2>/dev/null || true)"; printf '%s\n' "$developer_dir"; [[ "$developer_dir" == */Contents/Developer ]] || { echo "A full Xcode installation is not selected." >&2; exit 1; }
    @printf '%s\n' '--- Xcode ---'
    @xcodebuild -version
    @printf '%s\n' '--- macOS SDK ---'
    @xcrun --sdk macosx --show-sdk-version
    @printf '%s\n' '--- Swift ---'
    @swift --version
    @printf '%s\n' '--- Project ---'
    @xcodebuild -list -project "{{project}}"

# Resolve Swift package dependencies into the local derived-data directory.
resolve:
    @mkdir -p "{{derived_data}}"
    xcodebuild \
        -resolvePackageDependencies \
        -project "{{project}}" \
        -scheme "{{scheme}}" \
        -derivedDataPath "{{derived_data}}"

# Build AirBattery without code signing. Defaults to Debug.
build configuration="Debug":
    @mkdir -p "{{derived_data}}"
    xcodebuild \
        -project "{{project}}" \
        -scheme "{{scheme}}" \
        -configuration "{{configuration}}" \
        -destination 'platform=macOS' \
        -derivedDataPath "{{derived_data}}" \
        CODE_SIGNING_ALLOWED=NO \
        build

# Build a Release configuration without code signing.
release: (build "Release")

# Show installed code-signing identities.
signing-identities:
    @/usr/bin/security find-identity -v -p codesigning

# Build with Xcode's ad-hoc signing, then re-sign the complete app bundle with
# a stable Apple Development identity. This avoids Xcode account/provisioning
# requirements while giving TCC (Bluetooth, etc.) a persistent code identity.
build-signed configuration="Debug":
    just build-adhoc "{{configuration}}"
    @identity="$(/usr/bin/security find-identity -v -p codesigning | \
        /usr/bin/sed -nE 's/^[[:space:]]*[0-9]+\) [0-9A-F]+ "([^"]*Apple Development:[^"]*\(([A-Z0-9]{10})\))"$/\1|\2/p' | \
        /usr/bin/head -n 1)"; \
      if [[ -z "$identity" ]]; then \
        printf '%s\n' \
          "No Apple Development signing identity is installed." \
          "Run 'just signing-identities' to inspect available identities." >&2; \
        exit 1; \
      fi; \
      team="${identity##*|}"; \
      identity="${identity%|*}"; \
      app="{{derived_data}}/Build/Products/{{configuration}}/AirBattery.app"; \
      printf 'Re-signing with: %s\nDevelopment team: %s\n' "$identity" "$team"; \
      /usr/bin/codesign \
        --force \
        --deep \
        --sign "$identity" \
        --timestamp=none \
        --preserve-metadata=identifier,entitlements,flags,runtime \
        "$app"; \
      actual_team="$(/usr/bin/codesign -dvv "$app" 2>&1 | /usr/bin/sed -n 's/^TeamIdentifier=//p')"; \
      [[ "$actual_team" == "$team" ]] || { \
        echo "Expected TeamIdentifier=$team, got $actual_team" >&2; \
        exit 1; \
      }
    just verify-signing "{{configuration}}"

# Build all products ad-hoc. Intended for CI and as the first stage of
# build-signed; do not install this result directly for TCC-sensitive testing.
build-adhoc configuration="Debug":
    @mkdir -p "{{derived_data}}"
    xcodebuild \
        -project "{{project}}" \
        -scheme "{{scheme}}" \
        -configuration "{{configuration}}" \
        -destination 'platform=macOS' \
        -derivedDataPath "{{derived_data}}" \
        CODE_SIGNING_ALLOWED=YES \
        CODE_SIGNING_REQUIRED=YES \
        CODE_SIGN_STYLE=Manual \
        CODE_SIGN_IDENTITY=- \
        DEVELOPMENT_TEAM="" \
        build
    just verify-signing "{{configuration}}"

# Verify the host app and its embedded helper/widget signatures and identifiers.
verify-signing configuration="Debug":
    @app="{{derived_data}}/Build/Products/{{configuration}}/AirBattery.app"; \
      widget="$app/Contents/PlugIns/AirBatteryWidgetExtension.appex"; \
      helper="$app/Contents/Library/LoginItems/AirBatteryHelper.app"; \
      test -d "$app" || { echo "Missing $app; run 'just build-signed {{configuration}}' first." >&2; exit 1; }; \
      test -d "$widget" || { echo "Missing embedded widget extension: $widget" >&2; exit 1; }; \
      test -d "$helper" || { echo "Missing embedded login helper: $helper" >&2; exit 1; }; \
      codesign --verify --deep --strict --verbose=2 "$app"; \
      [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist")" == "{{app_bundle_id}}" ]] || { echo "Unexpected app bundle identifier." >&2; exit 1; }; \
      [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$widget/Contents/Info.plist")" == "{{widget_bundle_id}}" ]] || { echo "Unexpected widget bundle identifier." >&2; exit 1; }; \
      [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$helper/Contents/Info.plist")" == "{{helper_bundle_id}}" ]] || { echo "Unexpected helper bundle identifier." >&2; exit 1; }; \
      printf '%s\n' "Signed app:    {{app_bundle_id}}" "Signed widget: {{widget_bundle_id}}" "Signed helper: {{helper_bundle_id}}"

# Install a signed development build in ~/Applications by default.
# Override AIRBATTERY_INSTALL_DIR to use another directory.
install-local configuration="Debug":
    just build-signed "{{configuration}}"
    @src="{{derived_data}}/Build/Products/{{configuration}}/AirBattery.app"; \
      install_dir="${AIRBATTERY_INSTALL_DIR:-$HOME/Applications}"; \
      dst="$install_dir/AirBattery.app"; \
      mkdir -p "$install_dir"; \
      rm -rf "$dst"; \
      /usr/bin/ditto "$src" "$dst"; \
      codesign --verify --deep --strict --verbose=2 "$dst"; \
      printf '%s\n' "$dst"

# Stop every locally running AirBattery app/helper process.
# TERM first for a clean shutdown; force-kill anything that does not exit.
stop:
    @/usr/bin/pkill -TERM -x AirBattery >/dev/null 2>&1 || true
    @/usr/bin/pkill -TERM -x AirBatteryHelper >/dev/null 2>&1 || true
    @for _ in 1 2 3 4 5 6 7 8 9 10; do \
      if ! /usr/bin/pgrep -x AirBattery >/dev/null 2>&1 && \
         ! /usr/bin/pgrep -x AirBatteryHelper >/dev/null 2>&1; then \
        exit 0; \
      fi; \
      /bin/sleep 0.1; \
    done; \
    /usr/bin/pkill -KILL -x AirBattery >/dev/null 2>&1 || true; \
    /usr/bin/pkill -KILL -x AirBatteryHelper >/dev/null 2>&1 || true

# Stop existing instances, install, and launch exactly one signed local build.
# Launching the containing app allows macOS to register its WidgetKit extension.
run configuration="Debug":
    just stop
    just install-local "{{configuration}}"
    @install_dir="${AIRBATTERY_INSTALL_DIR:-$HOME/Applications}"; \
      /usr/bin/open "$install_dir/AirBattery.app"

# Reset macOS Bluetooth privacy consent for this fork.
# The next launch/use of CoreBluetooth should request permission again.
reset-bluetooth-permission:
    /usr/bin/tccutil reset BluetoothAlways "{{app_bundle_id}}"

# Inspect the installed app identity and Bluetooth privacy declaration.
bluetooth-diagnose:
    @app="${AIRBATTERY_INSTALL_DIR:-$HOME/Applications}/AirBattery.app"; \
      test -d "$app" || { echo "AirBattery is not installed at $app" >&2; exit 1; }; \
      printf '%s\n' '--- Installed app ---' "$app"; \
      printf '%s\n' '--- Bundle identifier ---'; \
      /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist"; \
      printf '%s\n' '--- Bluetooth usage description ---'; \
      /usr/libexec/PlistBuddy -c 'Print :NSBluetoothAlwaysUsageDescription' "$app/Contents/Info.plist"; \
      printf '%s\n' '--- Signature ---'; \
      /usr/bin/codesign -d -vvv "$app" 2>&1 | /usr/bin/grep -E '^(Identifier|TeamIdentifier|Authority|Signature|CodeDirectory)=' || true; \
      printf '%s\n' '--- Designated requirement ---'; \
      /usr/bin/codesign -d -r- "$app" 2>&1; \
      printf '%s\n' '--- Signature verification ---'; \
      /usr/bin/codesign --verify --deep --strict --verbose=2 "$app"; \
      printf '%s\n' '--- Running processes ---'; \
      /usr/bin/pgrep -alf 'AirBattery|AirBatteryHelper' || true; \
      printf '%s\n' '--- Available signing identities ---'; \
      /usr/bin/security find-identity -v -p codesigning

# Show whether macOS currently knows about the AirBattery WidgetKit extension.
widget-status:
    @/usr/bin/pluginkit -m -A -D -v -i "{{widget_bundle_id}}" || true

# Remove the locally installed development build.
uninstall-local:
    just stop
    @install_dir="${AIRBATTERY_INSTALL_DIR:-$HOME/Applications}"; \
      rm -rf "$install_dir/AirBattery.app"

# Run the normal local verification path.
check:
    just doctor
    just resolve
    just build

# Run the same unsigned build commands used by GitHub Actions.
ci:
    xcodebuild \
        -resolvePackageDependencies \
        -project "{{project}}" \
        -scheme "{{scheme}}"
    xcodebuild \
        -project "{{project}}" \
        -scheme "{{scheme}}" \
        -configuration Debug \
        -destination 'platform=macOS' \
        CODE_SIGNING_ALLOWED=NO \
        build

# Print the expected locally built application path.
app-path configuration="Debug":
    @printf '%s/%s\n' "$PWD" "{{derived_data}}/Build/Products/{{configuration}}/AirBattery.app"

# Remove local Xcode build products and package checkouts.
clean:
    rm -rf "{{derived_data}}"
