# Betriebsmodell

## Rollen

- Endpoint Engineering: Code, Konfiguration, Ringdesign
- Service Desk: Status lesen, Logbundle einsammeln, Standardeskalation
- Workplace Operations: Pilot, Deployment, Reporting
- Hardware/OEM Team: Storage-, BIOS- und Firmwarebefunde
- Security: Script Signing, AV/EDR-Ausnahmen nur nach Prüfung

## KPIs

- Healthy / Repairable / Escalated pro Ring
- Remediation Success Rate
- Repeat Offender Rate
- Befunde nach Hersteller, Modell, BIOS, Storage-/Treiberprovider
- Zeit seit letzter erfolgreicher Updateinstallation

## Eskalation

- Storage Event 55/98/129/153/157: Diagnose, Backupstatus, OEM-Test
- PnP-Fehler: betroffenes Gerät und Treiberpaket identifizieren
- RepairCount >= Schwellwert: kein weiterer Blind-Repair
- DISM unreparierbar: geeignete Repair Source oder kontrolliertes Inplace Upgrade
