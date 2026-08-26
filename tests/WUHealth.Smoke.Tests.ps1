Describe 'WUHealth Suite smoke tests' {
 BeforeAll { . "$PSScriptRoot\..\src\common\WUHealth.Common.ps1" }
 It 'returns default configuration' { (Get-WUHDefaultConfig).MinimumFreeSpaceGB | Should -BeGreaterThan 0 }
 It 'returns a reboot state boolean' { (Test-WUHPendingReboot) | Should -BeOfType [bool] }
 It 'contains required public functions' { Get-Command Get-WUHHealth,Invoke-WUHRepair | Should -Not -BeNullOrEmpty }
}
