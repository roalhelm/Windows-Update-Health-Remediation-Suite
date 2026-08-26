param([string]$Destination=$env:PUBLIC)
$ErrorActionPreference='Stop'
$stamp=Get-Date -Format yyyyMMdd-HHmmss
$work=Join-Path $env:TEMP "WUHealth-$stamp"; New-Item $work -ItemType Directory -Force|Out-Null
$paths=@('C:\ProgramData\WUHealthSuite','C:\Windows\Logs\DISM\dism.log','C:\Windows\Logs\CBS\CBS.log')
foreach($p in $paths){if(Test-Path $p){Copy-Item $p $work -Recurse -Force -ErrorAction SilentlyContinue}}
Get-WinEvent -FilterHashtable @{LogName='System';StartTime=(Get-Date).AddDays(-30);Id=@(7,11,51,55,98,129,153,157)} -ErrorAction SilentlyContinue | Export-Clixml (Join-Path $work 'StorageEvents.xml')
$zip=Join-Path $Destination "WUHealth-$env:COMPUTERNAME-$stamp.zip"; Compress-Archive "$work\*" $zip -Force; Remove-Item $work -Recurse -Force; $zip
