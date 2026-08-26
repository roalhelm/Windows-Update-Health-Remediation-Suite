# Customization

## Thresholds

`config/HealthConfig.json` contains central examples. Adjust them before production use:

- LookbackDays
- MinimumFreeSpaceGB
- storage event IDs and thresholds
- DriverAgeWarningDays
- RepeatOffenderThreshold
- Repair Source
- SFC/Component Cleanup/WU Reset

## Multi-Customer Operations

Recommended:

- a separate branch or customer-specific configuration
- no customer-specific values in shared code
- tag releases
- maintain a changelog per customer
- use signed artifacts instead of direct execution from the repository
