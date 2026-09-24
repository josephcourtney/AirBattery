set shell := ["bash", "-euo", "pipefail", "-c"]
set quiet
set no-exit-message

project := "AirBattery.xcodeproj"
scheme := "AirBattery"
derived_data := ".build/xcode"
log_dir := ".build/logs"
xcode_app := env("XCODE_APP", "/Applications/Xcode.app")
signing_identity := env("SIGNING_IDENTITY", "")
app_bundle_id := "com.josephcourtney.AirBattery"
widget_bundle_id := "com.josephcourtney.AirBattery.widget"
install_state_dir := ".build/install-state"
host_arch := `uname -m`
mac_destination := "platform=macOS,arch=" + host_arch

# List available recipes.
default: check

# Run a command quietly. Successful commands print one line. Warnings print a
# short excerpt and preserve the full log. Failures print the full captured log.
# Use AIRBATTERY_VERBOSE=1 to bypass capture for non-Xcode commands.
[no-exit-message]
[positional-arguments]
[private]
run-quiet label +command:
    label="$1"; shift; \
      mkdir -p "{{ log_dir }}"; \
      slug="$(printf '%s' "$label" | /usr/bin/tr -cs '[:alnum:]._-' '_')"; \
      log="{{ log_dir }}/${slug}.log"; \
      tmp="${log}.tmp.$$"; \
      if [[ "${AIRBATTERY_VERBOSE:-0}" == "1" ]]; then \
        "$@"; \
        exit $?; \
      fi; \
      trap 'rm -f "$tmp"' EXIT; \
      set +e; \
      "$@" >"$tmp" 2>&1; \
      rc=$?; \
      set -e; \
      /bin/mv "$tmp" "$log"; \
      trap - EXIT; \
      if [[ "$rc" -ne 0 ]]; then \
        printf '✗ %s\n\n' "$label" >&2; \
        cat "$log" >&2; \
        printf '\nFull log: %s\n' "$log" >&2; \
        exit "$rc"; \
      fi; \
      diagnostic_re='(^|[^[:alnum:]_])(warning|error|fatal)(:|[[:space:]])|DVTAssertions: Warning'; \
      if /usr/bin/grep -Eiq "$diagnostic_re" "$log"; then \
        printf '⚠ %s\n' "$label"; \
        /usr/bin/grep -Ei -C 2 "$diagnostic_re" "$log" || true; \
        printf 'Full log: %s\n' "$log"; \
      else \
        printf '✓ %s\n' "$label"; \
      fi

# Run xcodebuild through xcbeautify when available. The complete raw Xcode log
# is retained separately; without xcbeautify, xcodebuild -quiet is the fallback.
[no-exit-message]
[positional-arguments]
[private]
_xcode label +args:
    label="$1"; shift; \
      mkdir -p "{{ log_dir }}"; \
      slug="$(printf '%s' "$label" | /usr/bin/tr -cs '[:alnum:]._-' '_')"; \
      raw="{{ log_dir }}/${slug}.xcodebuild.log"; \
      if [[ "${AIRBATTERY_VERBOSE:-0}" == "1" ]]; then \
        if command -v xcbeautify >/dev/null 2>&1; then \
          NSUnbufferedIO=YES xcodebuild "$@" 2>&1 | /usr/bin/tee "$raw" | xcbeautify; \
        else \
          xcodebuild "$@"; \
        fi; \
        exit $?; \
      fi; \
      if command -v xcbeautify >/dev/null 2>&1; then \
        set +e; \
        just -- run-quiet "$label" \
          bash -o pipefail -c \
          'raw="$1"; shift; NSUnbufferedIO=YES xcodebuild "$@" 2>&1 | /usr/bin/tee "$raw" | xcbeautify --quiet --disable-colored-output' \
          xcodebuild "$raw" "$@"; \
        rc=$?; \
        set -e; \
        if [[ "$rc" -ne 0 ]]; then \
          printf 'Raw Xcode log: %s\n' "$raw" >&2; \
          exit "$rc"; \
        fi; \
      else \
        just -- run-quiet "$label" xcodebuild -quiet "$@"; \
      fi

# Install Xcode from the command line using xcodes.
install-xcode version="27":
    command -v brew >/dev/null 2>&1 || { echo "Homebrew is required to install xcodes." >&2; exit 1; }
    if ! command -v xcodes >/dev/null 2>&1; then brew install xcodesorg/made/xcodes; fi
    xcodes install "{{ version }}"
    echo
    xcodes installed
    echo
    echo "Select the installed Xcode with:"
    echo "  just setup-xcode /Applications/<Xcode.app>"

# Install the formatter used by normal build/test recipes.
install-xcbeautify:
    command -v brew >/dev/null 2>&1 || { echo "Homebrew is required to install xcbeautify." >&2; exit 1; }
    brew install xcbeautify

# List Xcode installations known to xcodes.
installed-xcodes:
    command -v xcodes >/dev/null 2>&1 || { echo "xcodes is not installed. Run 'just install-xcode' first." >&2; exit 1; }
    xcodes installed

# Select a full Xcode installation and perform its first-run setup.
setup-xcode app=xcode_app:
    test -d "{{ app }}/Contents/Developer" || { echo "Not a full Xcode application: {{ app }}" >&2; exit 1; }
    sudo xcode-select --switch "{{ app }}/Contents/Developer"
    sudo xcodebuild -license accept
    sudo xcodebuild -runFirstLaunch
    just doctor

# Show and validate the active macOS/Xcode toolchain. This is intentionally
# verbose because it is an explicit diagnostic command.
doctor:
    @command -v swift >/dev/null || { echo "missing: swift" >&2; exit 1; }
    @command -v xcodebuild >/dev/null || { echo "missing: xcodebuild" >&2; exit 1; }
    @command -v xcodegen >/dev/null || { echo "missing: xcodegen (brew install xcodegen)" >&2; exit 1; }
    @command -v xcbeautify >/dev/null || { echo "missing: xcbeautify" >&2; exit 1; }
    @echo "✓ doctor"

# Quiet health check used by `just check`. The generated Xcode project is not
# required to exist yet; `resolve` creates it from project.yml.
[private]
_doctor-check:
    just -- run-quiet "doctor" bash -c '\
      command -v swift >/dev/null || { echo "missing: swift" >&2; exit 1; }; \
      command -v xcodebuild >/dev/null || { echo "missing: xcodebuild" >&2; exit 1; }; \
      command -v xcodegen >/dev/null || { echo "missing: xcodegen (brew install xcodegen)" >&2; exit 1; }; \
      command -v xcbeautify >/dev/null || { echo "missing: xcbeautify" >&2; exit 1; }; \
      developer_dir="$(xcode-select -p 2>/dev/null || true)"; \
      [[ "$developer_dir" == */Contents/Developer ]] || { echo "A full Xcode installation is not selected." >&2; exit 1; }; \
      [[ -f Package.swift ]] || { echo "missing: Package.swift" >&2; exit 1; }; \
      [[ -f project.yml ]] || { echo "missing: project.yml" >&2; exit 1; }; \
      xcodebuild -version; \
      xcrun --sdk macosx --show-sdk-version; \
      swift --version; \
      swift package dump-package >/dev/null; \
      xcodegen --version'

# Initialize the pinned native source dependencies used for Apple mobile-device support.
vendor-init:
    just -- run-quiet "vendor init" git submodule update --init --recursive

# Build and stage the pinned libimobiledevice runtime and AirBattery-owned helper.
# The script is fingerprinted and returns immediately when the staged stack is current.
vendor-mobile: vendor-init
    just -- run-quiet "vendor mobile" bash scripts/build-mobile-stack.sh

# Report pinned submodule and generated-runtime state without cloning or building.
vendor-mobile-status:
    printf '%s\n' '--- Pinned source dependencies ---'; \
      git config -f .gitmodules --get-regexp path | awk '{print $2}' | \
      while read -r path; do \
        expected="$(git ls-files --stage -- "$path" | awk '{print $2}')"; \
        if git -C "$path" rev-parse --git-dir >/dev/null 2>&1; then \
          actual="$(git -C "$path" rev-parse HEAD)"; \
          if [[ "$actual" == "$expected" ]]; then state='ready'; else state='DIFFERS'; fi; \
          printf '%-38s %-16s %s\n' "$path" "$state" "$actual"; \
        else \
          printf '%-38s %-16s %s\n' "$path" 'not initialized' "$expected"; \
        fi; \
      done; \
      printf '%s\n' '--- Component cache ---'; \
      stamp_dir=".build/vendor/mobile/stamps"; \
      if [[ -d "$stamp_dir" ]] && compgen -G "$stamp_dir/*" >/dev/null; then \
        for stamp in "$stamp_dir"/*; do \
          [[ -f "$stamp" ]] || continue; \
          printf '%-38s %s\n' "$(basename "$stamp")" "$(cat "$stamp")"; \
        done; \
      else \
        printf '%s\n' 'empty'; \
      fi; \
      printf '%s\n' '--- Generated runtime ---'; \
      stage="AirBattery/libimobiledevice"; \
      if [[ -f "$stage/MANIFEST.txt" ]]; then \
        printf '%s\n' 'present'; \
        cat "$stage/MANIFEST.txt"; \
      else \
        printf '%s\n' 'not built'; \
      fi

# Inspect an already-generated mobile runtime. Intentionally verbose.
vendor-mobile-diagnose:
    stage="AirBattery/libimobiledevice"; \
      if [[ ! -f "$stage/MANIFEST.txt" || ! -d "$stage/bin" || ! -d "$stage/lib" ]]; then \
        printf '%s\n' \
          'Mobile vendor runtime has not been built.' \
          'Run just vendor-mobile to build it, or just vendor-mobile-diagnose-build to build and diagnose in one command.' >&2; \
        exit 2; \
      fi; \
      printf '%s\n' '--- Manifest ---'; \
      cat "$stage/MANIFEST.txt"; \
      printf '%s\n' '--- Runtime files ---'; \
      find "$stage/bin" "$stage/lib" -maxdepth 1 -type f -print | sort; \
      printf '%s\n' '--- Mach-O linkage ---'; \
      for file in "$stage"/bin/* "$stage"/lib/*; do \
        [[ -f "$file" && ! -L "$file" ]] || continue; \
        if /usr/bin/file "$file" | /usr/bin/grep -q 'Mach-O'; then \
          printf '\n[%s]\n' "$file"; \
          /usr/bin/file "$file"; \
          /usr/bin/otool -L "$file"; \
          /usr/bin/codesign --verify --verbose=1 "$file"; \
        fi; \
      done

# Build/update the mobile runtime, then run the observational diagnostics.
vendor-mobile-diagnose-build: vendor-mobile
    just vendor-mobile-diagnose

# Remove generated native mobile-device build products while keeping source submodules.
vendor-mobile-clean:
    rm -rf ".build/vendor/mobile"
    rm -rf "AirBattery/libimobiledevice/bin" "AirBattery/libimobiledevice/lib" "AirBattery/libimobiledevice/licenses"
    rm -f "AirBattery/libimobiledevice/MANIFEST.txt"
    printf '✓ vendor clean\n'

# Resolve SwiftPM dependencies, regenerate the disposable Xcode packaging
# project, and resolve package references used by that generated project.
resolve:
    just -- run-quiet "swift resolve" swift package resolve
    just -- run-quiet "xcodegen" xcodegen generate --spec project.yml
    just -- _xcode "xcode resolve" \
      -resolvePackageDependencies \
      -project "{{ project }}" \
      -scheme "{{ scheme }}"
    printf '✓ resolve\n'

# Run the hostless SwiftPM test suite.
swift-test:
    just -- run-quiet "swift test" swift test

# Compatibility alias for callers that explicitly request an Xcode build.
xcode-build: (build "Debug")

# Run SwiftPM tests and an unsigned integration build of the app/widget package.
test: resolve swift-test (build "Debug")
    printf '✓ test\n'

# Build AirBattery without code signing. Defaults to Debug.
build configuration="Debug": resolve vendor-mobile
    mkdir -p "{{ derived_data }}"
    just -- _xcode "build {{ configuration }}" \
      -project "{{ project }}" \
      -scheme "{{ scheme }}" \
      -configuration "{{ configuration }}" \
      -destination "{{ mac_destination }}" \
      -derivedDataPath "{{ derived_data }}" \
      CODE_SIGNING_ALLOWED=NO \
      build

# Build a Release configuration without code signing.
release: (build "Release")

# Show installed code-signing identities.
signing-identities:
    /usr/bin/security find-identity -v -p codesigning

# Print the signing identity that local signed builds will use.
# SIGNING_IDENTITY overrides automatic Apple Development identity discovery.
signing-identity:
    requested="{{ signing_identity }}"; \
      if [[ -n "$requested" ]]; then \
        printf '%s\n' "$requested"; \
        exit 0; \
      fi; \
      identity="$(/usr/bin/security find-identity -v -p codesigning | \
        /usr/bin/sed -nE 's/^[[:space:]]*[0-9]+\) [0-9A-F]+ "([^"]*Apple Development:[^"]*)"$/\1/p' | \
        /usr/bin/head -n 1)"; \
      if [[ -z "$identity" ]]; then \
        printf '%s\n' \
          "No Apple Development signing identity is installed." \
          "Run 'just signing-identities' to inspect available identities." >&2; \
        exit 1; \
      fi; \
      printf '%s\n' "$identity"

# Re-sign an already-built ad-hoc app with the selected development identity.
[private]
_sign-build configuration="Debug":
    identity="$(just signing-identity)"; \
      app="{{ derived_data }}/Build/Products/{{ configuration }}/AirBattery.app"; \
      test -d "$app" || { echo "Missing $app after ad-hoc build." >&2; exit 1; }; \
      sign_one() { \
        if /usr/bin/codesign -d "$1" >/dev/null 2>&1; then \
          /usr/bin/codesign \
            --force \
            --sign "$identity" \
            --timestamp=none \
            --preserve-metadata=identifier,entitlements,flags,runtime \
            "$1"; \
        else \
          /usr/bin/codesign \
            --force \
            --sign "$identity" \
            --timestamp=none \
            "$1"; \
        fi; \
      }; \
      while IFS=$'\t' read -r _ path; do \
        [[ -n "$path" ]] && sign_one "$path"; \
      done < <( \
        { \
          for root in \
            "$app/Contents/MacOS" \
            "$app/Contents/Frameworks" \
            "$app/Contents/PlugIns" \
            "$app/Contents/Library" \
            "$app/Contents/Resources/libimobiledevice"; do \
            [[ -e "$root" ]] && /usr/bin/find -L "$root" -type f -print0; \
          done; \
          [[ -f "$app/Contents/Resources/abt" ]] && printf '%s\0' "$app/Contents/Resources/abt"; \
        } | \
          while IFS= read -r -d '' path; do \
            if /usr/bin/file -L "$path" | /usr/bin/grep -q 'Mach-O'; then \
              slashes="${path//[^\\/]/}"; \
              depth="${#slashes}"; \
              printf '%s\t%s\n' "$depth" "$path"; \
            fi; \
          done | /usr/bin/sort -rn \
      ); \
      while IFS=$'\t' read -r _ path; do \
        [[ -n "$path" ]] && sign_one "$path"; \
      done < <( \
        /usr/bin/find "$app/Contents" -type d \
          \( -name '*.framework' -o -name '*.xpc' -o -name '*.appex' -o -name '*.app' -o -name '*.bundle' \) \
          -print | \
          while IFS= read -r path; do \
            slashes="${path//[^\\/]/}"; \
            depth="${#slashes}"; \
            printf '%s\t%s\n' "$depth" "$path"; \
          done | /usr/bin/sort -rn \
      ); \
      sign_one "$app"; \
      if [[ "$identity" != "-" ]]; then \
        actual_team="$(/usr/bin/codesign -dvv "$app" 2>&1 | /usr/bin/sed -n 's/^TeamIdentifier=//p')"; \
        [[ -n "$actual_team" && "$actual_team" != "not set" ]] || { \
          echo "Development-signed app has no TeamIdentifier." >&2; \
          exit 1; \
        }; \
      fi

# Build with Xcode's reliable ad-hoc path, then re-sign nested code objects.
build-signed configuration="Debug":
    just build-adhoc "{{ configuration }}"
    just -- run-quiet "sign {{ configuration }}" just _sign-build "{{ configuration }}"
    just verify-signing "{{ configuration }}"

# Build all products ad-hoc. This is the stable Xcode build path and the first
# stage of build-signed. Do not install it directly for TCC-sensitive testing.
build-adhoc configuration="Debug": resolve vendor-mobile
    mkdir -p "{{ derived_data }}"
    just -- _xcode "build ad-hoc {{ configuration }}" \
      -project "{{ project }}" \
      -scheme "{{ scheme }}" \
      -configuration "{{ configuration }}" \
      -destination "{{ mac_destination }}" \
      -derivedDataPath "{{ derived_data }}" \
      CODE_SIGNING_ALLOWED=YES \
      CODE_SIGNING_REQUIRED=YES \
      CODE_SIGN_STYLE=Manual \
      CODE_SIGN_IDENTITY=- \
      DEVELOPMENT_TEAM="" \
      build
    just verify-signing "{{ configuration }}"

# Verify the host app and embedded widget signatures and identifiers.
verify-signing configuration="Debug":
    just -- run-quiet "verify signing {{ configuration }}" bash -c '\
      app="{{ derived_data }}/Build/Products/{{ configuration }}/AirBattery.app"; \
      widget="$app/Contents/PlugIns/AirBatteryWidgetExtension.appex"; \
      test -d "$app" || { echo "Missing $app; run just build-signed {{ configuration }} first." >&2; exit 1; }; \
      test -d "$widget" || { echo "Missing embedded widget extension: $widget" >&2; exit 1; }; \
      codesign --verify --deep --strict --verbose=2 "$app"; \
      [[ "$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$app/Contents/Info.plist")" == "{{ app_bundle_id }}" ]] || { echo "Unexpected app bundle identifier." >&2; exit 1; }; \
      [[ "$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$widget/Contents/Info.plist")" == "{{ widget_bundle_id }}" ]] || { echo "Unexpected widget bundle identifier." >&2; exit 1; }; \
      test -n "$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$app/Contents/Info.plist")" || { echo "Missing app marketing version." >&2; exit 1; }; \
      test -n "$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$app/Contents/Info.plist")" || { echo "Missing app build number." >&2; exit 1; }; \
      test -n "$(/usr/libexec/PlistBuddy -c "Print :SUFeedURL" "$app/Contents/Info.plist")" || { echo "Missing Sparkle feed URL." >&2; exit 1; }; \
      test -n "$(/usr/libexec/PlistBuddy -c "Print :SUPublicEDKey" "$app/Contents/Info.plist")" || { echo "Missing Sparkle public key." >&2; exit 1; }; \
      assets="$app/Contents/Resources/Assets.car"; \
      test -f "$assets" || { echo "Missing compiled app asset catalog: $assets" >&2; exit 1; }'

# Compute the semantic fingerprint of a locally installed build.
# This intentionally hashes only build inputs, not documentation/tests or build caches.
install-fingerprint configuration="Debug":
    configuration="{{ configuration }}"; \
      install_dir="${AIRBATTERY_INSTALL_DIR:-$HOME/Applications}"; \
      identity="$(just signing-identity)"; \
      vendor_arch="${AIRBATTERY_VENDOR_ARCH:-$(uname -m)}"; \
      vendor_min="26.0"; \
      { \
        printf '%s\n' \
          'schema=2' \
          "configuration=$configuration" \
          "install_dir=$install_dir" \
          "signing_identity=$identity" \
          "host_arch=$(uname -m)" \
          "vendor_arch=$vendor_arch" \
          "vendor_macos_min=$vendor_min" \
          "developer_dir=${DEVELOPER_DIR:-$(xcode-select -p 2>/dev/null || true)}" \
          "xcode=$(xcodebuild -version 2>/dev/null | /usr/bin/tr '\n' '|')" \
          "sdk=$(xcrun --sdk macosx --show-sdk-version 2>/dev/null)" \
          "sdk_path=$(xcrun --sdk macosx --show-sdk-path 2>/dev/null)" \
          "swift=$(xcrun swiftc --version 2>/dev/null | /usr/bin/head -n 1)"; \
        printf '%s\n' '--- tracked build inputs ---'; \
        git ls-files -s -- \
          AirBattery widget abt Packaging tools/mobile \
          Package.swift Package.resolved project.yml \
          scripts/build-mobile-stack.sh justfile .gitmodules; \
        printf '%s\n' '--- worktree build-input diff ---'; \
        git diff --no-ext-diff --no-textconv --binary -- \
          AirBattery widget abt Packaging tools/mobile \
          Package.swift Package.resolved project.yml \
          scripts/build-mobile-stack.sh justfile .gitmodules; \
        printf '%s\n' '--- untracked build inputs ---'; \
        while IFS= read -r -d '' path; do \
          if [[ -L "$path" ]]; then \
            printf 'symlink\t%s\t%s\n' "$path" "$(readlink "$path")"; \
          elif [[ -f "$path" ]]; then \
            printf 'file\t%s\t%s\t%s\n' \
              "$path" \
              "$(/usr/bin/stat -f '%Lp' "$path")" \
              "$(git hash-object -- "$path")"; \
          else \
            printf 'missing\t%s\n' "$path"; \
          fi; \
        done < <(git ls-files -o --exclude-standard -z -- \
          AirBattery widget abt Packaging tools/mobile \
          Package.swift Package.resolved project.yml \
          scripts/build-mobile-stack.sh justfile .gitmodules); \
        printf '%s\n' '--- submodules ---'; \
        git config -f .gitmodules --get-regexp path | /usr/bin/awk '{print $2}' | \
          while read -r path; do \
            expected="$(git ls-files --stage -- "$path" | /usr/bin/awk '{print $2}')"; \
            if git -C "$path" rev-parse --git-dir >/dev/null 2>&1; then \
              actual="$(git -C "$path" rev-parse HEAD)"; \
            else \
              actual='<not-initialized>'; \
            fi; \
            printf '%s\t%s\t%s\n' "$path" "$expected" "$actual"; \
          done; \
      } | /usr/bin/shasum -a 256 | /usr/bin/awk '{print $1}'

# Exit successfully only when the installed app exactly matches current build inputs.
installed-current configuration="Debug":
    configuration="{{ configuration }}"; \
      state="{{ install_state_dir }}/$configuration.state"; \
      install_dir="${AIRBATTERY_INSTALL_DIR:-$HOME/Applications}"; \
      app="$install_dir/AirBattery.app"; \
      widget="$app/Contents/PlugIns/AirBatteryWidgetExtension.appex"; \
      [[ -f "$state" && -d "$app" && -d "$widget" ]] || exit 1; \
      recorded_path="$(/usr/bin/sed -n 's/^app_path=//p' "$state")"; \
      [[ "$recorded_path" == "$app" ]] || exit 1; \
      recorded_fp="$(/usr/bin/sed -n 's/^fingerprint=//p' "$state")"; \
      expected_fp="$(just install-fingerprint "$configuration")"; \
      [[ -n "$recorded_fp" && "$recorded_fp" == "$expected_fp" ]] || exit 1; \
      /usr/bin/codesign --verify --deep --strict "$app" >/dev/null 2>&1 || exit 1; \
      [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist" 2>/dev/null)" == "{{ app_bundle_id }}" ]] || exit 1; \
      [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$widget/Contents/Info.plist" 2>/dev/null)" == "{{ widget_bundle_id }}" ]] || exit 1; \
      recorded_cdhash="$(/usr/bin/sed -n 's/^cdhash=//p' "$state")"; \
      actual_cdhash="$(/usr/bin/codesign -dvvv "$app" 2>&1 | /usr/bin/sed -n 's/^CDHash=//p' | /usr/bin/head -n 1)"; \
      [[ -n "$recorded_cdhash" && "$recorded_cdhash" == "$actual_cdhash" ]] || exit 1

# Record a successfully installed and verified app atomically.
install-state-write configuration="Debug":
    configuration="{{ configuration }}"; \
      state_dir="{{ install_state_dir }}"; \
      state="$state_dir/$configuration.state"; \
      install_dir="${AIRBATTERY_INSTALL_DIR:-$HOME/Applications}"; \
      app="$install_dir/AirBattery.app"; \
      /usr/bin/codesign --verify --deep --strict "$app" >/dev/null; \
      fingerprint="$(just install-fingerprint "$configuration")"; \
      cdhash="$(/usr/bin/codesign -dvvv "$app" 2>&1 | /usr/bin/sed -n 's/^CDHash=//p' | /usr/bin/head -n 1)"; \
      [[ -n "$cdhash" ]] || { echo "Unable to determine installed app CDHash." >&2; exit 1; }; \
      mkdir -p "$state_dir"; \
      tmp="$state.tmp.$$.${RANDOM}"; \
      trap 'rm -f "$tmp"' EXIT; \
      printf '%s\n' \
        'schema=2' \
        "configuration=$configuration" \
        "app_path=$app" \
        "fingerprint=$fingerprint" \
        "cdhash=$cdhash" > "$tmp"; \
      /bin/mv "$tmp" "$state"; \
      trap - EXIT

# Explain the cached-install decision without modifying or rebuilding anything.
install-state configuration="Debug":
    configuration="{{ configuration }}"; \
      state="{{ install_state_dir }}/$configuration.state"; \
      install_dir="${AIRBATTERY_INSTALL_DIR:-$HOME/Applications}"; \
      app="$install_dir/AirBattery.app"; \
      expected="$(just install-fingerprint "$configuration")"; \
      recorded=''; \
      [[ -f "$state" ]] && recorded="$(/usr/bin/sed -n 's/^fingerprint=//p' "$state")"; \
      disposable=0; \
      products="$PWD/{{ derived_data }}/Build/Products"; \
      if [[ -d "$products" ]]; then \
        shopt -s nullglob; \
        for candidate in "$products"/*/AirBattery.app; do \
          [[ -d "$candidate" ]] && disposable=$((disposable + 1)); \
        done; \
      fi; \
      printf '%s\n' \
        "Configuration: $configuration" \
        "Installed app: $app" \
        "State file:    $state" \
        "Expected:      $expected" \
        "Recorded:      ${recorded:-<none>}" \
        "Disposable build apps: $disposable"; \
      if just installed-current "$configuration" >/dev/null 2>&1; then \
        printf '%s\n' 'Status:        current'; \
      else \
        printf '%s\n' 'Status:        stale or invalid'; \
      fi

# Stop the containing app while leaving the WidgetKit extension alone.
stop-host:
    /usr/bin/pkill -TERM -x AirBattery >/dev/null 2>&1 || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do \
      if ! /usr/bin/pgrep -x AirBattery >/dev/null 2>&1; then exit 0; fi; \
      /bin/sleep 0.1; \
    done; \
    /usr/bin/pkill -KILL -x AirBattery >/dev/null 2>&1 || true

# Stop every locally running AirBattery process.
stop: stop-host
    /usr/bin/pkill -TERM -x AirBatteryWidgetExtension >/dev/null 2>&1 || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do \
      if ! /usr/bin/pgrep -x AirBatteryWidgetExtension >/dev/null 2>&1; then exit 0; fi; \
      /bin/sleep 0.1; \
    done; \
    /usr/bin/pkill -KILL -x AirBatteryWidgetExtension >/dev/null 2>&1 || true

# Build and atomically install the complete signed app.
install-local configuration="Debug":
    just build-signed "{{ configuration }}"
    just -- run-quiet "install {{ configuration }}" bash -c '\
      src="{{ derived_data }}/Build/Products/{{ configuration }}/AirBattery.app"; \
      install_dir="${AIRBATTERY_INSTALL_DIR:-$HOME/Applications}"; \
      dst="$install_dir/AirBattery.app"; \
      token="$(/usr/bin/uuidgen)"; \
      stage="$install_dir/.AirBattery.app.new.$token"; \
      backup="$install_dir/.AirBattery.app.old.$token"; \
      mkdir -p "$install_dir"; \
      rm -rf "$stage" "$backup"; \
      cleanup() { rm -rf "$stage" "$backup"; }; \
      trap cleanup EXIT; \
      /usr/bin/ditto "$src" "$stage"; \
      /usr/bin/codesign --verify --deep --strict --verbose=2 "$stage"; \
      src_widget="$src/Contents/PlugIns/AirBatteryWidgetExtension.appex"; \
      if [[ -d "$src_widget" ]]; then /usr/bin/pluginkit -r "$src_widget" >/dev/null 2>&1 || true; fi; \
      /bin/rm -rf "$src"; \
      just stop-host; \
      if [[ -e "$dst" ]]; then /bin/mv "$dst" "$backup"; fi; \
      if ! /bin/mv "$stage" "$dst"; then \
        if [[ -e "$backup" && ! -e "$dst" ]]; then /bin/mv "$backup" "$dst"; fi; \
        echo "Failed to install staged AirBattery bundle." >&2; \
        exit 1; \
      fi; \
      /usr/bin/codesign --verify --deep --strict --verbose=2 "$dst" || { \
        rm -rf "$dst"; \
        if [[ -e "$backup" ]]; then /bin/mv "$backup" "$dst"; fi; \
        echo "Installed AirBattery bundle failed signature verification; restored previous build." >&2; \
        exit 1; \
      }; \
      rm -rf "$backup"; \
      /usr/bin/pkill -TERM -x AirBatteryWidgetExtension >/dev/null 2>&1 || true; \
      trap - EXIT'
    just widget-registration-clean
    install_dir="${AIRBATTERY_INSTALL_DIR:-$HOME/Applications}"; \
      widget="$install_dir/AirBattery.app/Contents/PlugIns/AirBatteryWidgetExtension.appex"; \
      /usr/bin/pluginkit -a "$widget" >/dev/null 2>&1 || true; \
      /usr/bin/pluginkit -e use \
        -p com.apple.widgetkit-extension \
        -i "{{ widget_bundle_id }}" >/dev/null 2>&1 || true
    just install-state-write "{{ configuration }}"

# Launch the current installed app. Rebuild only when stale.
run configuration="Debug":
    configuration="{{ configuration }}"; \
      if just installed-current "$configuration" >/dev/null 2>&1; then \
        printf '%s\n' "AirBattery $configuration install is current; skipping build and install."; \
        just widget-registration-clean; \
      else \
        printf '%s\n' "AirBattery $configuration install is stale; rebuilding and installing."; \
        just install-local "$configuration"; \
      fi; \
      install_dir="${AIRBATTERY_INSTALL_DIR:-$HOME/Applications}"; \
      /usr/bin/open "$install_dir/AirBattery.app"

# Explicitly bypass the install cache.
run-force configuration="Debug":
    just install-local "{{ configuration }}"
    install_dir="${AIRBATTERY_INSTALL_DIR:-$HOME/Applications}"; /usr/bin/open "$install_dir/AirBattery.app"

# Reset macOS Bluetooth privacy consent for this fork.
reset-bluetooth-permission:
    /usr/bin/tccutil reset BluetoothAlways "{{ app_bundle_id }}"

# Inspect installed Bluetooth/signing state. Intentionally verbose.
bluetooth-diagnose:
    app="${AIRBATTERY_INSTALL_DIR:-$HOME/Applications}/AirBattery.app"; \
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
      printf '%s\n' '--- Bluetooth-related preferences ---'; \
      for key in whitelistMode blockedDevices readBTDevice readBLEDevice ideviceOverBLE bleDiscoveryMode readBTHID; do \
        printf '%s=' "$key"; \
        /usr/bin/defaults read "{{ app_bundle_id }}" "$key" 2>/dev/null || echo '<unset>'; \
      done; \
      printf '%s\n' '--- Running processes ---'; \
      /usr/bin/pgrep -alf 'AirBattery|AirBatteryWidgetExtension' || true; \
      printf '%s\n' '--- Recent Bluetooth/BLE logs ---'; \
      /usr/bin/log show --last 10m --style compact --predicate 'process == "AirBattery"' 2>/dev/null | \
        /usr/bin/grep -E 'Bluetooth|BLE|permission|scanning' | /usr/bin/tail -n 80 || true; \
      printf '%s\n' '--- Available signing identities ---'; \
      /usr/bin/security find-identity -v -p codesigning

# Show whether macOS currently knows about the AirBattery WidgetKit extension.
widget-status:
    /usr/bin/pluginkit -m -A -D -v -i "{{ widget_bundle_id }}" || true

# Remove registrations for disposable Xcode build-product copies of the widget.
widget-registration-clean:
    products="$PWD/{{ derived_data }}/Build/Products"; \
      removed=0; \
      if [[ -d "$products" ]]; then \
        shopt -s nullglob; \
        for app in "$products"/*/AirBattery.app; do \
          [[ -d "$app" ]] || continue; \
          widget="$app/Contents/PlugIns/AirBatteryWidgetExtension.appex"; \
          if [[ -d "$widget" ]]; then /usr/bin/pluginkit -r "$widget" >/dev/null 2>&1 || true; fi; \
          /bin/rm -rf "$app"; \
          removed=$((removed + 1)); \
        done; \
      fi; \
      printf '✓ widget registration clean (%d removed)\n' "$removed"

# Show every physical registration for the AirBattery WidgetKit extension.
widget-registration-status:
    install_dir="${AIRBATTERY_INSTALL_DIR:-$HOME/Applications}"; \
      widget="$install_dir/AirBattery.app/Contents/PlugIns/AirBatteryWidgetExtension.appex"; \
      if [[ -d "$widget" ]]; then \
        printf '%s\n' "--- Installed widget bundle version ---"; \
        /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$widget/Contents/Info.plist" 2>/dev/null || true; \
        /usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$widget/Contents/Info.plist" 2>/dev/null || true; \
      fi; \
      printf '%s\n' "--- PlugInKit registrations ---"; \
      /usr/bin/pluginkit -m -A -D -vv -p com.apple.widgetkit-extension -i "{{ widget_bundle_id }}" || true

# Remove the locally installed development build.
uninstall-local:
    just stop
    install_dir="${AIRBATTERY_INSTALL_DIR:-$HOME/Applications}"; \
      rm -rf "$install_dir/AirBattery.app"; \
      rm -rf "{{ install_state_dir }}"; \
      printf '✓ uninstall\n'

# The deterministic hostless test suite is owned by SwiftPM; see `swift-test`
# and the combined `test` recipe above.

# Silent structural/signing verification used by test-runtime.
[private]
_vendor-mobile-verify:
    stage="AirBattery/libimobiledevice"; \
      [[ -f "$stage/MANIFEST.txt" ]] || { echo "Missing runtime manifest: $stage/MANIFEST.txt" >&2; exit 1; }; \
      [[ -d "$stage/bin" ]] || { echo "Missing runtime bin directory: $stage/bin" >&2; exit 1; }; \
      [[ -d "$stage/lib" ]] || { echo "Missing runtime lib directory: $stage/lib" >&2; exit 1; }; \
      for file in "$stage"/bin/* "$stage"/lib/*; do \
        [[ -f "$file" && ! -L "$file" ]] || continue; \
        if /usr/bin/file "$file" | /usr/bin/grep -q 'Mach-O'; then \
          /usr/bin/otool -L "$file" >/dev/null; \
          /usr/bin/codesign --verify --verbose=1 "$file"; \
        fi; \
      done

# Verify the staged native runtime without requiring a connected mobile device.
test-runtime: vendor-mobile
    just -- run-quiet "runtime" bash -c '\
      bin="AirBattery/libimobiledevice/bin/airbattery-mobile"; \
      set +e; "$bin" >/dev/null 2>&1; rc=$?; set -e; \
      if [[ "$rc" -ne 2 ]]; then \
        echo "airbattery-mobile usage smoke test failed: expected 2, got $rc" >&2; \
        just vendor-mobile-diagnose; \
        exit 1; \
      fi; \
      set +e; \
      just _vendor-mobile-verify; verify_rc=$?; \
      set -e; \
      if [[ "$verify_rc" -ne 0 ]]; then \
        printf "\n--- runtime diagnostics ---\n" >&2; \
        just vendor-mobile-diagnose >&2 || true; \
        exit "$verify_rc"; \
      fi'

# Exercise real USB/network iDevice battery reads and companion-proxy stress tests.
test-hardware: vendor-mobile
    just -- run-quiet "hardware" bash scripts/test-mobile-hardware.sh

# Run the normal local verification path. `test` includes SwiftPM tests and
# the unsigned Xcode packaging build; test-runtime verifies the staged native
# mobile-device runtime. Dependencies run only once per just invocation.
check: _doctor-check test test-runtime
    printf '✓ check\n'

# Run the same SwiftPM tests and unsigned packaging build used by CI.
ci: _doctor-check resolve swift-test vendor-mobile
    just -- _xcode "ci build" \
      -project "{{ project }}" \
      -scheme "{{ scheme }}" \
      -configuration Debug \
      -destination "{{ mac_destination }}" \
      -derivedDataPath "{{ derived_data }}" \
      CODE_SIGNING_ALLOWED=NO \
      CODE_SIGNING_REQUIRED=NO \
      build

# Print the expected locally built application path.
app-path configuration="Debug":
    printf '%s/%s\n' "$PWD" "{{ derived_data }}/Build/Products/{{ configuration }}/AirBattery.app"

# Remove SwiftPM/Xcode build products, the generated Xcode project, and staged
# native runtime products. Package.resolved remains tracked/reproducible state.
clean:
    rm -rf ".build" ".swiftpm" "{{ project }}"
    just vendor-mobile-clean
    printf '✓ clean\n'
