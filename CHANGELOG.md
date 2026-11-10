# Changelog

## 0.2.0

- Detection and remediation agree: every state that starts the Intune remediation has a remediation action.
  `UpdateIssue` and `PatchLevelBehind` trigger a Windows Update scan instead of ending as `Blocked`.
- Component store corruption ranks above the update states, so a corrupt device that is also behind gets repaired.
- Component store state comes from `Repair-WindowsImage -CheckHealth` (language independent); the text fallback no
  longer reads "No component store corruption detected" as corruption.
- SFC output is decoded correctly (UTF-16), so integrity violations are detected.
- Repair is postponed while component servicing waits for a restart.
- Failed updates count only when the installation failed or was aborted and did not succeed later.
- A stopped Windows Update service and pending updates on their own are no longer findings.
- Intune and SCCM scripts are generated from `src/common` with `build/Build-Scripts.ps1`; they are pure ASCII for
  Windows PowerShell 5.1.
- New logic and routing tests; `tests/Invoke-Tests.ps1` runs without Pester installed.

## 0.1.0

- Initiale Referenzimplementierung
- Gemeinsame Health Engine
- Intune Detection/Remediation
- SCCM Discovery/Remediation
- Storage-, Treiber-, Component-Store- und Repeat-Offender-Logik
- Dokumentation und Smoke Tests
