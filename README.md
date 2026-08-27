# Windows Update Health Remediation Suite

Automated detection, repair, and escalation of recurring Windows update issues for **Microsoft Intune** and **Microsoft Configuration Manager (SCCM/MECM)**.

> Status: Reference implementation. Always test customer-specific settings in production, sign the scripts, follow the change process, and use pilot groups before broad rollout.

## Objective

The suite does not treat a damaged component store in isolation; it also evaluates storage, file system, driver, firmware, free-space, repeat-failure indicators, and Windows Update health. Critical storage or device issues are intentionally **not automatically repaired** and are escalated for root-cause analysis.

The detection now also checks whether the client has Windows Update problems and whether it is behind the current patch level. It reports the current Windows build/version, UBR, pending updates, service status, update errors, and the last successful patch installation time so that Intune or SCCM can distinguish between a healthy client, a patch-level issue, and an actual Windows Update service fault.

## Architecture

```mermaid
flowchart LR
  I[Intune Remediations] --> D[Detect-WUHealth]
  S[SCCM Compliance Baseline] --> D
  D --> H{Health State}
  H -->|Healthy| M[Monitor]
  H -->|Repairable| R[Repair-WUHealth]
  H -->|Storage/Driver Risk| E[Escalate]
  R --> V[Re-detect]
  V -->|Healthy| M
  V -->|Repeated| E
```

## Directory Structure

- `src/common`: shared health, logging, and repair engine
- `src/intune`: standalone detection and remediation for Intune (with common engine embedded)
- `src/sccm`: standalone discovery and remediation for configuration baselines (with common engine embedded)
- `src/tools`: local diagnostics and installation helpers
- `config`: configurable thresholds
- `docs`: architecture, rollout, operations, troubleshooting, and support guidance
- `tests`: Pester smoke tests

## Quick Start

### Intune

1. No separate `config/HealthConfig.json` is required; the Intune scripts ship with embedded defaults and no local repair-source requirement.
2. Upload `src/intune/Detect-WUHealth.ps1` as a detection script.
3. Upload `src/intune/Remediate-WUHealth.ps1` as a remediation script.
4. Run as **SYSTEM** in **64-bit PowerShell** first, without automatic restarts.
5. Use a pilot group and monitor the output in **Devices > Manage devices > Scripts and remediations**.

### SCCM / MECM

1. Create a Windows desktop/server configuration item.
2. Use `src/sccm/Discovery-WUHealth.ps1` as the discovery script with data type `String`.
3. Compliance rule: the return value must be `Healthy`.
4. Store `src/sccm/Remediate-WUHealth.ps1` as the remediation script.
5. Create a configuration baseline, assign it to a pilot collection, and activate automatic remediation only during the maintenance window initially.

## Safety Boundaries

- No automatic `chkdsk /f`, no firmware flashing, no driver replacement, no in-place upgrade.
- No automatic restart caused by Intune remediations.
- Storage events, PnP errors, and repeated corruption are escalated.
- Repairs use the online Windows Update path only; no local DISM source or mounted ISO/media is required.

## Result States

| State | Meaning | Action |
|---|---|---|
| `Healthy` | No relevant findings | Monitor |
| `Repairable` | Component Store or system files are suspicious | DISM/SFC |
| `RebootRequired` | Repair or servicing requires a restart | Maintenance process |
| `PatchLevelBehind` | Build or patch age is below the supported baseline or updates are stale | Patch validation / Windows Update sync |
| `UpdateIssue` | Windows Update query detected failed updates or update service issues | Update troubleshooting |
| `EscalateStorage` | Storage/file-system indicators | Hardware/OEM analysis |
| `EscalateDriver` | PnP/critical driver issue | Driver/firmware review |
| `RepeatOffender` | Threshold of repeated repairs reached | Root-cause analysis / rebuild decision |
| `Error` | Validation logic could not be executed completely | Script/client analysis |

### Windows Update checks

The detection queries the local Windows Update agent and captures the following information as part of the health signal set:

- `WindowsUpdate.Status` - overall update health state
- `WindowsUpdate.CurrentBuild` - current OS build
- `WindowsUpdate.CurrentVersion` - OS version
- `WindowsUpdate.UBR` - update build revision
- `WindowsUpdate.PendingUpdates` - number of available but not installed updates
- `WindowsUpdate.ServiceStatus` - state of the Windows Update service
- `WindowsUpdate.AutomaticUpdateEnabled` - whether automatic updates are enabled
- `WindowsUpdate.LastError` - last Windows Update error code
- `WindowsUpdate.LastScanTime` - last scan timestamp
- `WindowsUpdate.LastInstallationTime` - last patch installation time
- `WindowsUpdate.FailedUpdates` - failed update entries from the agent history

The detection treats a client as stale or out-of-policy when one of the following is true:

- current build is below the configured minimum supported build
- last patch installation is older than the configured stale threshold
- there are pending updates waiting to be installed
- the Windows Update service is not running
- the Update agent has a non-zero error code or failed update history

This makes the suite useful for both serviceability health and operational patch compliance review.

## Documentation

- [Concept](docs/01-Concept.md)
- [Intune Rollout](docs/02-Intune-Rollout.md)
- [SCCM Rollout](docs/03-SCCM-Rollout.md)
- [Operating Model](docs/04-Operating-Model.md)
- [Troubleshooting](docs/05-Troubleshooting.md)
- [Repair Source](docs/07-Repair-Source.md)
- [In-place Upgrade Escalation](docs/08-Inplace-Upgrade.md)
- [Customization](docs/09-Customization.md)

## Disclaimer

The scripts are a configurable reference implementation. DISM, SFC, Windows Update reset, driver and storage diagnostics must be validated in the target customer environment with security products, maintenance windows, and operational procedures.
