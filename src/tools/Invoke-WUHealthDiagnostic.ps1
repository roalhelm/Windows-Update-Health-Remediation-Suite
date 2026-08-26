param([string]$OutputPath=(Join-Path $env:PUBLIC ("WUHealth-{0}.json" -f $env:COMPUTERNAME)))
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '..\common\WUHealth.Common.ps1')
$config=Get-WUHDefaultConfig
$r=Get-WUHHealth $config
$r | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
$r | Format-List ComputerName,Status,Manufacturer,Model,OSVersion,Build,BIOS,Warnings,Errors
Write-Host "Report: $OutputPath"
