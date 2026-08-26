# Intune Rollout

## Package

- Detection: `src/intune/Detect-WUHealth.ps1`
- Remediation: `src/intune/Remediate-WUHealth.ps1`

## Recommended Settings

- Run using logged-on credentials: **No**
- Run in 64-bit PowerShell: **Yes**
- Signature check: according to customer standard
- Schedule: pilot daily, production after change and load assessment
- Assignment: device groups, not user groups

## Rollout Rings

1. Lab
2. IT pilot
3. Business-unit pilot
4. Broad
5. Critical systems separate or excluded

## Monitoring

The detection script writes a compact JSON output. Full details are stored under `C:\ProgramData\WUHealthSuite`. Export the device status regularly and analyze status, model, BIOS, storage provider, and RepairCount.

## Important Note

Remediation scripts must not trigger a restart. `RebootRequired` is only reported and must be handled through the established reboot process.
