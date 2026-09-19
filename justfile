set shell := ["bash", "-euo", "pipefail", "-c"]

project := "AirBattery.xcodeproj"
scheme := "AirBattery"
derived_data := ".build/xcode"
xcode_app := env("XCODE_APP", "/Applications/Xcode.app")
signing_identity := env("SIGNING_IDENTITY", "-")
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

# Build all local app targets using an ad-hoc signature by default.
# Override SIGNING_IDENTITY to use another installed signing identity.
build-signed configuration="Debug":
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
        CODE_SIGN_IDENTITY="{{signing_identity}}" \
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

# Install and launch the signed local development build.
# Launching the containing app allows macOS to register its WidgetKit extension.
run configuration="Debug":
    just install-local "{{configuration}}"
    @install_dir="${AIRBATTERY_INSTALL_DIR:-$HOME/Applications}"; \
      /usr/bin/pkill -x AirBattery >/dev/null 2>&1 || true; \
      /usr/bin/open "$install_dir/AirBattery.app"

# Show whether macOS currently knows about the AirBattery WidgetKit extension.
widget-status:
    @/usr/bin/pluginkit -m -A -D -v -i "{{widget_bundle_id}}" || true

# Remove the locally installed development build.
uninstall-local:
    @install_dir="${AIRBATTERY_INSTALL_DIR:-$HOME/Applications}"; \
      /usr/bin/pkill -x AirBattery >/dev/null 2>&1 || true; \
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
