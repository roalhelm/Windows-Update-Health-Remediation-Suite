# Konzept

## Leitprinzipien

1. **Detect first**: Keine Reparatur ohne nachvollziehbaren Befund.
2. **Risk gate**: Storage-/PnP-Risiken blockieren aggressive automatische Reparaturen.
3. **Idempotenz**: Wiederholte Ausführung darf keinen zusätzlichen Schaden erzeugen.
4. **Stateful escalation**: Reparaturhistorie identifiziert Wiederholungstäter.
5. **Small output, full local log**: Management-Ausgabe bleibt kompakt, Details liegen lokal als JSON/Log.

## Erhobene Signale

- DISM `/CheckHealth`
- optional DISM `/ScanHealth` in manueller Diagnose
- SFC Verify-Only
- freier Speicher auf Systemlaufwerk
- Pending Reboot
- System-Events für Disk, Ntfs, StorPort, stornvme und iaStor
- PhysicalDisk HealthStatus/OperationalStatus, soweit vom Gerät bereitgestellt
- PnP ConfigManagerErrorCode
- Storage-/Systemtreiber mit Provider, Version und Datum
- OS, Build, Modell, BIOS
- lokale Reparaturhistorie

## Entscheidungsreihenfolge

1. Scriptfehler
2. Storage kritisch
3. PnP-/Treiber kritisch
4. Repeat Offender
5. Component Store reparabel
6. SFC-Befund
7. Pending Reboot
8. Healthy

## Warum kein automatisches Inplace Upgrade?

Ein Inplace Upgrade ist eine Eskalationsstufe mit höherem Risiko und benötigt passende Medien, Kompatibilitätsprüfung, Benutzerkommunikation, Stromversorgung, BitLocker-/Security-Abstimmung und Auswertung der Setup-Logs. Die Suite liefert dafür ein Gate und Diagnosedaten, führt es aber bewusst nicht ungeprüft aus.
