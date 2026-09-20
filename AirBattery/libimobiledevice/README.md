# Generated mobile-device runtime

This directory is populated by `scripts/build-mobile-stack.sh`.

Do not add compiled executables or dynamic libraries to source control here.
The runtime is built from the pinned source submodules in `third_party/` plus
AirBattery-owned helper sources in `tools/mobile/`.

Run:

```bash
git submodule update --init --recursive
just vendor-mobile
```

The generated `bin/`, `lib/`, `licenses/`, and `MANIFEST.txt` paths are
ignored by Git and copied into the application bundle by Xcode.
