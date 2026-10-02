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
repositories under the dedicated Hrost provider root, builds the UI test and the
Hrost host before the timing-sensitive phase, then executes `AirBatteryHrost
fidelity` inside the test user's GUI bootstrap.

The production side is driven by XCUITest. The real AirBattery app entry point
recognizes the explicit `AIRBATTERY_HROST_XCUITEST=1` launch mode, validates the
fixture scenario and appearance, applies the same deterministic settings used by
AirBatteryHrost, and enters the production `SettingsWindowController` fixture
lifecycle without starting the live monitoring graph. XCUITest reaches the
settings window and calls `HrostXCUITestSession.checkpoint(...)`. The XCTest
sandbox writes only to its temporary relay queue; the provider-owned relay talks
to the stable Hrost acquisition broker, which owns canonical pixel, geometry,
Accessibility, and trace capture.

After the production reference is returned, the same `AirBatteryHrost fidelity`
process creates the Hrost-host candidate and performs the configured comparison.
The validator accepts the run only when the reference driver is
`hrost-xcuitest`, the comparison passes, reference/candidate roles are
`production-host`/`hrost-host`, their pairing keys match, required evidence is
available, no fixture process remains, and the broker is healthy afterward.

## What was reusable

The real integration needs the same provider mechanics that were proven by the
accepted synthetic Hrost smoke: execution of an already-built `.xctestrun`,
discovery of the XCTest sandbox relay, broker handoff, result publication, and
bounded Xcode/relay cleanup. That accepted logic was extracted into Hrost as
`scripts/hrost-xcuitest-provider`; this directory's `provider.sh` supplies only
AirBattery-specific paths and the selected test identifier.

The original synthetic provider is deliberately left unchanged as the P12
acceptance baseline. Migrating examples and additional hosts onto the extracted
runner is integration-polish work, not a prerequisite for proving the real-host
vertical slice.

The following remain host-specific and were intentionally not generalized:

- XcodeGen project construction and AirBattery resource staging;
- the deterministic AirBattery launch environment;
- the AirBattery fixture coordinate;
- preparation of the SwiftPM-built `AirBatteryHrost.app`;
- the choice to execute the entire fidelity run in the existing GUI-agent
  bootstrap.

Those differences are useful evidence for later integration design; P13 does
not introduce a generic abstraction for them.
