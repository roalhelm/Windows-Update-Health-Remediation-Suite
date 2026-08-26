[CmdletBinding()]
param(
    [string]$SourcePath,
    [string]$ImagePath,
    [switch]$UseUsbMedia,
    [switch]$CleanupOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$helper = Join-Path $scriptRoot 'Files\Invoke-WUHLocalImageRepair.ps1'
$toolkitMain = Join-Path $scriptRoot 'AppDeployToolkit\AppDeployToolkitMain.ps1'

if (-not (Test-Path $helper)) {
    throw "Missing helper script: $helper"
}

if (Test-Path $toolkitMain) {
    . $toolkitMain
    Initialize-Application
    Write-Log -Message 'Starting PSADT package for local image-based repair.' -Level Info

    if (-not $SourcePath -and -not $ImagePath) {
        $SourcePath = Get-ADTConfigValue -Key 'SourcePath'
        $ImagePath = Get-ADTConfigValue -Key 'ImagePath'
    }

    if ($CleanupOnly) {
        & $helper -CleanupOnly
        exit $LASTEXITCODE
    }

    & $helper -SourcePath $SourcePath -ImagePath $ImagePath -UseUsbMedia:$UseUsbMedia
    exit $LASTEXITCODE
}

# Fallback for standalone execution without PSADT toolkit
if (-not $SourcePath -and -not $ImagePath) {
    throw 'Provide either -SourcePath or -ImagePath. The PSADT toolkit folder is not present, so no config values are available.'
}

& $helper -SourcePath $SourcePath -ImagePath $ImagePath -UseUsbMedia:$UseUsbMedia
exit $LASTEXITCODE
