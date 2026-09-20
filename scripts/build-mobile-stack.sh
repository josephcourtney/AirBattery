#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_ROOT="$ROOT/.build/vendor/mobile"
WORK_ROOT="$BUILD_ROOT/work"
PREFIX="$BUILD_ROOT/prefix"
STAMP_ROOT="$BUILD_ROOT/stamps"
STAGE="$ROOT/AirBattery/libimobiledevice"
ARCH="${AIRBATTERY_VENDOR_ARCH:-$(uname -m)}"
MACOS_MIN="${AIRBATTERY_VENDOR_MACOS_MIN:-12.0}"
JOBS="${AIRBATTERY_VENDOR_JOBS:-$(sysctl -n hw.ncpu 2>/dev/null || echo 4)}"

SUBMODULES=(
  "third_party/openssl"
  "third_party/libplist"
  "third_party/libimobiledevice-glue"
  "third_party/libusbmuxd"
  "third_party/libtatsu"
  "third_party/libimobiledevice"
)

# Bump only the recipe whose build/staging logic changed. These versions are
# deliberately per-component: editing one helper must not invalidate OpenSSL
# and the complete libimobiledevice dependency chain.
RECIPE_OPENSSL=1
RECIPE_LIBPLIST=1
RECIPE_GLUE=1
RECIPE_USBMUXD=1
RECIPE_TATSU=1
RECIPE_LIBIMOBILEDEVICE=1
RECIPE_AIRBATTERY_MOBILE=1
RECIPE_WIFICONNECTION=1
RECIPE_STAGE=2

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'Missing required command: %s\n' "$1" >&2
    exit 2
  }
}

# Xcode shell phases do not reliably inherit the interactive shell PATH.
BREW=""
for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
  if [[ -x "$candidate" ]]; then
    BREW="$candidate"
    break
  fi
done
if [[ -n "$BREW" ]]; then
  eval "$("$BREW" shellenv)"
fi

for command in git make perl pkg-config autoconf automake autoreconf xcrun otool install_name_tool shasum codesign lipo; do
  require_command "$command"
done

# Homebrew installs GNU libtool with a "g" prefix to avoid colliding with
# Apple's unrelated /usr/bin/libtool. Autoreconf needs the GNU implementation.
if command -v glibtoolize >/dev/null 2>&1; then
  export LIBTOOLIZE="$(command -v glibtoolize)"
elif [[ -n "$BREW" ]]; then
  libtool_gnubin="$("$BREW" --prefix libtool 2>/dev/null || true)/libexec/gnubin"
  if [[ -d "$libtool_gnubin" ]]; then
    export PATH="$libtool_gnubin:$PATH"
  fi
fi
if ! command -v libtoolize >/dev/null 2>&1 && [[ -z "${LIBTOOLIZE:-}" ]]; then
  printf '%s\n' \
    'GNU libtool is required to build the mobile stack.' \
    'Install it with: brew install libtool' >&2
  exit 2
fi

for path in "${SUBMODULES[@]}"; do
  if [[ ! -e "$ROOT/$path/.git" && ! -f "$ROOT/$path/.git" ]]; then
    printf 'Submodule is not initialized: %s\n' "$path" >&2
    printf '%s\n' 'Run: git submodule update --init --recursive' >&2
    exit 2
  fi

  expected="$(git -C "$ROOT" ls-files --stage -- "$path" | awk '{print $2}')"
  actual="$(git -C "$ROOT/$path" rev-parse HEAD)"
  if [[ -z "$expected" || "$actual" != "$expected" ]]; then
    printf 'Submodule %s is not at the commit pinned in the AirBattery index.\n' "$path" >&2
    printf 'Expected: %s\nActual:   %s\n' "$expected" "$actual" >&2
    printf '%s\n' 'Run: git submodule update --init --recursive' >&2
    exit 2
  fi
done

CC="$(xcrun --sdk macosx --find clang)"
SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
SDK_VERSION="$(xcrun --sdk macosx --show-sdk-version)"
export CC
export SDKROOT
export MACOSX_DEPLOYMENT_TARGET="$MACOS_MIN"
export CFLAGS="-arch $ARCH -isysroot $SDKROOT -mmacosx-version-min=$MACOS_MIN -O2"
export CPPFLAGS="-I$PREFIX/include -isysroot $SDKROOT"
export LDFLAGS="-arch $ARCH -isysroot $SDKROOT -mmacosx-version-min=$MACOS_MIN -L$PREFIX/lib"
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PREFIX/share/pkgconfig"
export PATH="$PREFIX/bin:$PATH"

mkdir -p "$BUILD_ROOT" "$WORK_ROOT/src" "$WORK_ROOT/build" "$PREFIX" "$STAMP_ROOT"

hash_values() {
  printf '%s\n' "$@" | shasum -a 256 | awk '{print $1}'
}

hash_file() {
  shasum -a 256 "$1" | awk '{print $1}'
}

submodule_sha() {
  git -C "$ROOT/$1" rev-parse HEAD
}

toolchain_fingerprint="$(
  hash_values \
    "arch=$ARCH" \
    "macos_min=$MACOS_MIN" \
    "sdk=$SDK_VERSION" \
    "sdkroot=$SDKROOT" \
    "cc=$("$CC" --version | head -n 1)"
)"

openssl_sha="$(submodule_sha third_party/openssl)"
plist_sha="$(submodule_sha third_party/libplist)"
glue_sha="$(submodule_sha third_party/libimobiledevice-glue)"
usbmuxd_sha="$(submodule_sha third_party/libusbmuxd)"
tatsu_sha="$(submodule_sha third_party/libtatsu)"
limd_sha="$(submodule_sha third_party/libimobiledevice)"

openssl_fp="$(hash_values "recipe=$RECIPE_OPENSSL" "$toolchain_fingerprint" "$openssl_sha")"
plist_fp="$(hash_values "recipe=$RECIPE_LIBPLIST" "$toolchain_fingerprint" "$plist_sha")"
glue_fp="$(hash_values "recipe=$RECIPE_GLUE" "$toolchain_fingerprint" "$glue_sha" "libplist=$plist_fp")"
usbmuxd_fp="$(hash_values "recipe=$RECIPE_USBMUXD" "$toolchain_fingerprint" "$usbmuxd_sha" "libplist=$plist_fp" "glue=$glue_fp")"
tatsu_fp="$(hash_values "recipe=$RECIPE_TATSU" "$toolchain_fingerprint" "$tatsu_sha" "libplist=$plist_fp" "system-libcurl=$SDK_VERSION")"
limd_fp="$(hash_values \
  "recipe=$RECIPE_LIBIMOBILEDEVICE" \
  "$toolchain_fingerprint" \
  "$limd_sha" \
  "openssl=$openssl_fp" \
  "libplist=$plist_fp" \
  "glue=$glue_fp" \
  "usbmuxd=$usbmuxd_fp" \
  "tatsu=$tatsu_fp"
)"
airbattery_mobile_fp="$(hash_values \
  "recipe=$RECIPE_AIRBATTERY_MOBILE" \
  "$toolchain_fingerprint" \
  "source=$(hash_file "$ROOT/tools/mobile/airbattery-mobile.c")" \
  "libimobiledevice=$limd_fp" \
  "libplist=$plist_fp"
)"
wificonnection_fp="$(hash_values \
  "recipe=$RECIPE_WIFICONNECTION" \
  "$toolchain_fingerprint" \
  "source=$(hash_file "$ROOT/tools/mobile/wificonnection.c")" \
  "libimobiledevice=$limd_fp" \
  "usbmuxd=$usbmuxd_fp" \
  "libplist=$plist_fp"
)"
stage_fp="$(hash_values \
  "recipe=$RECIPE_STAGE" \
  "$toolchain_fingerprint" \
  "libimobiledevice=$limd_fp" \
  "airbattery-mobile=$airbattery_mobile_fp" \
  "wificonnection=$wificonnection_fp"
)"

stamp_path() {
  printf '%s/%s' "$STAMP_ROOT" "$1"
}

component_cached() {
  local name="$1"
  local fingerprint="$2"
  shift 2
  local stamp artifact

  stamp="$(stamp_path "$name")"
  [[ -f "$stamp" ]] || return 1
  [[ "$(cat "$stamp")" == "$fingerprint" ]] || return 1

  for artifact in "$@"; do
    [[ -e "$artifact" ]] || return 1
  done
  return 0
}

write_stamp() {
  printf '%s\n' "$2" > "$(stamp_path "$1")"
}

source_description() {
  git -C "$ROOT/$1" describe --tags --always
}

legacy_build_matches_all_sources() {
  local spec name path marker expected
  for spec in \
    "openssl:third_party/openssl" \
    "libplist:third_party/libplist" \
    "libimobiledevice-glue:third_party/libimobiledevice-glue" \
    "libusbmuxd:third_party/libusbmuxd" \
    "libtatsu:third_party/libtatsu" \
    "libimobiledevice:third_party/libimobiledevice"; do
    name="${spec%%:*}"
    path="${spec#*:}"
    marker="$WORK_ROOT/src/$name/.tarball-version"
    [[ -f "$marker" ]] || return 1
    expected="$(source_description "$path")"
    [[ "$(cat "$marker")" == "$expected" ]] || return 1
  done
  return 0
}

LEGACY_BOOTSTRAP=0
if [[ -z "${AIRBATTERY_VENDOR_ARCH+x}" ]] &&
   [[ -z "${AIRBATTERY_VENDOR_MACOS_MIN+x}" ]] &&
   [[ -z "$(find "$STAMP_ROOT" -type f -maxdepth 1 -print -quit 2>/dev/null)" ]] &&
   legacy_build_matches_all_sources; then
  LEGACY_BOOTSTRAP=1
fi

# Migrate successful outputs produced by the previous all-or-nothing builder.
# This is intentionally conservative: it only applies to the default target,
# verifies the exact materialized source revision, checks all expected outputs,
# and confirms the representative Mach-O/archive contains the current arch.
maybe_bootstrap_component() {
  local name="$1"
  local fingerprint="$2"
  local repo_path="$3"
  local representative="$4"
  shift 4
  local marker expected_desc artifact archs

  [[ ! -f "$(stamp_path "$name")" ]] || return 0
  [[ "$LEGACY_BOOTSTRAP" -eq 1 ]] || return 0

  marker="$WORK_ROOT/src/$name/.tarball-version"
  [[ -f "$marker" ]] || return 0
  expected_desc="$(source_description "$repo_path")"
  [[ "$(cat "$marker")" == "$expected_desc" ]] || return 0

  for artifact in "$representative" "$@"; do
    [[ -e "$artifact" ]] || return 0
  done

  archs="$(lipo -archs "$representative" 2>/dev/null || true)"
  case " $archs " in
    *" $ARCH "*) ;;
    *) return 0 ;;
  esac

  write_stamp "$name" "$fingerprint"
  printf '==> Reusing successful %s output from the previous vendor build\n' "$name"
}

materialize() {
  local name="$1"
  local path="$2"
  local dst="$WORK_ROOT/src/$name"

  rm -rf "$dst"
  mkdir -p "$dst"
  git -C "$ROOT/$path" archive --format=tar HEAD | tar -xf - -C "$dst"
  git -C "$ROOT/$path" describe --tags --always > "$dst/.tarball-version"
  printf '%s\n' "$dst"
}

uninstall_autotools() {
  local name="$1"
  local build="$WORK_ROOT/build/$name"
  if [[ -f "$build/Makefile" ]]; then
    make -C "$build" uninstall >/dev/null 2>&1 || true
  fi
}

configure_openssl() {
  local src="$1"
  local target
  case "$ARCH" in
    arm64) target="darwin64-arm64-cc" ;;
    x86_64) target="darwin64-x86_64-cc" ;;
    *)
      printf 'Unsupported macOS architecture: %s\n' "$ARCH" >&2
      exit 2
      ;;
  esac

  rm -rf "$PREFIX/include/openssl"
  rm -f "$PREFIX/lib/libcrypto.a" "$PREFIX/lib/libssl.a"
  rm -f "$PREFIX/lib/pkgconfig/libcrypto.pc" "$PREFIX/lib/pkgconfig/libssl.pc" "$PREFIX/lib/pkgconfig/openssl.pc"

  (
    cd "$src"
    ./Configure "$target" \
      --prefix="$PREFIX" \
      --openssldir="$PREFIX/ssl" \
      no-shared no-tests no-docs \
      "-mmacosx-version-min=$MACOS_MIN"
    make -j"$JOBS"
    make install_sw
  )
}

build_autotools() {
  local name="$1"
  local src="$2"
  shift 2
  local build="$WORK_ROOT/build/$name"

  uninstall_autotools "$name"
  (
    cd "$src"
    autoreconf -fi
  )
  rm -rf "$build"
  mkdir -p "$build"
  (
    cd "$build"
    "$src/configure" \
      --prefix="$PREFIX" \
      --enable-shared \
      --disable-static \
      "$@"
    make -j"$JOBS"
    make install
  )
}

maybe_bootstrap_component \
  openssl "$openssl_fp" third_party/openssl \
  "$PREFIX/lib/libcrypto.a" "$PREFIX/lib/libssl.a"
maybe_bootstrap_component \
  libplist "$plist_fp" third_party/libplist \
  "$PREFIX/lib/libplist-2.0.dylib"
maybe_bootstrap_component \
  libimobiledevice-glue "$glue_fp" third_party/libimobiledevice-glue \
  "$PREFIX/lib/libimobiledevice-glue-1.0.dylib"
maybe_bootstrap_component \
  libusbmuxd "$usbmuxd_fp" third_party/libusbmuxd \
  "$PREFIX/lib/libusbmuxd-2.0.dylib"
maybe_bootstrap_component \
  libtatsu "$tatsu_fp" third_party/libtatsu \
  "$PREFIX/lib/libtatsu-1.0.dylib"
maybe_bootstrap_component \
  libimobiledevice "$limd_fp" third_party/libimobiledevice \
  "$PREFIX/lib/libimobiledevice-1.0.dylib" \
  "$PREFIX/bin/idevice_id" "$PREFIX/bin/ideviceinfo" "$PREFIX/bin/idevicesyslog"

if component_cached openssl "$openssl_fp" "$PREFIX/lib/libcrypto.a" "$PREFIX/lib/libssl.a"; then
  printf '%s\n' '==> OpenSSL: cached'
else
  printf '%s\n' '==> Building OpenSSL'
  openssl_src="$(materialize openssl third_party/openssl)"
  configure_openssl "$openssl_src"
  write_stamp openssl "$openssl_fp"
fi

if component_cached libplist "$plist_fp" "$PREFIX/lib/libplist-2.0.dylib"; then
  printf '%s\n' '==> libplist: cached'
else
  printf '%s\n' '==> Building libplist'
  plist_src="$(materialize libplist third_party/libplist)"
  build_autotools libplist "$plist_src" --without-cython --without-tools --without-tests
  write_stamp libplist "$plist_fp"
fi

if component_cached libimobiledevice-glue "$glue_fp" "$PREFIX/lib/libimobiledevice-glue-1.0.dylib"; then
  printf '%s\n' '==> libimobiledevice-glue: cached'
else
  printf '%s\n' '==> Building libimobiledevice-glue'
  glue_src="$(materialize libimobiledevice-glue third_party/libimobiledevice-glue)"
  build_autotools libimobiledevice-glue "$glue_src"
  write_stamp libimobiledevice-glue "$glue_fp"
fi

if component_cached libusbmuxd "$usbmuxd_fp" "$PREFIX/lib/libusbmuxd-2.0.dylib"; then
  printf '%s\n' '==> libusbmuxd: cached'
else
  printf '%s\n' '==> Building libusbmuxd'
  usbmuxd_src="$(materialize libusbmuxd third_party/libusbmuxd)"
  build_autotools libusbmuxd "$usbmuxd_src"
  write_stamp libusbmuxd "$usbmuxd_fp"
fi

if component_cached libtatsu "$tatsu_fp" "$PREFIX/lib/libtatsu-1.0.dylib"; then
  printf '%s\n' '==> libtatsu: cached'
else
  printf '%s\n' '==> Building libtatsu'
  tatsu_src="$(materialize libtatsu third_party/libtatsu)"
  export libcurl_CFLAGS=""
  export libcurl_LIBS="-lcurl"
  build_autotools libtatsu "$tatsu_src"
  unset libcurl_CFLAGS libcurl_LIBS
  write_stamp libtatsu "$tatsu_fp"
fi

if component_cached \
  libimobiledevice "$limd_fp" \
  "$PREFIX/lib/libimobiledevice-1.0.dylib" \
  "$PREFIX/bin/idevice_id" "$PREFIX/bin/ideviceinfo" "$PREFIX/bin/idevicesyslog"; then
  printf '%s\n' '==> libimobiledevice: cached'
else
  printf '%s\n' '==> Building libimobiledevice'
  limd_src="$(materialize libimobiledevice third_party/libimobiledevice)"
  build_autotools libimobiledevice "$limd_src" --without-cython --with-openssl
  write_stamp libimobiledevice "$limd_fp"
fi

common_flags=(
  -arch "$ARCH"
  -isysroot "$SDKROOT"
  "-mmacosx-version-min=$MACOS_MIN"
  -O2
  -I"$PREFIX/include"
)
read -r -a limd_flags <<<"$(PKG_CONFIG_PATH="$PKG_CONFIG_PATH" pkg-config --libs libimobiledevice-1.0 libplist-2.0)"
read -r -a wifi_flags <<<"$(PKG_CONFIG_PATH="$PKG_CONFIG_PATH" pkg-config --libs libimobiledevice-1.0 libusbmuxd-2.0 libplist-2.0)"

if component_cached airbattery-mobile "$airbattery_mobile_fp" "$PREFIX/bin/airbattery-mobile"; then
  printf '%s\n' '==> airbattery-mobile: cached'
else
  printf '%s\n' '==> Building airbattery-mobile'
  "$CC" "${common_flags[@]}" \
    "$ROOT/tools/mobile/airbattery-mobile.c" \
    -L"$PREFIX/lib" "${limd_flags[@]}" \
    -o "$PREFIX/bin/airbattery-mobile"
  write_stamp airbattery-mobile "$airbattery_mobile_fp"
fi

if component_cached wificonnection "$wificonnection_fp" "$PREFIX/bin/wificonnection"; then
  printf '%s\n' '==> wificonnection: cached'
else
  printf '%s\n' '==> Building wificonnection'
  "$CC" "${common_flags[@]}" \
    "$ROOT/tools/mobile/wificonnection.c" \
    -L"$PREFIX/lib" "${wifi_flags[@]}" \
    -o "$PREFIX/bin/wificonnection"
  write_stamp wificonnection "$wificonnection_fp"
fi

stage_stamp="$(stamp_path stage)"
if [[ -f "$stage_stamp" ]] &&
   [[ "$(cat "$stage_stamp")" == "$stage_fp" ]] &&
   [[ -f "$STAGE/MANIFEST.txt" ]] &&
   [[ -d "$STAGE/lib" ]] &&
   [[ -x "$STAGE/bin/airbattery-mobile" ]] &&
   [[ -x "$STAGE/bin/idevice_id" ]] &&
   [[ -x "$STAGE/bin/ideviceinfo" ]] &&
   [[ -x "$STAGE/bin/idevicesyslog" ]] &&
   [[ -x "$STAGE/bin/wificonnection" ]]; then
  set +e
  "$STAGE/bin/airbattery-mobile" >/dev/null 2>&1
  cached_helper_status=$?
  set -e
  if [[ "$cached_helper_status" -eq 2 ]]; then
    printf '==> Runtime staging: cached (%s)\n' "$ARCH"
    exit 0
  fi
  printf '%s\n' 'Cached staged runtime failed its loader check; restaging.'
fi

printf '%s\n' '==> Staging runtime'
rm -rf "$STAGE/bin" "$STAGE/lib" "$STAGE/licenses"
mkdir -p "$STAGE/bin" "$STAGE/lib" "$STAGE/licenses"

for tool in idevice_id ideviceinfo idevicesyslog airbattery-mobile wificonnection; do
  test -x "$PREFIX/bin/$tool" || {
    printf 'Expected built tool is missing: %s\n' "$tool" >&2
    exit 3
  }
  cp "$PREFIX/bin/$tool" "$STAGE/bin/$tool"
done

# Copy only the dylibs reachable from the staged executables. The shared build
# prefix may contain old versioned files after an upstream ABI bump; dependency
# closure staging prevents those stale files from entering the app bundle.
copy_prefix_dependencies() {
  local file="$1"
  local dep dest
  while IFS= read -r dep; do
    case "$dep" in
      "$PREFIX/lib/"*)
        dest="$STAGE/lib/$(basename "$dep")"
        if [[ ! -e "$dest" ]]; then
          cp -L "$dep" "$dest"
          runtime_dependency_added=1
        fi
        ;;
    esac
  done < <(otool -L "$file" | tail -n +2 | awk '{print $1}')
}

runtime_dependency_added=0
for file in "$STAGE"/bin/*; do
  copy_prefix_dependencies "$file"
done

while :; do
  runtime_dependency_added=0
  for file in "$STAGE"/lib/*; do
    [[ -f "$file" ]] || continue
    copy_prefix_dependencies "$file"
  done
  [[ "$runtime_dependency_added" -eq 0 ]] && break
done

relocate_macho() {
  local file="$1"
  local kind="$2"
  local dep new_dep

  if [[ "$kind" == "dylib" ]]; then
    install_name_tool -id "@rpath/$(basename "$file")" "$file" 2>/dev/null || true
    install_name_tool -add_rpath "@loader_path" "$file" 2>/dev/null || true
  else
    install_name_tool -add_rpath "@executable_path/../lib" "$file" 2>/dev/null || true
  fi

  while IFS= read -r dep; do
    case "$dep" in
      "$PREFIX/lib/"*)
        if [[ "$kind" == "dylib" ]]; then
          new_dep="@loader_path/$(basename "$dep")"
        else
          new_dep="@executable_path/../lib/$(basename "$dep")"
        fi
        install_name_tool -change "$dep" "$new_dep" "$file"
        ;;
    esac
  done < <(otool -L "$file" | tail -n +2 | awk '{print $1}')
}

for file in "$STAGE"/lib/*; do
  [[ -f "$file" ]] || continue
  if /usr/bin/file "$file" | grep -q 'Mach-O.*dynamically linked shared library'; then
    relocate_macho "$file" dylib
  fi
done
for file in "$STAGE"/bin/*; do
  [[ -f "$file" ]] || continue
  relocate_macho "$file" executable
done

printf '%s\n' '==> Verifying staged Mach-O linkage'
for file in "$STAGE"/bin/* "$STAGE"/lib/*; do
  [[ -f "$file" ]] || continue
  if otool -L "$file" | grep -F "$PREFIX/" >/dev/null; then
    printf 'Non-relocatable vendor linkage remains in %s:\n' "$file" >&2
    otool -L "$file" >&2
    exit 4
  fi
done

set +e
"$STAGE/bin/airbattery-mobile" >/dev/null 2>&1
helper_status=$?
set -e
if [[ "$helper_status" -ne 2 ]]; then
  printf 'Staged airbattery-mobile failed its loader smoke test (status %s).\n' "$helper_status" >&2
  exit 4
fi

printf '%s\n' '==> Ad-hoc signing staged native code'
for file in "$STAGE"/lib/* "$STAGE"/bin/*; do
  [[ -f "$file" ]] || continue
  if /usr/bin/file "$file" | grep -q 'Mach-O'; then
    codesign --force --sign - --timestamp=none "$file"
  fi
done

printf '%s\n' '==> Copying source-license notices'
for spec in \
  "libimobiledevice:third_party/libimobiledevice" \
  "libplist:third_party/libplist" \
  "libimobiledevice-glue:third_party/libimobiledevice-glue" \
  "libusbmuxd:third_party/libusbmuxd" \
  "libtatsu:third_party/libtatsu" \
  "openssl:third_party/openssl"; do
  name="${spec%%:*}"
  path="${spec#*:}"
  for license in COPYING LICENSE LICENSE.txt; do
    if [[ -f "$ROOT/$path/$license" ]]; then
      cp "$ROOT/$path/$license" "$STAGE/licenses/$name-$license"
      break
    fi
  done
done

{
  printf 'AirBattery generated mobile stack\n'
  printf 'architecture=%s\nmacos_min=%s\nsdk=%s\n' "$ARCH" "$MACOS_MIN" "$SDK_VERSION"
  printf 'openssl=%s\n' "$openssl_sha"
  printf 'libplist=%s\n' "$plist_sha"
  printf 'libimobiledevice-glue=%s\n' "$glue_sha"
  printf 'libusbmuxd=%s\n' "$usbmuxd_sha"
  printf 'libtatsu=%s\n' "$tatsu_sha"
  printf 'libimobiledevice=%s\n' "$limd_sha"
  printf 'fingerprint.openssl=%s\n' "$openssl_fp"
  printf 'fingerprint.libplist=%s\n' "$plist_fp"
  printf 'fingerprint.libimobiledevice-glue=%s\n' "$glue_fp"
  printf 'fingerprint.libusbmuxd=%s\n' "$usbmuxd_fp"
  printf 'fingerprint.libtatsu=%s\n' "$tatsu_fp"
  printf 'fingerprint.libimobiledevice=%s\n' "$limd_fp"
  printf 'fingerprint.airbattery-mobile=%s\n' "$airbattery_mobile_fp"
  printf 'fingerprint.wificonnection=%s\n' "$wificonnection_fp"
} > "$STAGE/MANIFEST.txt"

write_stamp stage "$stage_fp"
printf 'Mobile vendor stack staged at %s\n' "$STAGE"
