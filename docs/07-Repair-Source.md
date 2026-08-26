# Repair Source

Standardmäßig verwendet DISM die konfigurierte Windows-Reparaturquelle. Optional kann eine WIM- oder gemountete Windows-Quelle mit `/Source` verwendet werden.

## Anforderungen

- gleiche Architektur
- passende Edition und WIM-Index
- gleiche System-UI-Sprache
- kompatibler bzw. gepflegter Patchstand
- erreichbarer, geschützter Pfad

## Beispiel

```powershell
DISM.exe /Online /Cleanup-Image /RestoreHealth /Source:WIM:\serverepair\install.wim:6 /LimitAccess
```

Die Suite setzt `/LimitAccess` nur, wenn eine explizite Quelle konfiguriert ist.
