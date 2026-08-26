# Inplace Upgrade als Eskalation

## Gate

Nur erwägen, wenn:

- Storage-/Hardware-Risiken bewertet sind
- ausreichend freier Speicher vorhanden ist
- Medien zu Architektur, Edition und Sprache passen
- Kompatibilität geprüft wurde
- BitLocker, EDR, VPN und kritische Apps bewertet sind
- Backup/OneDrive-Status und Benutzerkommunikation geklärt sind

## Beispiel, nicht automatisch aktiviert

```cmd
setup.exe /auto upgrade /quiet /eula accept /dynamicupdate enable
```

Windows Setup muss anhand der SetupDiag-/Panther-Logs überwacht werden. Ein erneut auffälliger Client wird nicht endlos mit Inplace Upgrades behandelt, sondern als Repeat Offender eskaliert.
