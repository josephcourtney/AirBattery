# Native mobile-device vendoring

AirBattery talks to iPhone, iPad, and paired Apple Watch devices through a
small native runtime based on libimobiledevice.

The runtime is **built from pinned source**. Compiled executables and dynamic
libraries are generated artifacts and are not committed to this repository.

## Source inputs

The following Git submodules are pinned by the AirBattery superproject:

| Component | Pinned commit | Purpose |
| --- | --- | --- |
| libimobiledevice | `fa0f79190142bc309307967c058f89c1b36eb6b8` | Device, lockdown, battery, and companion-proxy protocols |
| libplist | `32428abacb909988e8e960a8845a6430b17b6a60` | Property-list representation |
| libimobiledevice-glue | `da770a7687f35fbb981db4d7b47b1b032cd5c2c7` | Shared transport/platform helpers |
| libusbmuxd | `93eb168bf6b07472d17781328c21df0c60300524` | USB/network device transport |
| libtatsu | `e7d6ad13ef928aa609d0ccdfc586f7d6e8e049bf` | TSS support required by current libimobiledevice |
| OpenSSL 3.5.8 | `f4dc4d58b48d346a8270183f89acf826d459b0ca` | TLS build input |

macOS's system libcurl is used by libtatsu. OpenSSL is built from the pinned
submodule as a static build input and linked into the generated
libimobiledevice runtime, so AirBattery does not redistribute separate
`libssl` or `libcrypto` dylibs.

The old AirBattery bundle was a set of checked-in native binaries built from
libimobiledevice commit `73b6fd1`. The old `comptest` executable was built
from Nikias Bassen's companion-proxy example gist. Both are retained here only
as provenance; neither prebuilt artifact is part of the current source tree.

## AirBattery-owned helper

`tools/mobile/airbattery-mobile.c` is the narrow process boundary between
Swift and companion-proxy operations.

Currently it exposes:

```text
airbattery-mobile companion-battery <parent-udid>
```

It prints JSON on stdout and diagnostics on stderr. Apple Watch companion
queries therefore remain outside the AirBattery process: a native-library
fault can terminate the helper without terminating the application.

`tools/mobile/wificonnection.c` is also AirBattery-owned source. It replaces
the formerly checked-in compiled `wificonnection` utility.

The standard `idevice_id`, `ideviceinfo`, and `idevicesyslog` tools are
built directly from the pinned upstream libimobiledevice source.

## Building

A normal local AirBattery build initializes and builds the vendor stack
automatically:

```bash
just build
```

For the vendor stack alone:

```bash
just vendor-mobile
```

The first build requires the native autotools toolchain. With Homebrew:

```bash
brew install autoconf automake libtool pkg-config
```

`scripts/build-mobile-stack.sh`:

1. verifies that every submodule is checked out at the commit recorded by the
   superproject;
2. materializes clean source copies under `.build/vendor/mobile` so the
   submodules are never modified by autotools;
3. builds the dependency stack for the host architecture and the AirBattery
   macOS deployment target;
4. builds the AirBattery-owned helpers;
5. rewrites Mach-O install names so the runtime is relocatable inside the app
   bundle;
6. verifies that no staged Mach-O still refers to the temporary build prefix
   and smoke-tests the helper through dyld;
7. ad-hoc signs each generated Mach-O object so Xcode can package and verify
   the native runtime before the later development-signing pass;
8. copies license notices and a generated manifest; and
9. stages the result under `AirBattery/libimobiledevice/`.

The script fingerprints its source inputs, helper sources, architecture, and
compiler. Re-running it is effectively a no-op while those inputs are
unchanged.

Generated paths are:

```text
AirBattery/libimobiledevice/
    bin/
        airbattery-mobile
        idevice_id
        ideviceinfo
        idevicesyslog
        wificonnection
    lib/
        *.dylib
    licenses/
    MANIFEST.txt
```

These paths are ignored by Git. Xcode's existing folder resource copies them
into the application bundle.

The staged runtime is ad-hoc signed first. Development signing later re-signs
the generated Mach-O files in `Contents/Resources/libimobiledevice` with the
selected Apple Development identity before signing the outer app.

For linkage and signature diagnostics:

```bash
just vendor-mobile-diagnose
```

## Updating a dependency

Do not point a submodule at a branch tip implicitly. Update deliberately:

```bash
git -C third_party/libimobiledevice fetch origin
git -C third_party/libimobiledevice checkout <reviewed-commit>
git add third_party/libimobiledevice
just vendor-mobile-clean
just vendor-mobile
just build
```

Then review the generated `MANIFEST.txt`, exercise iPhone/iPad network and
USB discovery, and specifically test Apple Watch companion queries before
committing the new gitlink.

The same procedure applies to the other submodules.

## Fault isolation

libimobiledevice is intentionally **not linked into the Swift application**.
AirBattery launches small child processes instead. This preserves a useful
failure boundary for native protocol code and makes abnormal termination
observable through `Process.terminationReason`.

The app serializes iDevice scans. Companion probing is rate-limited and is
disabled for the remainder of an AirBattery launch if `airbattery-mobile`
terminates from a signal.
