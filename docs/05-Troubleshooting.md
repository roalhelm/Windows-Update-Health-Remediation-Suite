# Troubleshooting

## Local Diagnosis

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\src\tools\Invoke-WUHealthDiagnostic.ps1
```

## Logs

- Suite: `C:\ProgramData\WUHealthSuite\Logs`
- State: `C:\ProgramData\WUHealthSuite\State.json`
- CBS: `C:\Windows\Logs\CBS\CBS.log`
- DISM: `C:\Windows\Logs\DISM\dism.log`
- Intune IME: `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs`
- SCCM DCM: `C:\Windows\CCM\Logs\DCMAgent.log`, `CIAgent.log`, `DiscoveryDataManager.log`

## Common Cases

### DISM 0x800f081f
The repair source is missing or does not match. Check edition, architecture, language, and patch level.

### Detection does not run in Intune
Check IME, assignment, license, 64-bit setting, encoding, and HealthScripts logs.

### SCCM remains Unknown
Check baseline evaluation, client policy, DCM agent logs, and script timeout.

### Many Event 129/153 entries
Do not mask this by repeatedly running DISM. Check the storage controller, NVMe/IRST drivers, firmware, BIOS, cables/backplane, and OEM diagnostics.
