<#
.SYNOPSIS
    Generates the self-contained Intune and SCCM scripts from src/common/WUHealth.Common.ps1.

.DESCRIPTION
    Intune and Configuration Manager upload single files, so the health engine has to be embedded in each script.
    To keep the copies identical, they are generated here. Edit src/common/WUHealth.Common.ps1 (engine) or the
    tails below (entry points), then run this script. Never edit the generated files by hand.

    -Check only verifies that the generated scripts are up to date (exit code 1 if not).

.EXAMPLE
    pwsh ./build/Build-Scripts.ps1
    pwsh ./build/Build-Scripts.ps1 -Check
#>
[CmdletBinding()]
param([switch]$Check)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$common = (Get-Content -LiteralPath (Join-Path $root 'src/common/WUHealth.Common.ps1') -Raw) -replace "`r`n", "`n"

$header = @'
# ---------------------------------------------------------------------------------------------
# GENERATED FILE - do not edit. Source: src/common/WUHealth.Common.ps1 + build/Build-Scripts.ps1
# Regenerate with: pwsh ./build/Build-Scripts.ps1
# ---------------------------------------------------------------------------------------------
'@

$tails = [ordered]@{}

$tails['src/intune/Detect-WUHealth.ps1'] = @'
# Intune detection: exit 1 starts the remediation script, exit 0 does not.
# Only states the remediation can act on return 1. Escalation states are reported in the output only.
$config=Get-WUHDefaultConfig
$config.LogRoot='C:\ProgramData\Microsoft\IntuneManagementExtension\Logs'
try {
  $result=Get-WUHHealth $config
  $wu=$result.Signals.WindowsUpdate
  $compact=[ordered]@{
    Status=$result.Status;
    ComponentStore=$result.Signals.ComponentStoreState;
    SFCViolation=$result.Signals.SFCViolation;
    PendingReboot=$result.Signals.PendingReboot;
    FreeGB=$result.Signals.FreeSpaceGB;
    DiskEvents=$result.Signals.StorageEventCount;
    PnPErrors=@($result.Signals.PnPErrors).Count;
    RepairCount=$result.Signals.RepairCount;
    UpdateStatus=$wu.Status;
    PatchLevelBehind=$wu.PatchLevelBehind;
    CurrentBuild=$wu.CurrentBuild;
    UBR=$wu.UBR;
    PendingUpdates=$wu.PendingUpdates;
    FailedUpdates=@($wu.FailedUpdates).Count;
    LastInstallationTime=$wu.LastInstallationTime;
    Model=$result.Model
  } | ConvertTo-Json -Compress
  Write-Output $compact
  if($result.Status -in @('Repairable','UpdateIssue','PatchLevelBehind')){exit 1}else{exit 0}
} catch { Write-Output ("Error: "+$_.Exception.Message); exit 1 }
'@

$tails['src/intune/Remediate-WUHealth.ps1'] = @'
# Intune remediation: exit 0 when the action for the detected state was carried out, exit 1 otherwise.
$config=Get-WUHDefaultConfig
$config.LogRoot='C:\ProgramData\Microsoft\IntuneManagementExtension\Logs'
try {
  $r=Invoke-WUHRepair $config
  Write-Output ($r|ConvertTo-Json -Compress)
  if($r.Status -in @('Healthy','RebootRequired','UpdateScanTriggered','UpdateActionTaken')){exit 0}else{exit 1}
} catch { Write-Output ("Error: "+$_.Exception.Message); exit 1 }
'@

$tails['src/sccm/Discovery-WUHealth.ps1'] = @'
# Configuration Manager discovery: returns the state as a string. Compliance rule: value equals "Healthy".
# Patch compliance is owned by software updates in Configuration Manager, so the Windows Update check is off here.
$config=Get-WUHDefaultConfig
$config.CheckWindowsUpdate=$false
try { (Get-WUHHealth $config).Status } catch { 'Error' }
'@

$tails['src/sccm/Remediate-WUHealth.ps1'] = @'
# Configuration Manager remediation: repairs the component store when the state is "Repairable".
$config=Get-WUHDefaultConfig
$config.CheckWindowsUpdate=$false
$r=Invoke-WUHRepair $config
$r.Status
'@

$utf8 = New-Object System.Text.UTF8Encoding($false)
$stale = @()

foreach ($relative in $tails.Keys) {
    $content = ($header.TrimEnd() + "`n" + $common.TrimEnd() + "`n`n" + $tails[$relative].TrimEnd() + "`n") -replace "`r`n", "`n"
    if ($content -match '[^\x00-\x7F]') { throw "$relative would contain non-ASCII characters. Windows PowerShell 5.1 misreads them in files without BOM." }
    $path = Join-Path $root $relative
    $current = if (Test-Path -LiteralPath $path) { (Get-Content -LiteralPath $path -Raw) -replace "`r`n", "`n" } else { '' }
    if ($current -ne $content) {
        if ($Check) { $stale += $relative } else { [IO.File]::WriteAllText($path, $content, $utf8); Write-Host "Generated $relative" }
    }
}

# manifest.json: SHA-256 of every repository file except the manifest itself.
# Not part of -Check: hashes depend on the line endings of the checkout (core.autocrlf).
if (-not $Check) {
    $manifestPath = Join-Path $root 'manifest.json'
    Push-Location $root
    try { $files = @(git ls-files --cached --others --exclude-standard | Where-Object { $_ -ne 'manifest.json' -and (Test-Path -LiteralPath $_) }) }
    finally { Pop-Location }
    $files = @($files | Sort-Object { $_ } -Culture ([cultureinfo]::InvariantCulture) -CaseSensitive -Unique)
    $entries = foreach ($file in $files) {
        [ordered]@{ path = $file; sha256 = (Get-FileHash -LiteralPath (Join-Path $root $file) -Algorithm SHA256).Hash.ToLowerInvariant() }
    }
    $manifest = (ConvertTo-Json -InputObject @($entries) -Depth 3) -replace "`r`n", "`n"
    [IO.File]::WriteAllText($manifestPath, $manifest + "`n", $utf8)
    Write-Host "Generated manifest.json ($($files.Count) files)"
}

if ($Check) {
    if ($stale.Count) { Write-Host ("Out of date: " + ($stale -join ', ') + ". Run build/Build-Scripts.ps1."); exit 1 }
    Write-Host 'Generated scripts are up to date.'
    exit 0
}
