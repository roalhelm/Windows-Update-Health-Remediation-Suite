# Troubleshooting

## Lokale Diagnose

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\src	ools\Invoke-WUHealthDiagnostic.ps1
```

## Logs

- Suite: `C:\ProgramData\WUHealthSuite\Logs`
- State: `C:\ProgramData\WUHealthSuite\State.json`
- CBS: `C:\Windows\Logs\CBS\CBS.log`
- DISM: `C:\Windows\Logs\DISM\dism.log`
- Intune IME: `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs`
- SCCM DCM: `C:\Windows\CCM\Logs\DCMAgent.log`, `CIAgent.log`, `DiscoveryDataManager.log`

## Häufige Fälle

### DISM 0x800f081f
Repair Source fehlt oder passt nicht. Edition, Architektur, Sprache und Patchstand prüfen.

### Detection läuft in Intune nicht
IME, Assignment, Lizenz, 64-Bit-Einstellung, Encoding und HealthScripts-Logs prüfen.

### SCCM bleibt Unknown
Baseline-Evaluation, Client Policy, DCM-Agent-Logs und Script Timeout prüfen.

### Viele Event 129/153
Nicht mit wiederholtem DISM überdecken. Storage Controller, NVMe/IRST-Treiber, Firmware, BIOS, Kabel/Backplane und OEM-Diagnose prüfen.
