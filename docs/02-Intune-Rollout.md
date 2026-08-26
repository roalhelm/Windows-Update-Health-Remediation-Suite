# Intune-Rollout

## Paket

- Detection: `src/intune/Detect-WUHealth.ps1`
- Remediation: `src/intune/Remediate-WUHealth.ps1`

## Empfohlene Einstellungen

- Run using logged-on credentials: **No**
- Run in 64-bit PowerShell: **Yes**
- Signature check: gemäß Kundenstandard
- Schedule: Pilot täglich, Produktion nach Change- und Lastbewertung
- Assignment: Gerätegruppen, nicht Benutzergruppen

## Rolloutringe

1. Lab
2. IT Pilot
3. Fachbereichspilot
4. Broad
5. Kritische Systeme separat oder ausgeschlossen

## Monitoring

Die Detection schreibt eine kompakte JSON-Ausgabe. Vollständige Details liegen unter `C:\ProgramData\WUHealthSuite`. Exportiere den Device Status regelmäßig und analysiere Status, Modell, BIOS, Storage Provider und RepairCount.

## Wichtiger Hinweis

Remediation Scripts dürfen keinen Neustart erzwingen. `RebootRequired` wird lediglich gemeldet und muss über den etablierten Neustartprozess behandelt werden.
