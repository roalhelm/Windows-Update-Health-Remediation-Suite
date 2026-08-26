$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-WUHDefaultConfig {
    [ordered]@{
        LookbackDays = 30; MinimumFreeSpaceGB = 20
        StorageEventIds = @(7,11,51,55,98,129,153,157)
        StorageEventWarningCount = 1; StorageEventCriticalCount = 5
        DriverAgeWarningDays = 1095; RepeatOffenderThreshold = 2
        RepairHistoryDays = 90; RepairSource = ''; RepairSourceType = 'WindowsUpdate'
        RunSFC = $true; RunComponentCleanup = $false; ResetWindowsUpdateComponents = $false
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
function Test-WUHPendingReboot {
    $paths=@('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending','HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired')
    if($paths | Where-Object {Test-Path $_}){return $true}
    try { return $null -ne (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue).PendingFileRenameOperations } catch{return $false}
}
function Get-WUHStorageEvents([hashtable]$Config) {
    $start=(Get-Date).AddDays(-[int]$Config.LookbackDays)
    try { @(Get-WinEvent -FilterHashtable @{LogName='System';StartTime=$start;Id=$Config.StorageEventIds} -ErrorAction Stop | Select-Object TimeCreated,Id,ProviderName,LevelDisplayName,Message) } catch { @() }
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
    $dism=Invoke-WUHProcess dism.exe '/Online /Cleanup-Image /CheckHealth' 20
    $signals.DISMExitCode=$dism.ExitCode
    $signals.DISMRepairable=($dism.StdOut -match 'repairable|reparierbar|component store corruption detected|Komponentenspeicher.*beschädigt')
    $signals.DISMUnrepairable=($dism.StdOut -match 'non-repairable|nicht reparierbar')
    $sfc=Invoke-WUHProcess sfc.exe '/verifyonly' 60
    $signals.SFCExitCode=$sfc.ExitCode
    $signals.SFCViolation=($sfc.StdOut -match 'integrity violations|Integritätsverletzungen') -and ($sfc.StdOut -notmatch 'did not find|keine Integritätsverletzungen')
    $signals.PendingReboot=Test-WUHPendingReboot
    $state=Get-WUHState $Config
    $cut=(Get-Date).AddDays(-[int]$Config.RepairHistoryDays)
    $recent=@($state.RepairHistory|Where-Object {try{[datetime]$_.Time -ge $cut}catch{$false}})
    $signals.RepairCount=$recent.Count
    $status='Healthy'
    if($errors.Count){$status='Error'}
    elseif($storageBad){$status='EscalateStorage'}
    elseif($driverBad){$status='EscalateDriver'}
    elseif($recent.Count -ge [int]$Config.RepeatOffenderThreshold){$status='RepeatOffender'}
    elseif($signals.DISMUnrepairable){$status='RepeatOffender'}
    elseif($signals.DISMRepairable -or $signals.SFCViolation){$status='Repairable'}
    elseif($signals.PendingReboot){$status='RebootRequired'}
    [pscustomobject]@{SchemaVersion='1.0';Timestamp=(Get-Date).ToString('o');ComputerName=$env:COMPUTERNAME;Status=$status;Manufacturer=$cs.Manufacturer;Model=$cs.Model;OSVersion=$os.Version;Build=$os.BuildNumber;BIOS=$bios.SMBIOSBIOSVersion;Warnings=$warnings;Errors=$errors;Signals=$signals}
}
function Invoke-WUHRepair([hashtable]$Config) {
    Initialize-WUHPath $Config; Write-WUHLog $Config 'Repair start'
    $pre=Get-WUHHealth $Config
    if($pre.Status -notin @('Repairable')){Write-WUHLog $Config "Repair blocked by state $($pre.Status)" 'WARN'; return [pscustomobject]@{Status='Blocked';PreStatus=$pre.Status}}
    if($Config.ResetWindowsUpdateComponents){
        foreach($svc in 'bits','wuauserv','cryptsvc'){Stop-Service $svc -Force -ErrorAction SilentlyContinue}
        Rename-Item "$env:windir\SoftwareDistribution" "SoftwareDistribution.wuh-old-$(Get-Date -Format yyyyMMddHHmmss)" -ErrorAction SilentlyContinue
        Rename-Item "$env:windir\System32\catroot2" "catroot2.wuh-old-$(Get-Date -Format yyyyMMddHHmmss)" -ErrorAction SilentlyContinue
        foreach($svc in 'cryptsvc','wuauserv','bits'){Start-Service $svc -ErrorAction SilentlyContinue}
    }
    $args='/Online /Cleanup-Image /RestoreHealth'
    if($Config.RepairSource){$args += " /Source:$($Config.RepairSource) /LimitAccess"}
    $dism=Invoke-WUHProcess dism.exe $args 120
    $sfc=$null; if($Config.RunSFC){$sfc=Invoke-WUHProcess sfc.exe '/scannow' 90}
    if($Config.RunComponentCleanup){Invoke-WUHProcess dism.exe '/Online /Cleanup-Image /StartComponentCleanup' 120 | Out-Null}
    $state=Get-WUHState $Config; $history=@($state.RepairHistory); $history += [pscustomobject]@{Time=(Get-Date).ToString('o');DISM=$dism.ExitCode;SFC=if($sfc){$sfc.ExitCode}else{$null}}
    $new=[pscustomobject]@{RepairHistory=$history;LastResult="DISM=$($dism.ExitCode);SFC=$(if($sfc){$sfc.ExitCode}else{'Skipped'})";LastRun=(Get-Date).ToString('o')}; Save-WUHState $Config $new
    $post=Get-WUHHealth $Config; Write-WUHLog $Config "Repair finished: $($post.Status)"
    [pscustomobject]@{Status=$post.Status;DISMExitCode=$dism.ExitCode;SFCExitCode=if($sfc){$sfc.ExitCode}else{$null};RebootRequired=(Test-WUHPendingReboot)}
}

$config=Get-WUHDefaultConfig
try { $r=Invoke-WUHRepair $config; Write-Output ($r|ConvertTo-Json -Compress); if($r.Status -in @('Healthy','RebootRequired')){exit 0}else{exit 1} } catch { Write-Output ("Error: "+$_.Exception.Message); exit 1 }
