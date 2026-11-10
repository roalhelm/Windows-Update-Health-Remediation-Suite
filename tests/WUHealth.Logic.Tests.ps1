# Tests for the pure decision logic. They need no Windows APIs and run on any platform.
Describe 'WUHealth decision logic' {
 BeforeAll {
  . "$PSScriptRoot\..\src\common\WUHealth.Common.ps1"
  function Assert-Equal($Actual,$Expected,[string]$What){ if($Actual -ne $Expected){ throw "$What - expected '$Expected', got '$Actual'." } }
  function New-HistoryEntry([string]$Title,[int]$ResultCode,[int]$Operation=1){ [pscustomobject]@{Title=$Title;ResultCode=$ResultCode;Operation=$Operation;Date=(Get-Date)} }
 }
 It 'reports Healthy when no signal is set' {
  Assert-Equal (Resolve-WUHStatus) 'Healthy' 'no signals'
 }
 It 'ranks component store corruption above update findings' {
  Assert-Equal (Resolve-WUHStatus -DISMRepairable $true -UpdateHasProblems $true -PatchLevelBehind $true -PendingReboot $true) 'Repairable' 'corrupt and behind'
  Assert-Equal (Resolve-WUHStatus -SFCViolation $true -PatchLevelBehind $true) 'Repairable' 'sfc violation and behind'
 }
 It 'ranks escalation states above repair' {
  Assert-Equal (Resolve-WUHStatus -ErrorCount 1 -StorageBad $true -DISMRepairable $true) 'Error' 'error first'
  Assert-Equal (Resolve-WUHStatus -StorageBad $true -DriverBad $true -DISMRepairable $true) 'EscalateStorage' 'storage'
  Assert-Equal (Resolve-WUHStatus -DriverBad $true -DISMRepairable $true) 'EscalateDriver' 'driver'
  Assert-Equal (Resolve-WUHStatus -RepairCount 2 -RepeatOffenderThreshold 2 -DISMRepairable $true) 'RepeatOffender' 'repeat count'
  Assert-Equal (Resolve-WUHStatus -DISMUnrepairable $true -DISMRepairable $true) 'RepeatOffender' 'unrepairable store'
 }
 It 'orders update findings and reboot' {
  Assert-Equal (Resolve-WUHStatus -UpdateHasProblems $true -PatchLevelBehind $true) 'UpdateIssue' 'update issue first'
  Assert-Equal (Resolve-WUHStatus -PatchLevelBehind $true -PendingReboot $true) 'PatchLevelBehind' 'behind before reboot'
  Assert-Equal (Resolve-WUHStatus -PendingReboot $true) 'RebootRequired' 'reboot only'
 }
 It 'counts only failed installs without a newer success' {
  $history=@(
   (New-HistoryEntry 'KB1 cumulative' 2),   # newest: succeeded
   (New-HistoryEntry 'KB1 cumulative' 4),   # older failure of the same update, superseded by the success above
   (New-HistoryEntry 'KB2 driver' 4),       # failed, never succeeded
   (New-HistoryEntry 'KB2 driver' 4),       # duplicate failure, counted once
   (New-HistoryEntry 'KB3 defender' 1),     # in progress, not a failure
   (New-HistoryEntry 'KB4 feature' 5),      # aborted
   (New-HistoryEntry 'KB5 removed' 4 2)     # uninstall operation, ignored
  )
  $failed=@(Get-WUHFailedUpdates $history)
  Assert-Equal $failed.Count 2 'failed count'
  Assert-Equal $failed[0].Title 'KB2 driver' 'first failed title'
  Assert-Equal $failed[1].Title 'KB4 feature' 'second failed title'
 }
 It 'returns no failures for an empty or clean history' {
  Assert-Equal @(Get-WUHFailedUpdates @()).Count 0 'empty history'
  Assert-Equal @(Get-WUHFailedUpdates @((New-HistoryEntry 'KB1' 2),(New-HistoryEntry 'KB2' 3))).Count 0 'clean history'
 }
 It 'parses DISM CheckHealth output without mistaking a healthy store for corruption' {
  Assert-Equal (ConvertTo-WUHComponentStoreState 'No component store corruption detected.') 'Healthy' 'en healthy'
  Assert-Equal (ConvertTo-WUHComponentStoreState 'The component store is repairable.') 'Repairable' 'en repairable'
  Assert-Equal (ConvertTo-WUHComponentStoreState 'The component store cannot be repaired.') 'NonRepairable' 'en non-repairable'
  Assert-Equal (ConvertTo-WUHComponentStoreState 'Der Komponentenspeicher kann repariert werden.') 'Repairable' 'de repairable'
  Assert-Equal (ConvertTo-WUHComponentStoreState 'Der Komponentenspeicher kann nicht repariert werden.') 'NonRepairable' 'de non-repairable'
  Assert-Equal (ConvertTo-WUHComponentStoreState '') 'Unknown' 'empty'
 }
 It 'detects sfc integrity violations in UTF-16 output read as ANSI' {
  $raw=('Windows Resource Protection found integrity violations.'.ToCharArray() -join "`0")
  Assert-Equal (Test-WUHSfcViolation ($raw -replace "`0",'')) $true 'en violation'
  Assert-Equal (Test-WUHSfcViolation 'Windows Resource Protection did not find any integrity violations.') $false 'en clean'
  Assert-Equal (Test-WUHSfcViolation '') $false 'empty'
 }
}

Describe 'Repair routing' {
 BeforeAll {
  . "$PSScriptRoot\..\src\common\WUHealth.Common.ps1"
  # Replace everything that touches the system. Only the routing in Invoke-WUHRepair is under test.
  $script:preStatus='Healthy'; $script:servicingReboot=$false; $script:calls=@()
  function Initialize-WUHPath($Config){}
  function Write-WUHLog($Config,$Message,$Level){}
  function Get-WUHHealth($Config){ [pscustomobject]@{Status=$script:preStatus} }
  function Test-WUHPendingReboot{ $false }
  function Test-WUHServicingRebootPending{ $script:servicingReboot }
  function Invoke-WUHProcess($File,$Arguments,$TimeoutMinutes){ $script:calls += "$File $Arguments"; [pscustomobject]@{ExitCode=0;StdOut='';StdErr=''} }
  function Get-WUHState($Config){ [pscustomobject]@{RepairHistory=@();LastResult='Never';LastRun=$null} }
  function Save-WUHState($Config,$State){}
  function Reset-WUHUpdateComponents($Config){ $script:calls += 'reset' }
  function New-TestConfig{ $c=Get-WUHDefaultConfig; $c.TriggerUpdateScan=$false; $c }
  function Assert-Equal($Actual,$Expected,[string]$What){ if($Actual -ne $Expected){ throw "$What - expected '$Expected', got '$Actual'." } }
 }
 It 'never repairs in an escalation state' {
  foreach($state in 'EscalateStorage','EscalateDriver','RepeatOffender','Error','Healthy','RebootRequired'){
   $script:preStatus=$state; $script:calls=@()
   $r=Invoke-WUHRepair (New-TestConfig)
   Assert-Equal $r.Status 'Blocked' "state $state"
   Assert-Equal $script:calls.Count 0 "process calls in state $state"
  }
 }
 It 'runs DISM and SFC only for Repairable' {
  $script:preStatus='Repairable'; $script:servicingReboot=$false; $script:calls=@()
  $r=Invoke-WUHRepair (New-TestConfig)
  Assert-Equal $r.PreStatus 'Repairable' 'pre status'
  Assert-Equal $script:calls[0] 'dism.exe /Online /Cleanup-Image /RestoreHealth' 'dism call'
  Assert-Equal $script:calls[1] 'sfc.exe /scannow' 'sfc call'
  Assert-Equal $script:calls.Count 2 'call count'
 }
 It 'postpones the repair while component servicing waits for a restart' {
  $script:preStatus='Repairable'; $script:servicingReboot=$true; $script:calls=@()
  $r=Invoke-WUHRepair (New-TestConfig)
  Assert-Equal $r.Status 'RebootRequired' 'status'
  Assert-Equal $script:calls.Count 0 'process calls'
  $script:servicingReboot=$false
 }
 It 'handles update states without touching the component store' {
  foreach($state in 'UpdateIssue','PatchLevelBehind'){
   $script:preStatus=$state; $script:calls=@()
   $r=Invoke-WUHRepair (New-TestConfig)
   Assert-Equal $r.Status 'NoActionTaken' "state $state without scan"
   $c=New-TestConfig; $c.ResetWindowsUpdateComponents=$true
   $r=Invoke-WUHRepair $c
   Assert-Equal $r.Status 'UpdateActionTaken' "state $state with reset"
   Assert-Equal ($script:calls -join ';') 'reset' "calls in state $state"
  }
 }
}

Describe 'Generated scripts' {
 BeforeAll { $script:root = Split-Path $PSScriptRoot -Parent }
 It 'are up to date with the common engine' {
  & (Join-Path $script:root 'build/Build-Scripts.ps1') -Check 6>$null
  if($LASTEXITCODE -ne 0){ throw 'Generated scripts are stale. Run build/Build-Scripts.ps1.' }
 }
 It 'are pure ASCII and free of parse errors' {
  foreach($relative in 'src/common/WUHealth.Common.ps1','src/intune/Detect-WUHealth.ps1','src/intune/Remediate-WUHealth.ps1','src/sccm/Discovery-WUHealth.ps1','src/sccm/Remediate-WUHealth.ps1'){
   $path=Join-Path $script:root $relative
   if((Get-Content -LiteralPath $path -Raw) -match '[^\x00-\x7F]'){ throw "$relative contains non-ASCII characters." }
   $errors=$null; $tokens=$null
   [void][System.Management.Automation.Language.Parser]::ParseFile($path,[ref]$tokens,[ref]$errors)
   if($errors.Count){ throw "$relative has parse errors: $($errors[0].Message)" }
  }
 }
 It 'detection only starts remediation for states the remediation handles' {
  $detect=Get-Content -LiteralPath (Join-Path $script:root 'src/intune/Detect-WUHealth.ps1') -Raw
  $common=Get-Content -LiteralPath (Join-Path $script:root 'src/common/WUHealth.Common.ps1') -Raw
  if($detect -notmatch "-in @\(([^)]*)\)\)\{exit 1\}"){ throw 'Could not find the detection exit rule.' }
  foreach($state in ($Matches[1] -split ',' | ForEach-Object { $_.Trim(" '") })){
   if($state -ne 'Repairable' -and $common -notmatch "\`$pre\.Status -in @\([^)]*'$state'"){ throw "Remediation has no action for state '$state'." }
  }
 }
}
