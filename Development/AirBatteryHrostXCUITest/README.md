# AirBattery Hrost XCUITest vertical slice

This directory contains the first real-application integration of Hrost's
controlled XCUITest reference-acquisition path.

The acceptance coordinate is deliberately narrow:

```text
display-settings / airpods / default / light
```

Run it from the AirBattery checkout with Hrost available at `../hrost` (or set
`HROST_PATH`):

```bash
bash Development/AirBatteryHrostXCUITest/validate.sh \
  --user testymctestface
```

The validator does not launch native UI in the invoking account. It stages both
repositories under the dedicated Hrost provider root and builds the UI test and
Hrost host before the timing-sensitive phase.

The production side is driven by XCUITest. The real AirBattery app entry point
recognizes the explicit `AIRBATTERY_HROST_XCUITEST=1` launch mode, validates the
fixture scenario and appearance, applies the same deterministic settings used by
AirBatteryHrost, and enters the production `SettingsWindowController` fixture
lifecycle without starting the live monitoring graph. XCUITest reaches the
settings window and calls `HrostXCUITestSession.checkpoint(...)`. The XCTest
sandbox writes only to its temporary relay queue; the provider-owned relay talks
to the stable Hrost acquisition broker, which owns canonical pixel, geometry,
Accessibility, and trace capture.

The Hrost-host candidate is acquired separately through
`hrost-screen-share-capture-app`, which launches `AirBatteryHrost.app` through
LaunchServices in the same dedicated GUI session. Comparison itself is non-UI
and runs after both archives exist. This split is intentional: GUI-bearing
AppKit processes must enter the authoritative session through normal
LaunchServices/session machinery rather than direct execution through
`sudo launchctl bsexec`.

The P13 profile treats geometry and pixels as exact failure gates. Accessibility
must be present, but a cross-host semantic mismatch is informational rather than
a P13 failure because the production reference is observed externally through
AX while the Hrost-host candidate currently records its in-process
`NSAccessibility` hierarchy. Those are different evidence channels even when
they describe the same visible UI. The mismatch remains in the comparison
report; later fidelity work can add a normalized external-AX candidate channel
if accessibility parity needs to become a blocking dimension. View-tree
mismatch is likewise informational.

The validator accepts the run only when the reference driver is
`hrost-xcuitest`, the comparison profile does not evaluate to failure,
reference/candidate roles are `production-host`/`hrost-host`, both archives
identify AirBattery, their pairing keys match, required production-reference
evidence is available, no fixture process remains, and the broker is healthy
afterward.

## What was reusable

The real integration needs the same provider mechanics that were proven by the
accepted synthetic Hrost smoke: execution of an already-built `.xctestrun`,
discovery of the XCTest sandbox relay, broker handoff, result publication, and
bounded Xcode/relay cleanup. That accepted logic was extracted into Hrost as
`scripts/hrost-xcuitest-provider`; this directory's `provider.sh` supplies only
AirBattery-specific paths and the selected test identifier.

The controlled reference probe now accepts application and variant identity so
real-host references are not forced through the synthetic smoke's `Example`
identity.

The original synthetic provider is deliberately left unchanged as the P12
acceptance baseline. Migrating examples and additional hosts onto the extracted
runner is integration-polish work, not a prerequisite for proving the real-host
vertical slice.

The following remain host-specific and were intentionally not generalized:

- XcodeGen project construction and AirBattery resource staging;
- the deterministic AirBattery launch environment;
- the AirBattery fixture coordinate;
- preparation of the SwiftPM-built `AirBatteryHrost.app`.

Those differences are useful evidence for later integration design; P13 does
not introduce a generic abstraction for them.
