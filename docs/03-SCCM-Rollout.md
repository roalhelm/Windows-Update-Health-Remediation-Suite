# SCCM-/MECM-Rollout

## Configuration Item

- Setting type: Script
- Data type: String
- Discovery: `src/sccm/Discovery-WUHealth.ps1`
- Expected value: `Healthy`
- Remediation: `src/sccm/Remediate-WUHealth.ps1`
- 64-Bit PowerShell aktivieren

## Baseline

- Name: `CB-Windows-Update-Health`
- Deployment zuerst an Pilot-Collection
- Automatic remediation nur für `Repairable`
- Service Windows beachten
- Compliance-Status für Collections nutzen, zum Beispiel `Repeat Offender`, `Storage Review`, `Driver Review`

## Alternative für längere Reparaturen

DISM/SFC können lange laufen. Wenn die Configuration Baseline dafür betrieblich ungeeignet ist, Discovery nur zur Klassifizierung verwenden und die Reparatur als Package/Application/Task Sequence mit eigener Max Runtime und Wartungsfenster verteilen.
