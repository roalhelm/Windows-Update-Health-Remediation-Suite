$checks=[ordered]@{}
$checks.PowerShell64=[Environment]::Is64BitProcess
$checks.Admin=([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$checks.DISM=Test-Path "$env:windir\System32\dism.exe"
$checks.SFC=Test-Path "$env:windir\System32\sfc.exe"
$checks.SystemLog=try{Get-WinEvent -LogName System -MaxEvents 1 -ErrorAction Stop|Out-Null;$true}catch{$false}
[pscustomobject]$checks
