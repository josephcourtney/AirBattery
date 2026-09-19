set shell := ["bash", "-euo", "pipefail", "-c"]

project := "AirBattery.xcodeproj"
scheme := "AirBattery"
derived_data := ".build/xcode"
xcode_app := env("XCODE_APP", "/Applications/Xcode.app")

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

# Run the normal local verification path.
check:
    just doctor
    just resolve
    just build

# Run the same build commands used by GitHub Actions.
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
