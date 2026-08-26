# PSADT package for local Windows image source repair

This sample package is intended for the rare cases where a local Windows image source is required, for example when `DISM /RestoreHealth` cannot resolve dependencies from Windows Update alone.

It is designed to be packaged with Microsoft PSAppDeployToolkit (PSADT) and distributed via SCCM or Intune as a Win32 application.

## Purpose

Use this only when the default online repair path is insufficient, for example:

- the device cannot reach or use Windows Update
- the local image source is already staged on the device or a network share
- the service team has explicitly approved a repair using a Windows image source

## Files

- `Deploy-Application.ps1` – PSADT-compatible entry point
- `Files/Invoke-WUHLocalImageRepair.ps1` – runs the local-source DISM repair with logging

## Required inputs

Set one of these values before execution:

- `-SourcePath` for a local source folder such as `C:\Sources\SXS` or a mounted ISO path
- `-ImagePath` for a WIM file path such as `D:\images\install.wim`
- `-UseUsbMedia` if the image is on removable media

## Typical command examples

```powershell
# local source folder
powershell.exe -ExecutionPolicy Bypass -File .\Files\Invoke-WUHLocalImageRepair.ps1 -SourcePath "C:\Sources\SXS"

# WIM file
powershell.exe -ExecutionPolicy Bypass -File .\Files\Invoke-WUHLocalImageRepair.ps1 -ImagePath "D:\Images\install.wim"
```

## Packaging guidance

1. Copy the folder as a PSADT package source.
2. Add the PSADT toolkit in the package root under `AppDeployToolkit`.
3. Build the package and deploy it via SCCM or Intune.
4. Use the package only in controlled maintenance windows.

## Safety notes

- Only use a valid Windows image that matches the target edition, architecture, and language.
- Do not point to an arbitrary local source.
- Prefer `Windows Update` and the online repair path by default.
- Keep the package out of production unless the team has validated the source and repair path.
