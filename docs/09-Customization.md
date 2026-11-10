# Customization

## Thresholds

The Intune and remediation scripts use embedded defaults and do not require `config/HealthConfig.json` or any local repair source.

If you need to customize behavior, adjust the defaults in `Get-WUHDefaultConfig` in `src/common/WUHealth.Common.ps1` and run `build/Build-Scripts.ps1`. The Intune and SCCM scripts are generated; do not edit them by hand.

- LookbackDays
- MinimumFreeSpaceGB
- storage event IDs and thresholds
- DriverAgeWarningDays
- RepeatOffenderThreshold
- SFC/Component Cleanup/WU Reset
- CheckWindowsUpdate, TriggerUpdateScan, MinimumSupportedBuild, PatchStaleDays

## Multi-Customer Operations

Recommended:

- a separate branch or customer-specific configuration
- no customer-specific values in shared code
- tag releases
- maintain a changelog per customer
- use signed artifacts instead of direct execution from the repository
