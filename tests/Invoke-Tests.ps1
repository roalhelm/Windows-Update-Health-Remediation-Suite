<#
.SYNOPSIS
    Runs all tests. Uses Pester when it is installed, otherwise a minimal built-in runner.
.EXAMPLE
    pwsh ./tests/Invoke-Tests.ps1
#>
$ErrorActionPreference = 'Stop'
$testFiles = @(Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.Tests.ps1' | Sort-Object Name)

if (Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version.Major -ge 5 }) {
    Import-Module Pester -MinimumVersion 5.0
    $result = Invoke-Pester -Path $PSScriptRoot -PassThru
    exit $result.FailedCount
}

Write-Host 'Pester 5 not found, using the built-in runner.'
$script:failed = 0; $script:passed = 0; $script:setup = $null
function Describe([string]$Name, [scriptblock]$Body) { Write-Host $Name; $script:setup = $null; . $Body }
function BeforeAll([scriptblock]$Body) { $script:setup = $Body }
function It([string]$Name, [scriptblock]$Body) {
    try { if ($script:setup) { . $script:setup }; . $Body; $script:passed++; Write-Host "  [+] $Name" }
    catch { $script:failed++; Write-Host "  [-] $Name`n      $($_.Exception.Message)" }
}
foreach ($file in $testFiles) { . $file.FullName }
Write-Host "Passed: $script:passed  Failed: $script:failed"
exit $script:failed
