#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_ROOT="$ROOT/.build/vendor/mobile"
WORK_ROOT="$BUILD_ROOT/work"
PREFIX="$BUILD_ROOT/prefix"
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

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'Missing required command: %s\n' "$1" >&2
    exit 2
  }
}

# Xcode shell phases do not reliably inherit the interactive shell PATH.
# Import Homebrew's environment explicitly when it is installed.
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

for command in git make perl pkg-config autoconf automake autoreconf xcrun otool install_name_tool shasum codesign; do
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
  printf '%s\n'     'GNU libtool is required to build the mobile stack.'     'Install it with: brew install libtool' >&2
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
export CC
export SDKROOT
export MACOSX_DEPLOYMENT_TARGET="$MACOS_MIN"
export CFLAGS="-arch $ARCH -isysroot $SDKROOT -mmacosx-version-min=$MACOS_MIN -O2"
export CPPFLAGS="-I$PREFIX/include -isysroot $SDKROOT"
export LDFLAGS="-arch $ARCH -isysroot $SDKROOT -mmacosx-version-min=$MACOS_MIN -L$PREFIX/lib"
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PREFIX/share/pkgconfig"
export PATH="$PREFIX/bin:$PATH"

fingerprint="$(
  {
    printf 'arch=%s\nmacos_min=%s\ncc=%s\n' "$ARCH" "$MACOS_MIN" "$("$CC" --version | head -n 1)"
    shasum -a 256 "$0" "$ROOT/tools/mobile/airbattery-mobile.c" "$ROOT/tools/mobile/wificonnection.c"
    for path in "${SUBMODULES[@]}"; do
      printf '%s=%s\n' "$path" "$(git -C "$ROOT/$path" rev-parse HEAD)"
    done
  } | shasum -a 256 | awk '{print $1}'
)"
stamp="$BUILD_ROOT/stamp-$ARCH"
if [[ -f "$stamp" ]] &&
   [[ "$(cat "$stamp")" == "$fingerprint" ]] &&
   [[ -x "$STAGE/bin/airbattery-mobile" ]] &&
   [[ -x "$STAGE/bin/idevice_id" ]] &&
   [[ -x "$STAGE/bin/ideviceinfo" ]] &&
   [[ -x "$STAGE/bin/idevicesyslog" ]] &&
   [[ -x "$STAGE/bin/wificonnection" ]]; then
  printf 'Mobile vendor stack is current (%s).\n' "$ARCH"
  exit 0
fi

rm -rf "$WORK_ROOT" "$PREFIX"
mkdir -p "$WORK_ROOT" "$PREFIX" "$STAGE/bin" "$STAGE/lib" "$STAGE/licenses"
rm -rf "$STAGE/bin" "$STAGE/lib" "$STAGE/licenses"
mkdir -p "$STAGE/bin" "$STAGE/lib" "$STAGE/licenses"

materialize() {
  local name="$1"
  local path="$2"
  local dst="$WORK_ROOT/src/$name"
  rm -rf "$dst"
  mkdir -p "$dst"
  git -C "$ROOT/$path" archive --format=tar HEAD | tar -xf - -C "$dst"
  # Upstream git-version-gen scripts need either a .git directory or a
  # tarball version marker. The build copy intentionally has no .git metadata.
  git -C "$ROOT/$path" describe --tags --always > "$dst/.tarball-version"
  printf '%s\n' "$dst"
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

  (
    cd "$src"
    ./Configure "$target"       --prefix="$PREFIX"       --openssldir="$PREFIX/ssl"       no-shared no-tests no-docs       "-mmacosx-version-min=$MACOS_MIN"
    make -j"$JOBS"
    make install_sw
  )
}

build_autotools() {
  local name="$1"
  local src="$2"
  shift 2
  local build="$WORK_ROOT/build/$name"

  (
    cd "$src"
    autoreconf -fi
  )
  rm -rf "$build"
  mkdir -p "$build"
  (
    cd "$build"
    "$src/configure"       --prefix="$PREFIX"       --enable-shared       --disable-static       "$@"
    make -j"$JOBS"
    make install
  )
}

printf '%s\n' '==> Building OpenSSL (static build input)'
openssl_src="$(materialize openssl third_party/openssl)"
configure_openssl "$openssl_src"

printf '%s\n' '==> Building libplist'
plist_src="$(materialize libplist third_party/libplist)"
build_autotools libplist "$plist_src" --without-cython --without-tools --without-tests

printf '%s\n' '==> Building libimobiledevice-glue'
glue_src="$(materialize libimobiledevice-glue third_party/libimobiledevice-glue)"
build_autotools libimobiledevice-glue "$glue_src"

printf '%s\n' '==> Building libusbmuxd'
usbmuxd_src="$(materialize libusbmuxd third_party/libusbmuxd)"
build_autotools libusbmuxd "$usbmuxd_src"

printf '%s\n' '==> Building libtatsu'
tatsu_src="$(materialize libtatsu third_party/libtatsu)"
# macOS supplies libcurl as a system library. Supplying the pkg-config override
# keeps curl out of AirBattery's redistributed native dependency set.
export libcurl_CFLAGS=""
export libcurl_LIBS="-lcurl"
build_autotools libtatsu "$tatsu_src"
unset libcurl_CFLAGS libcurl_LIBS

printf '%s\n' '==> Building libimobiledevice'
limd_src="$(materialize libimobiledevice third_party/libimobiledevice)"
build_autotools libimobiledevice "$limd_src" --without-cython --with-openssl

printf '%s\n' '==> Building AirBattery-owned mobile helpers'
common_flags=(
  -arch "$ARCH"
  -isysroot "$SDKROOT"
  "-mmacosx-version-min=$MACOS_MIN"
  -O2
  -I"$PREFIX/include"
)
read -r -a limd_flags <<<"$(PKG_CONFIG_PATH="$PKG_CONFIG_PATH" pkg-config --libs libimobiledevice-1.0 libplist-2.0)"
read -r -a wifi_flags <<<"$(PKG_CONFIG_PATH="$PKG_CONFIG_PATH" pkg-config --libs libimobiledevice-1.0 libusbmuxd-2.0 libplist-2.0)"

"$CC" "${common_flags[@]}"   "$ROOT/tools/mobile/airbattery-mobile.c"   -L"$PREFIX/lib" "${limd_flags[@]}"   -o "$PREFIX/bin/airbattery-mobile"

"$CC" "${common_flags[@]}"   -DPACKAGE_VERSION='\"AirBattery\"'   "$ROOT/tools/mobile/wificonnection.c"   -L"$PREFIX/lib" "${wifi_flags[@]}"   -o "$PREFIX/bin/wificonnection"

printf '%s\n' '==> Staging runtime tools'
for tool in idevice_id ideviceinfo idevicesyslog airbattery-mobile wificonnection; do
  test -x "$PREFIX/bin/$tool" || {
    printf 'Expected built tool is missing: %s\n' "$tool" >&2
    exit 3
  }
  cp "$PREFIX/bin/$tool" "$STAGE/bin/$tool"
done

# Redistribute only dylibs required by the staged executables, not the static
# OpenSSL build inputs or development archives.
for dylib in "$PREFIX"/lib/*.dylib "$PREFIX"/lib/*.dylib.*; do
  [[ -e "$dylib" ]] || continue
  cp -P "$dylib" "$STAGE/lib/"
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
    [[ "$dep" == "$PREFIX/lib/"* ]] || continue
    if [[ "$kind" == "dylib" ]]; then
      new_dep="@loader_path/$(basename "$dep")"
    else
      new_dep="@executable_path/../lib/$(basename "$dep")"
    fi
    install_name_tool -change "$dep" "$new_dep" "$file"
  done < <(otool -L "$file" | tail -n +2 | awk '{print $1}')
}

for file in "$STAGE"/lib/*; do
  [[ -f "$file" && ! -L "$file" ]] || continue
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
  [[ -f "$file" && ! -L "$file" ]] || continue
  if otool -L "$file" | grep -F "$PREFIX/" >/dev/null; then
    printf 'Non-relocatable vendor linkage remains in %s:\n' "$file" >&2
    otool -L "$file" >&2
    exit 4
  fi
done

# A no-argument invocation exits with usage status 2. Reaching main proves that
# dyld can resolve the staged helper and its private dylibs.
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
  [[ -f "$file" && ! -L "$file" ]] || continue
  if /usr/bin/file "$file" | grep -q 'Mach-O'; then
    codesign --force --sign - --timestamp=none "$file"
  fi
done

printf '%s\n' '==> Copying source-license notices'
for spec in   "libimobiledevice:third_party/libimobiledevice"   "libplist:third_party/libplist"   "libimobiledevice-glue:third_party/libimobiledevice-glue"   "libusbmuxd:third_party/libusbmuxd"   "libtatsu:third_party/libtatsu"   "openssl:third_party/openssl"; do
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
  printf 'architecture=%s\nmacos_min=%s\n' "$ARCH" "$MACOS_MIN"
  for path in "${SUBMODULES[@]}"; do
    printf '%s=%s\n' "$path" "$(git -C "$ROOT/$path" rev-parse HEAD)"
  done
} > "$STAGE/MANIFEST.txt"

mkdir -p "$BUILD_ROOT"
printf '%s\n' "$fingerprint" > "$stamp"
printf 'Mobile vendor stack staged at %s\n' "$STAGE"
