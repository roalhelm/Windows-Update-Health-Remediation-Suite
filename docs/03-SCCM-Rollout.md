# SCCM / MECM Rollout

## Configuration Item

- Setting type: Script
- Data type: String
- Discovery: `src/sccm/Discovery-WUHealth.ps1`
- Expected value: `Healthy`
- Remediation: `src/sccm/Remediate-WUHealth.ps1`
- Enable 64-bit PowerShell

## Baseline

- Name: `CB-Windows-Update-Health`
- Deploy first to a pilot collection
- Automatic remediation only for `Repairable`
- Consider the Windows servicing model
- Use compliance status for collections, for example `Repeat Offender`, `Storage Review`, and `Driver Review`

## Alternative for Longer Repairs

DISM/SFC can take a long time to run. If the configuration baseline is operationally unsuitable for this, use discovery only for classification and deploy repair via a package, application, or task sequence with its own maximum runtime and maintenance window.
