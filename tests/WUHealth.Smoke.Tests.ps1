Describe 'WUHealth Suite smoke tests' {
 BeforeAll { . "$PSScriptRoot\..\src\common\WUHealth.Common.ps1" }
 It 'returns default configuration' {
  $cfg = Get-WUHDefaultConfig
  if($cfg.MinimumFreeSpaceGB -le 0){ throw 'MinimumFreeSpaceGB should be greater than zero.' }
 }
 It 'returns a reboot state boolean' {
  $state = Test-WUHPendingReboot
  if($state -isnot [bool]) { throw "Expected boolean reboot state, got $($state.GetType().FullName)" }
 }
 It 'includes Windows Update health signals' {
  $update = Get-WUHUpdateStatus (Get-WUHDefaultConfig)
  if($null -eq $update){ throw 'Get-WUHUpdateStatus returned null.' }
  if((-not ($update.PSObject.Properties.Name -contains 'CurrentBuild')) -or (-not ($update.PSObject.Properties.Name -contains 'Status'))){ throw 'Windows Update status is missing required properties.' }
 }
 It 'contains required public functions' {
  $commands = Get-Command Get-WUHHealth,Invoke-WUHRepair -ErrorAction SilentlyContinue
  if($null -eq $commands -or $commands.Count -lt 2){ throw 'Expected Get-WUHHealth and Invoke-WUHRepair to be available.' }
 }
 It 'disables local repair sources for Intune and avoids HealthConfig dependencies' {
  $config = Get-WUHDefaultConfig
  if($config.RepairSource -ne ''){ throw 'RepairSource should be empty for Intune default config.' }
  if($config.RepairSourceType -ne 'WindowsUpdate'){ throw 'RepairSourceType should remain WindowsUpdate.' }

  $detect = Get-Content "$PSScriptRoot\..\src\intune\Detect-WUHealth.ps1" -Raw
  $remediate = Get-Content "$PSScriptRoot\..\src\intune\Remediate-WUHealth.ps1" -Raw

  if($detect -match 'HealthConfig\.json'){ throw 'Detect script should not reference HealthConfig.json.' }
  if($remediate -match 'HealthConfig\.json'){ throw 'Remediate script should not reference HealthConfig.json.' }
  if($remediate -match '/Source:'){ throw 'Remediate script should not use a local repair source.' }
 }
}
