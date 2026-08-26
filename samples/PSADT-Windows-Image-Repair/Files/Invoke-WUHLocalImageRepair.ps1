[CmdletBinding()]
param(
    [string]$SourcePath,
    [string]$ImagePath,
    [switch]$UseUsbMedia,
    [switch]$CleanupOnly,
    [string]$LogPath = 'C:\ProgramData\WUHealthSuite\Logs\WUHealth-LocalRepair.log'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-WUHLocalLog {
    param(
        [string]$Message,
        [string]$Level = 'INFO'
    )

    $logDir = Split-Path -Parent $LogPath
    if (-not (Test-Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }

    $line = '{0} [{1}] {2}' -f (Get-Date -Format o), $Level, $Message
    Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8
}

function Get-WUHLocalSourceCommand {
    param(
        [string]$SourcePath,
        [string]$ImagePath,
        [switch]$UseUsbMedia
    )

    if ($CleanupOnly) {
        return @('/Online', '/Cleanup-Image', '/StartComponentCleanup')
    }

    if ($ImagePath) {
        $resolved = (Resolve-Path $ImagePath -ErrorAction Stop).Path
        return @('/Online', '/Cleanup-Image', '/RestoreHealth', "/Source:wim:$resolved:1", '/LimitAccess')
    }

    if ($SourcePath) {
        $resolved = (Resolve-Path $SourcePath -ErrorAction Stop).Path
        return @('/Online', '/Cleanup-Image', '/RestoreHealth', "/Source:$resolved", '/LimitAccess')
    }

    if ($UseUsbMedia) {
        $usbCandidates = @(
            'D:\', 'E:\', 'F:\', 'G:\', 'H:\'
        )
        foreach ($candidate in $usbCandidates) {
            if (Test-Path (Join-Path $candidate 'sources\install.wim')) {
                $resolved = (Resolve-Path (Join-Path $candidate 'sources\install.wim') -ErrorAction Stop).Path
                return @('/Online', '/Cleanup-Image', '/RestoreHealth', "/Source:wim:$resolved:1", '/LimitAccess')
            }
        }
    }

    throw 'No valid local repair source was provided. Supply -SourcePath or -ImagePath.'
}

Write-WUHLocalLog 'Starting local Windows image repair workflow.'

if ($CleanupOnly) {
    Write-WUHLocalLog 'Running component cleanup only.'
    & dism.exe @('/Online', '/Cleanup-Image', '/StartComponentCleanup')
    exit $LASTEXITCODE
}

$command = Get-WUHLocalSourceCommand -SourcePath $SourcePath -ImagePath $ImagePath -UseUsbMedia:$UseUsbMedia
Write-WUHLocalLog ('DISM command: dism.exe {0}' -f ($command -join ' '))

& dism.exe $command
$exitCode = $LASTEXITCODE
Write-WUHLocalLog ('DISM exit code: {0}' -f $exitCode)

if ($exitCode -ne 0) {
    throw "DISM repair failed with exit code $exitCode"
}

Write-WUHLocalLog 'Local repair completed successfully.'
exit 0
