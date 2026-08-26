# Repair Source

By default, DISM uses the configured Windows repair source. Optionally, a WIM or mounted Windows source can be used with `/Source`.

## Requirements

- same architecture
- matching edition and WIM index
- same system UI language
- compatible and maintained patch level
- reachable and protected path

## Example

```powershell
DISM.exe /Online /Cleanup-Image /RestoreHealth /Source:WIM:\server\repair\install.wim:6 /LimitAccess
```

The suite sets `/LimitAccess` only when an explicit source is configured.
