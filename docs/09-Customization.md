# Customization

## Thresholds

The Intune and remediation scripts use embedded defaults and do not require `config/HealthConfig.json` or any local repair source.

If you need to customize behavior, adjust the defaults in the script itself:

- LookbackDays
- MinimumFreeSpaceGB
- storage event IDs and thresholds
- DriverAgeWarningDays
- RepeatOffenderThreshold
- SFC/Component Cleanup/WU Reset

## Multi-Customer Operations

Recommended:

- a separate branch or customer-specific configuration
- no customer-specific values in shared code
- tag releases
- maintain a changelog per customer
- use signed artifacts instead of direct execution from the repository
