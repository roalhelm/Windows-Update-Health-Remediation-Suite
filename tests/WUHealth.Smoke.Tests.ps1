Describe 'WUHealth Suite smoke tests' {
 BeforeAll { . "$PSScriptRoot\..\src\common\WUHealth.Common.ps1" }
 It 'returns default configuration' { (Get-WUHDefaultConfig).MinimumFreeSpaceGB | Should -BeGreaterThan 0 }
 It 'returns a reboot state boolean' { (Test-WUHPendingReboot) | Should -BeOfType [bool] }
 It 'contains required public functions' { Get-Command Get-WUHHealth,Invoke-WUHRepair | Should -Not -BeNullOrEmpty }
 It 'disables local repair sources for Intune and avoids HealthConfig dependencies' {
  $config = Get-WUHDefaultConfig
  $config.RepairSource | Should -Be ''
  $config.RepairSourceType | Should -Be 'WindowsUpdate'

  $detect = Get-Content "$PSScriptRoot\..\src\intune\Detect-WUHealth.ps1" -Raw
  $remediate = Get-Content "$PSScriptRoot\..\src\intune\Remediate-WUHealth.ps1" -Raw

  $detect | Should -Not -Match 'HealthConfig\.json'
  $remediate | Should -Not -Match 'HealthConfig\.json'
  $remediate | Should -Not -Match '/Source:'
 }
}
