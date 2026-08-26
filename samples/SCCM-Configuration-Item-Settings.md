# SCCM Configuration Item Beispiel

- Setting Name: `Windows Update Health State`
- Discovery Script: `src/sccm/Discovery-WUHealth.ps1`
- Data Type: String
- Rule: Equals `Healthy`
- Severity: Critical with event
- Remediation: `src/sccm/Remediate-WUHealth.ps1`
- Run scripts using 64-bit process: Yes
