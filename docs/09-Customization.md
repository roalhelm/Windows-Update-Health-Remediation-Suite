# Anpassung

## Schwellenwerte

`config/HealthConfig.json` enthält zentrale Beispiele. Vor Produktion anpassen:

- LookbackDays
- MinimumFreeSpaceGB
- Storage Event IDs und Schwellenwerte
- DriverAgeWarningDays
- RepeatOffenderThreshold
- Repair Source
- SFC/Component Cleanup/WU Reset

## Multi-Customer-Betrieb

Empfohlen:

- eigener Branch oder kundenspezifische Config
- keine kundenspezifischen Werte im gemeinsamen Code
- Releases taggen
- Changelog pro Kunde
- signierte Artefakte statt direkter Ausführung aus dem Repository
