# Concept

## Guiding Principles

1. **Detect first**: No repair without a traceable finding.
2. **Risk gate**: Storage/PnP risks block aggressive automatic repair actions.
3. **Idempotence**: Repeated execution must not cause additional damage.
4. **Stateful escalation**: Repair history identifies repeat offenders.
5. **Small output, full local log**: Management output remains compact; details are stored locally as JSON/log files.

## Signals Collected

- DISM `/CheckHealth`
- optional DISM `/ScanHealth` in manual diagnostics
- SFC verify-only
- free space on the system drive
- pending reboot
- system events for Disk, Ntfs, StorPort, stornvme, and iaStor
- PhysicalDisk HealthStatus/OperationalStatus when provided by the device
- PnP ConfigManagerErrorCode
- storage/system drivers with provider, version, and date
- OS, build, model, and BIOS
- local repair history

## Decision Order

1. Script error
2. Storage critical
3. PnP/driver critical
4. Repeat offender
5. Component Store repairable
6. SFC finding
7. Pending reboot
8. Healthy

## Why No Automatic In-place Upgrade?

An in-place upgrade is a higher-risk escalation path and requires suitable media, compatibility validation, user communication, power supply, BitLocker/security alignment, and review of setup logs. The suite provides a gate and diagnostic data for this, but intentionally does not execute it without review.
