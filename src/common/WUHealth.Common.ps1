Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-WUHDefaultConfig {
    @{
        LookbackDays = 30; MinimumFreeSpaceGB = 20
        StorageEventIds = @(7,11,51,55,98,129,153,157)
        StorageEventWarningCount = 1; StorageEventCriticalCount = 5
        DriverAgeWarningDays = 1095; RepeatOffenderThreshold = 2
        RepairHistoryDays = 90; RepairSource = ''; RepairSourceType = 'WindowsUpdate'; UseLocalRepairSource = $false
        RunSFC = $true; RunComponentCleanup = $false; ResetWindowsUpdateComponents = $false
        CheckWindowsUpdate = $true; TriggerUpdateScan = $true
        MinimumSupportedBuild = 26100; PatchStaleDays = 45
        LogRoot = 'C:\ProgramData\WUHealthSuite\Logs'
        StatePath = 'C:\ProgramData\WUHealthSuite\State.json'
    }
}
function Initialize-WUHPath([hashtable]$Config) {
    $root = Split-Path $Config.StatePath -Parent
    New-Item -Path $root,$Config.LogRoot -ItemType Directory -Force | Out-Null
}
function Write-WUHLog([hashtable]$Config,[string]$Message,[string]$Level='INFO') {
    Initialize-WUHPath $Config
    $line = "{0} [{1}] {2}" -f (Get-Date -Format o),$Level,$Message
    Add-Content -LiteralPath (Join-Path $Config.LogRoot ('WUHealth-{0}.log' -f (Get-Date -Format yyyyMMdd))) -Value $line -Encoding UTF8
}
function Invoke-WUHProcess([string]$File,[string]$Arguments,[int]$TimeoutMinutes=120) {
    $out = [IO.Path]::GetTempFileName(); $err = [IO.Path]::GetTempFileName()
    try {
        $p = Start-Process -FilePath $File -ArgumentList $Arguments -PassThru -Wait:$false -WindowStyle Hidden -RedirectStandardOutput $out -RedirectStandardError $err
        if(-not $p.WaitForExit($TimeoutMinutes*60000)){ try{$p.Kill()}catch{}; throw "Timeout: $File $Arguments" }
        [pscustomobject]@{ ExitCode=$p.ExitCode; StdOut=(Get-Content $out -Raw -ErrorAction SilentlyContinue); StdErr=(Get-Content $err -Raw -ErrorAction SilentlyContinue) }
    } finally { Remove-Item $out,$err -Force -ErrorAction SilentlyContinue }
}
function Get-WUHState([hashtable]$Config) {
    if(Test-Path $Config.StatePath){ try { return Get-Content $Config.StatePath -Raw | ConvertFrom-Json } catch{} }
    [pscustomobject]@{ RepairHistory=@(); LastResult='Never'; LastRun=$null }
}
function Save-WUHState([hashtable]$Config,[object]$State) {
    Initialize-WUHPath $Config
    $State | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Config.StatePath -Encoding UTF8
}
function Test-WUHServicingRebootPending {
    # True when component servicing itself waits for a restart. DISM /RestoreHealth cannot run reliably in that state.
    Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
}
function Test-WUHPendingReboot {
    $paths=@('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending','HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired')
    if($paths | Where-Object {Test-Path $_}){return $true}
    try { return $null -ne (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue).PendingFileRenameOperations } catch{return $false}
}
function Get-WUHStorageEvents([hashtable]$Config) {
    $start=(Get-Date).AddDays(-[int]$Config.LookbackDays)
    try { @(Get-WinEvent -FilterHashtable @{LogName='System';StartTime=$start;Id=$Config.StorageEventIds} -ErrorAction Stop | Select-Object TimeCreated,Id,ProviderName,LevelDisplayName,Message) } catch { @() }
}
function Get-WUHFailedUpdates([object[]]$History) {
    # $History is newest first. An entry counts as failed only when the install failed or was aborted
    # (ResultCode 4 or 5) and the same update has no newer successful install (ResultCode 2 or 3).
    # In-progress and not-started entries (codes 1 and 0) are not failures.
    $succeeded=@{}; $failed=@()
    foreach($entry in @($History)){
        if(-not $entry -or [string]::IsNullOrWhiteSpace([string]$entry.Title)){ continue }
        if($null -ne $entry.Operation -and [int]$entry.Operation -ne 1){ continue }
        $title=[string]$entry.Title
        $code=[int]$entry.ResultCode
        if($code -eq 2 -or $code -eq 3){ $succeeded[$title]=$true; continue }
        if(($code -eq 4 -or $code -eq 5) -and -not $succeeded.ContainsKey($title)){
            $succeeded[$title]=$true
            $failed += [pscustomobject]@{ Date=$entry.Date; Title=$title; ResultCode=$code }
        }
    }
    $failed
}
function Get-WUHUpdateStatus {
    param(
        [hashtable]$Config
    )
    if($null -eq $Config -or $Config.Count -eq 0){ $Config = Get-WUHDefaultConfig }
    $state=[ordered]@{
        Status='Unknown';
        HasProblems=$false;
        PatchLevelBehind=$false;
        CurrentVersion=$null;
        CurrentBuild=$null;
        UBR=$null;
        LastScanTime=$null;
        LastInstallationTime=$null;
        PendingUpdates=0;
        FailedUpdates=@();
        ServiceStatus=$null;
        ServiceStartType=$null;
        AgentVersion=$null
    }
    try {
        $os=Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $state.CurrentVersion=$os.Version
        $state.CurrentBuild=$os.BuildNumber
        $nt=Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue
        if($nt){ $state.UBR=$nt.UBR }
    } catch {}
    try {
        $hotfix = Get-HotFix | Where-Object { $_.InstalledOn } | Sort-Object InstalledOn -Descending | Select-Object -First 1
        if($hotfix){ $state.LastInstallationTime = [datetime]$hotfix.InstalledOn }
    } catch {}
    try {
        $svc=Get-Service -Name wuauserv -ErrorAction Stop
        $state.ServiceStatus=$svc.Status.ToString()
        $state.ServiceStartType=$svc.StartType.ToString()
    } catch { $state.ServiceStatus='Missing' }
    try { $state.AgentVersion=(New-Object -ComObject Microsoft.Update.AgentInfo).GetInfo('ProductVersionString') } catch {}
    $searcher=$null
    try {
        $session=New-Object -ComObject Microsoft.Update.Session
        $searcher=$session.CreateUpdateSearcher()
        # Offline search: tests the agent and its database without starting a network scan.
        $searcher.Online=$false
        $pending=$searcher.Search('IsInstalled=0 and IsHidden=0')
        # Count software updates only. Drivers (Type 2) and optional updates (BrowseOnly) are not a patch gap.
        $count=0
        foreach($update in $pending.Updates){
            $optional=$false; try { $optional=[bool]$update.BrowseOnly } catch {}
            if([int]$update.Type -eq 1 -and -not $optional){ $count++ }
        }
        $state.PendingUpdates=$count
        $state.LastScanTime=(Get-Date).ToString('o')
    } catch {
        $state.HasProblems=$true
        $state.Status='QueryFailed'
    }
    if($searcher){
        try {
            $total=$searcher.GetTotalHistoryCount()
            if($total -gt 0){
                $failed=Get-WUHFailedUpdates @($searcher.QueryHistory(0,[math]::Min(50,$total)))
                if(@($failed).Count -gt 0){
                    $state.FailedUpdates=@($failed)
                    $state.HasProblems=$true
                    if($state.Status -ne 'QueryFailed'){ $state.Status='UpdateIssues' }
                }
            }
        } catch {}
    }
    # wuauserv is a demand-start service: "Stopped" is normal. Only "Disabled" or "Missing" is a problem.
    if($state.ServiceStatus -eq 'Missing' -or $state.ServiceStartType -eq 'Disabled'){
        $state.HasProblems=$true
        $state.Status='UpdateServiceIssue'
    }
    if($state.CurrentBuild -and $Config.MinimumSupportedBuild -and [int]$state.CurrentBuild -lt [int]$Config.MinimumSupportedBuild){
        $state.PatchLevelBehind=$true
    }
    if($state.LastInstallationTime -and $Config.PatchStaleDays){
        $ageDays = ((Get-Date) - [datetime]$state.LastInstallationTime).TotalDays
        if($ageDays -gt [double]$Config.PatchStaleDays){ $state.PatchLevelBehind=$true }
    }
    # Pending updates alone are not a finding: update rings defer and schedule them on purpose.
    if(-not $state.HasProblems){
        if($state.PatchLevelBehind){ $state.Status='PatchLevelBehind' }
        elseif($state.PendingUpdates -gt 0){ $state.Status='PendingUpdates' }
        else { $state.Status='Healthy' }
    }
    [pscustomobject]$state
}
function Resolve-WUHStatus {
    # Pure decision function: turns collected signals into one status. Order matters.
    # Component store corruption ranks above update findings because it is a common cause of them.
    param(
        [int]$ErrorCount=0,[bool]$StorageBad=$false,[bool]$DriverBad=$false,
        [int]$RepairCount=0,[int]$RepeatOffenderThreshold=2,
        [bool]$DISMUnrepairable=$false,[bool]$DISMRepairable=$false,[bool]$SFCViolation=$false,
        [bool]$UpdateHasProblems=$false,[bool]$PatchLevelBehind=$false,[bool]$PendingReboot=$false
    )
    if($ErrorCount -gt 0){ return 'Error' }
    if($StorageBad){ return 'EscalateStorage' }
    if($DriverBad){ return 'EscalateDriver' }
    if($RepairCount -ge $RepeatOffenderThreshold){ return 'RepeatOffender' }
    if($DISMUnrepairable){ return 'RepeatOffender' }
    if($DISMRepairable -or $SFCViolation){ return 'Repairable' }
    if($UpdateHasProblems){ return 'UpdateIssue' }
    if($PatchLevelBehind){ return 'PatchLevelBehind' }
    if($PendingReboot){ return 'RebootRequired' }
    'Healthy'
}
function ConvertTo-WUHComponentStoreState([string]$Text) {
    # Fallback parser for "dism /Online /Cleanup-Image /CheckHealth" output (English and German).
    # Checks run from most to least specific: "No component store corruption detected" must not count as corruption.
    # A dot stands in for umlauts so the script stays pure ASCII (Windows PowerShell 5.1 reads BOM-less files as ANSI).
    if([string]::IsNullOrWhiteSpace($Text)){ return 'Unknown' }
    if($Text -match 'No component store corruption detected|keine Komponentenspeicherbesch.digung'){ return 'Healthy' }
    if($Text -match 'cannot be repaired|not repairable|non-repairable|nicht repariert werden|nicht reparierbar'){ return 'NonRepairable' }
    if($Text -match 'is repairable|can be repaired|kann repariert werden|reparierbar'){ return 'Repairable' }
    'Unknown'
}
function Get-WUHComponentStoreState {
    # Prefers the DISM cmdlet because its result does not depend on the display language.
    try {
        $image=Repair-WindowsImage -Online -CheckHealth -ErrorAction Stop
        return [pscustomobject]@{ State=[string]$image.ImageHealthState; ExitCode=0; Source='Cmdlet' }
    } catch {}
    $dism=Invoke-WUHProcess dism.exe '/Online /Cleanup-Image /CheckHealth' 20
    [pscustomobject]@{ State=(ConvertTo-WUHComponentStoreState ([string]$dism.StdOut)); ExitCode=$dism.ExitCode; Source='DismExe' }
}
function Test-WUHSfcViolation([string]$Text) {
    # Input is the NUL-stripped output of "sfc /verifyonly" (English and German).
    if([string]::IsNullOrWhiteSpace($Text)){ return $false }
    if($Text -match 'did not find any integrity violations|keine Integrit.tsverletzungen'){ return $false }
    [bool]($Text -match 'found integrity violations|Integrit.tsverletzungen gefunden')
}
function Get-WUHHealth([hashtable]$Config) {
    Initialize-WUHPath $Config
    $errors=@(); $warnings=@(); $signals=[ordered]@{}
    try {$os=Get-CimInstance Win32_OperatingSystem; $cs=Get-CimInstance Win32_ComputerSystem; $bios=Get-CimInstance Win32_BIOS} catch {$errors += $_.Exception.Message}
    $system=Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction SilentlyContinue
    $freeGB=if($system){[math]::Round($system.FreeSpace/1GB,1)}else{$null}
    $signals.FreeSpaceGB=$freeGB
    if($null -ne $freeGB -and $freeGB -lt [double]$Config.MinimumFreeSpaceGB){$warnings += "LowFreeSpace"}
    $events=Get-WUHStorageEvents $Config; $signals.StorageEventCount=$events.Count; $signals.StorageEventIds=@($events.Id | Sort-Object -Unique)
    try {$pd=@(Get-PhysicalDisk -ErrorAction Stop | Select FriendlyName,MediaType,HealthStatus,OperationalStatus,BusType)}catch{$pd=@()}
    $signals.PhysicalDisks=$pd
    $storageBad=($events.Count -ge [int]$Config.StorageEventCriticalCount) -or @($pd|Where-Object {$_.HealthStatus -notin @('Healthy','Unknown') -or $_.OperationalStatus -notcontains 'OK'}).Count -gt 0
    try {$pnp=@(Get-CimInstance Win32_PnPEntity -ErrorAction Stop | Where-Object {$_.ConfigManagerErrorCode -ne 0} | Select Name,PNPClass,ConfigManagerErrorCode,Manufacturer)}catch{$pnp=@()}
    $signals.PnPErrors=$pnp
    $driverBad=@($pnp|Where-Object {$_.PNPClass -match 'SCSIAdapter|HDC|DiskDrive|System'}).Count -gt 0
    $updateProblems=$false; $patchBehind=$false
    if($Config.CheckWindowsUpdate){
        $signals.WindowsUpdate=Get-WUHUpdateStatus $Config
        $updateProblems=[bool]$signals.WindowsUpdate.HasProblems; $patchBehind=[bool]$signals.WindowsUpdate.PatchLevelBehind
    }
    $store=Get-WUHComponentStoreState
    $signals.ComponentStoreState=$store.State
    $signals.DISMExitCode=$store.ExitCode
    $signals.DISMRepairable=($store.State -eq 'Repairable')
    $signals.DISMUnrepairable=($store.State -eq 'NonRepairable')
    $sfc=Invoke-WUHProcess sfc.exe '/verifyonly' 60
    $signals.SFCExitCode=$sfc.ExitCode
    # sfc.exe writes UTF-16. Read as ANSI the text has a NUL between all characters, so strip them before matching.
    $sfcText=([string]$sfc.StdOut) -replace "`0",''
    $signals.SFCViolation=Test-WUHSfcViolation $sfcText
    $signals.PendingReboot=Test-WUHPendingReboot
    $state=Get-WUHState $Config
    $cut=(Get-Date).AddDays(-[int]$Config.RepairHistoryDays)
    $recent=@($state.RepairHistory|Where-Object {try{[datetime]$_.Time -ge $cut}catch{$false}})
    $signals.RepairCount=$recent.Count
    $status=Resolve-WUHStatus -ErrorCount $errors.Count -StorageBad $storageBad -DriverBad $driverBad -RepairCount $recent.Count -RepeatOffenderThreshold ([int]$Config.RepeatOffenderThreshold) -DISMUnrepairable ([bool]$signals.DISMUnrepairable) -DISMRepairable ([bool]$signals.DISMRepairable) -SFCViolation ([bool]$signals.SFCViolation) -UpdateHasProblems $updateProblems -PatchLevelBehind $patchBehind -PendingReboot ([bool]$signals.PendingReboot)
    [pscustomobject]@{SchemaVersion='1.0';Timestamp=(Get-Date).ToString('o');ComputerName=$env:COMPUTERNAME;Status=$status;Manufacturer=$cs.Manufacturer;Model=$cs.Model;OSVersion=$os.Version;Build=$os.BuildNumber;BIOS=$bios.SMBIOSBIOSVersion;Warnings=$warnings;Errors=$errors;Signals=$signals}
}
function Get-WUHRepairCommandArgs([hashtable]$Config) {
    if ($Config.UseLocalRepairSource -or (-not [string]::IsNullOrWhiteSpace($Config.RepairSource))) {
        Write-WUHLog $Config 'Local DISM repair source ignored; using Windows Update / online repair only.' 'WARN'
    }
    '/Online /Cleanup-Image /RestoreHealth'
}
function Reset-WUHUpdateComponents([hashtable]$Config) {
    # Renames (never deletes) the update cache folders so Windows rebuilds them. Off by default.
    Write-WUHLog $Config 'Resetting Windows Update components (rename SoftwareDistribution and catroot2)'
    $stamp=Get-Date -Format yyyyMMddHHmmss
    foreach($svc in 'bits','wuauserv','cryptsvc'){Stop-Service $svc -Force -ErrorAction SilentlyContinue}
    Rename-Item "$env:windir\SoftwareDistribution" "SoftwareDistribution.wuh-old-$stamp" -ErrorAction SilentlyContinue
    Rename-Item "$env:windir\System32\catroot2" "catroot2.wuh-old-$stamp" -ErrorAction SilentlyContinue
    foreach($svc in 'cryptsvc','wuauserv','bits'){Start-Service $svc -ErrorAction SilentlyContinue}
}
function Invoke-WUHUpdateRemediation([hashtable]$Config,[string]$PreStatus) {
    # Safe actions for UpdateIssue / PatchLevelBehind: optional component reset, then ask Windows to scan.
    # Installation stays with the update policy (update rings, Autopatch); nothing is forced here.
    Write-WUHLog $Config "Update remediation start (state $PreStatus)"
    $actions=@()
    if($Config.ResetWindowsUpdateComponents){ Reset-WUHUpdateComponents $Config; $actions += 'ComponentReset' }
    $scan=$false
    if($Config.TriggerUpdateScan){
        $uso=Join-Path $env:windir 'System32\UsoClient.exe'
        if(Test-Path $uso){
            try { Invoke-WUHProcess $uso 'StartScan' 5 | Out-Null; $scan=$true; $actions += 'ScanTriggered' }
            catch { Write-WUHLog $Config "UsoClient StartScan failed: $($_.Exception.Message)" 'WARN' }
        } else { Write-WUHLog $Config 'UsoClient.exe not found; scan not triggered' 'WARN' }
    }
    $status=if($scan){'UpdateScanTriggered'}elseif($actions.Count){'UpdateActionTaken'}else{'NoActionTaken'}
    Write-WUHLog $Config "Update remediation finished: $status ($($actions -join ','))"
    [pscustomobject]@{Status=$status;PreStatus=$PreStatus;Actions=$actions;RebootRequired=(Test-WUHPendingReboot)}
}
function Invoke-WUHRepair([hashtable]$Config) {
    Initialize-WUHPath $Config; Write-WUHLog $Config 'Repair start'
    $pre=Get-WUHHealth $Config
    if($pre.Status -in @('UpdateIssue','PatchLevelBehind')){ return Invoke-WUHUpdateRemediation $Config $pre.Status }
    if($pre.Status -ne 'Repairable'){Write-WUHLog $Config "Repair blocked by state $($pre.Status)" 'WARN'; return [pscustomobject]@{Status='Blocked';PreStatus=$pre.Status}}
    if(Test-WUHServicingRebootPending){
        # A servicing restart is outstanding: repairing now would fail or be undone. Report it and repair on the next run.
        Write-WUHLog $Config 'Repair postponed: component servicing is waiting for a restart' 'WARN'
        return [pscustomobject]@{Status='RebootRequired';PreStatus=$pre.Status;RebootRequired=$true}
    }
    if($Config.ResetWindowsUpdateComponents){ Reset-WUHUpdateComponents $Config }
    $dismArgs = Get-WUHRepairCommandArgs $Config
    $dism=Invoke-WUHProcess dism.exe $dismArgs 120
    $sfc=$null; if($Config.RunSFC){$sfc=Invoke-WUHProcess sfc.exe '/scannow' 90}
    if($Config.RunComponentCleanup){Invoke-WUHProcess dism.exe '/Online /Cleanup-Image /StartComponentCleanup' 120 | Out-Null}
    $state=Get-WUHState $Config; $history=@($state.RepairHistory); $history += [pscustomobject]@{Time=(Get-Date).ToString('o');DISM=$dism.ExitCode;SFC=if($sfc){$sfc.ExitCode}else{$null}}
    $new=[pscustomobject]@{RepairHistory=$history;LastResult="DISM=$($dism.ExitCode);SFC=$(if($sfc){$sfc.ExitCode}else{'Skipped'})";LastRun=(Get-Date).ToString('o')}; Save-WUHState $Config $new
    $post=Get-WUHHealth $Config; Write-WUHLog $Config "Repair finished: $($post.Status)"
    [pscustomobject]@{Status=$post.Status;PreStatus=$pre.Status;DISMExitCode=$dism.ExitCode;SFCExitCode=if($sfc){$sfc.ExitCode}else{$null};RebootRequired=(Test-WUHPendingReboot)}
}
