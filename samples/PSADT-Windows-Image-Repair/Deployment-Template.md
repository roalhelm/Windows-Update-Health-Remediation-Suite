# SCCM / Intune deployment template for local Windows image repair

This template is for the rare exception where Windows Update alone is not sufficient and a local Windows image source must be used for `DISM /RestoreHealth`.

## 1) Package structure

```text
PSADT-Windows-Image-Repair/
├── Deploy-Application.ps1
├── Files/
│   └── Invoke-WUHLocalImageRepair.ps1
├── AppDeployToolkit/
│   └── AppDeployToolkitMain.ps1
└── README.md
```

## 2) Example deployment parameters

Use one of the following parameter sets:

### Option A: local source folder

```powershell
-SourcePath "D:\Sources\SXS"
```

### Option B: WIM file

```powershell
-ImagePath "D:\Images\install.wim"
```

### Option C: mounted ISO / USB image

```powershell
-UseUsbMedia
```

### Option D: cleanup only

```powershell
-CleanupOnly
```

## 3) Example install command for Intune Win32 app

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Deploy-Application.ps1 -ImagePath "D:\Images\install.wim"
```

or

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Deploy-Application.ps1 -SourcePath "D:\Sources\SXS"
```

## 4) Example deployment command for SCCM package/program

```powershell
powershell.exe -ExecutionPolicy Bypass -File "C:\Program Files\Microsoft Configuration Manager\OSD\PackageSource\PSADT-Windows-Image-Repair\Deploy-Application.ps1" -SourcePath "D:\Sources\SXS"
```

or

```powershell
powershell.exe -ExecutionPolicy Bypass -File "C:\Program Files\Microsoft Configuration Manager\OSD\PackageSource\PSADT-Windows-Image-Repair\Deploy-Application.ps1" -ImagePath "D:\Images\install.wim"
```

## 5) Example source validation

Only use a source that matches the target device exactly:

- same Windows edition
- same architecture (x86 / x64 / ARM64)
- same language
- same patch level or compatible servicing baseline

## 6) Default recommendation

Use the online repair path by default and only switch to this package when:

- the machine cannot use Windows Update successfully
- a local source is required by the service team
- the image source has been validated and approved

## 7) Standard operational rule

This package should remain an exception, not the default. For normal remediation, the default configuration in the repository should be used without local sources.
