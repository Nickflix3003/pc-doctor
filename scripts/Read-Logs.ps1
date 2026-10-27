<#
.SYNOPSIS
  pc-doctor step 1: read what Windows already knows about keyboard / input trouble.
.DESCRIPTION
  READ-ONLY. Changes no setting, installs nothing, sends nothing anywhere.
  Reads: System + Application warnings/errors, USB/HID/PnP device events, the keyboard
  device list, running overlay and peripheral programs, Riot Vanguard service + log
  folder (if present), Sticky/Filter Keys, keyboard layouts, Game Mode / Game Bar settings.
  Writes the report to %USERPROFILE%\pc-doctor\read-logs-<stamp>.txt and prints it.
.PARAMETER Since
  How many days back to look (default 7).
.PARAMETER Around
  One or more date/times when the keyboard died, e.g. -Around "2026-10-25 21:40","2026-10-26 20:05".
  If given, events are read only for +/- AroundMinutes around each time instead of the Since window.
.PARAMETER AroundMinutes
  Half-width of each -Around window (default 10).
#>
[CmdletBinding()]
param(
  [double]$Since = 7,
  [string[]]$Around,
  [int]$AroundMinutes = 10
)
$ErrorActionPreference = 'SilentlyContinue'
$L = New-Object System.Collections.Generic.List[string]
function Say([string]$s = '') { [void]$L.Add($s) }
function Head([string]$s) { Say ''; Say ('=== ' + $s + ' ===') }

# ---- time windows ----
$now = Get-Date
$windows = @()
if ($Around) {
  foreach ($a in ($Around -split ',')) {   # powershell -File passes "a","b" as one comma-joined string
    try { $t = [datetime]::Parse($a.Trim()); $windows += @{ S = $t.AddMinutes(-$AroundMinutes); E = $t.AddMinutes($AroundMinutes) } }
    catch { Say "Could not read the time '$a' - skipped." }
  }
}
if (-not $windows) { $windows = @(@{ S = $now.AddDays(-$Since); E = $now }) }
$winText = ($windows | ForEach-Object { '{0:yyyy-MM-dd HH:mm} to {1:yyyy-MM-dd HH:mm}' -f $_.S, $_.E }) -join '; '

function Get-Ev([hashtable]$filter) {
  foreach ($w in $windows) {
    $f = $filter.Clone(); $f.StartTime = $w.S; $f.EndTime = $w.E
    Get-WinEvent -FilterHashtable $f -MaxEvents 500
  }
}
function Show-Ev($ev, [int]$top = 12) {
  if (-not $ev) { Say '  (none found)'; return }
  $ev | Group-Object ProviderName, Id | Sort-Object Count -Descending | Select-Object -First $top | ForEach-Object {
    $f = $_.Group[0]
    $msg = ("$($f.Message)" -split "`r?`n")[0]
    if ($msg.Length -gt 110) { $msg = $msg.Substring(0, 110) }
    Say ('  {0,4}x  {1}  id {2}  last {3:yyyy-MM-dd HH:mm}  {4}' -f $_.Count, $f.ProviderName, $f.Id, $f.TimeCreated, $msg)
  }
}

Say 'pc-doctor Read-Logs report'
Say ('Made:   {0:yyyy-MM-dd HH:mm}   Windows: {1}' -f $now, [Environment]::OSVersion.Version)
Say ('Window: ' + $winText)
Say 'Read-only. Nothing was changed or sent.'

# ---- 1. warnings / errors ----
Head 'System log: warnings and errors (grouped, most frequent first)'
$sysEv = @(Get-Ev @{ LogName = 'System'; Level = 1, 2, 3 })
Show-Ev $sysEv
Head 'Application log: warnings and errors (grouped, most frequent first)'
$appEv = @(Get-Ev @{ LogName = 'Application'; Level = 1, 2, 3 })
Show-Ev $appEv

# ---- 2. USB / HID / PnP device events ----
Head 'USB / HID / keyboard driver events (cause 5)'
$devProv = 'Microsoft-Windows-Kernel-PnP', 'Microsoft-Windows-USB-USBHUB3', 'Microsoft-Windows-USB-USBHUB', 'Microsoft-Windows-USB-USBXHCI',
  'Microsoft-Windows-USB-USBPORT', 'Microsoft-Windows-Input-HIDCLASS', 'kbdhid', 'i8042prt', 'mouhid', 'HidBth'
$devEv = @(Get-Ev @{ LogName = 'System'; ProviderName = $devProv; Level = 1, 2, 3 })
Say '  System log (Kernel-PnP id 219 = a driver failed to load):'
Show-Ev $devEv
$cfg = @(Get-Ev @{ LogName = 'Microsoft-Windows-Kernel-PnP/Configuration'; Id = 411 })
Say '  Kernel-PnP/Configuration, id 411 (a device had a problem starting):'
Show-Ev $cfg
$wd = @(Get-Ev @{ LogName = 'Microsoft-Windows-Kernel-PnP/Driver Watchdog'; Level = 1, 2, 3 })
Say '  Kernel-PnP/Driver Watchdog (warnings/errors):'
Show-Ev $wd

# ---- 3. keyboard devices ----
Head 'Keyboard / HID devices currently plugged in'
$kb = @(Get-PnpDevice -Class Keyboard, HIDClass -PresentOnly | Where-Object { $_.Class -eq 'Keyboard' -or $_.FriendlyName -match 'keyboard' })
if ($kb) { $kb | ForEach-Object { Say ('  [{0}] {1}  ({2})' -f $_.Status, $_.FriendlyName, $_.InstanceId) } } else { Say '  (none listed)' }
Say '  Note: one physical keyboard often shows as several "HID Keyboard Device" lines (one per interface).'

# ---- 4. overlays and peripheral software ----
Head 'Running overlay / peripheral programs (causes 2 and 3)'
$watch = [ordered]@{
  'Steam (overlay, Steam Input)' = '^(steam|steamwebhelper|gameoverlayui)$'
  'Discord (overlay)'            = '^discord'
  'NVIDIA overlay / GeForce'     = '^(nvcontainer|nvsphelper|nvidia share|nvidia overlay|nvoawrapper)'
  'AMD Radeon overlay'           = '^(radeonsoftware|amdrssrcext|amdrsserv|cnext)'
  'Xbox Game Bar'                = '^gamebar'
  'Razer Synapse / Central'      = '^(razer|rz)'
  'Logitech G Hub'               = '^lghub'
  'Corsair iCUE'                 = '^(icue|corsair)'
  'Wooting Wootility'            = '^wootility'
  'reWASD'                       = '^rewasd'
  'Other overlays/hooks'         = '^(overwolf|msiafterburner|rtss|medal|autohotkey)'
}
$procs = @(Get-Process | Select-Object -ExpandProperty Name -Unique)
$overlayHit = @(); $periphHit = @()
foreach ($k in $watch.Keys) {
  $m = @($procs | Where-Object { $_ -match $watch[$k] })
  if ($m) {
    Say ('  RUNNING  {0}  [{1}]' -f $k, ($m -join ', '))
    if ($k -match 'Razer|Logitech|Corsair|Wooting|reWASD') { $periphHit += $k } else { $overlayHit += $k }
  }
}
if (-not ($overlayHit + $periphHit)) { Say '  (none of the known overlay/peripheral programs are running)' }

# ---- 5. Riot Vanguard ----
Head 'Riot Vanguard (cause 3)'
foreach ($s in 'vgc', 'vgk') {
  $svc = Get-Service $s
  if ($svc) { Say ('  service {0}: {1}' -f $s, $svc.Status) } else { Say "  service ${s}: not installed" }
}
Say '  (vgk Running is normal; vgc may show Stopped until a Riot game starts)'
$vgDir = Join-Path $env:ProgramFiles 'Riot Vanguard\Logs'
$vgNote = ''
if (Test-Path $vgDir) {
  $logs = @(Get-ChildItem $vgDir -File | Sort-Object LastWriteTime -Descending | Select-Object -First 3)
  Say "  log folder: $vgDir  ($((Get-ChildItem $vgDir -File).Count) files, newest 3 below)"
  foreach ($f in $logs) {
    Say ('    {0}  {1:yyyy-MM-dd HH:mm}  {2} KB' -f $f.Name, $f.LastWriteTime, [int]($f.Length / 1KB))
    Get-Content $f.FullName -Tail 400 | Where-Object { $_ -match 'error|fail|block|denied|driver|conflict' } |
      Select-Object -Last 5 | ForEach-Object { Say ('      > ' + $_.Substring(0, [Math]::Min(150, $_.Length))) }
  }
} else { Say "  log folder not found ($vgDir) - Vanguard is probably not installed." }

# ---- 6. Sticky Keys / Filter Keys / layouts ----
Head 'Sticky Keys, Filter Keys, keyboard layouts (cause 4)'
$acc = 'HKCU:\Control Panel\Accessibility'
$flags = @{}
foreach ($n in 'StickyKeys', 'Keyboard Response', 'ToggleKeys') {
  $v = [int](Get-ItemProperty "$acc\$n").Flags
  $flags[$n] = $v
  Say ('  {0,-18} Flags={1,-4} feature is {2}; keyboard shortcut for it is {3}' -f $n, $v, $(if ($v -band 1) { 'ON' } else { 'off' }), $(if ($v -band 4) { 'enabled (e.g. 5x Shift)' } else { 'disabled' }))
}
$langs = @(Get-WinUserLanguageList)
Say ('  Language / layout list ({0}):' -f $langs.Count)
$langs | ForEach-Object { Say ('    {0}  layouts: {1}' -f $_.LanguageTag, ($_.InputMethodTips -join ', ')) }
$tipCount = ($langs | ForEach-Object { @($_.InputMethodTips).Count } | Measure-Object -Sum).Sum
$tog = Get-ItemProperty 'HKCU:\Keyboard Layout\Toggle'
Say ('  Layout-switch hotkey (1=Alt+Shift, 2=Ctrl+Shift, 3=none): {0}' -f $(if ($tog -and $tog.Hotkey) { $tog.Hotkey } else { '(not set)' }))

# ---- 7. Game Mode / Game Bar ----
Head 'Game Mode / Game Bar / fullscreen settings (cause 2, cause 1)'
function Show-Reg($path, $names) {
  $p = Get-ItemProperty $path
  foreach ($n in $names) {
    $v = if ($p -and $null -ne $p.$n) { $p.$n } else { '(not set = Windows default)' }
    Say ('  {0}\{1} = {2}' -f ($path -replace '^HKCU:', 'HKCU'), $n, $v)
  }
}
Show-Reg 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled', 'AllowAutoGameMode', 'UseNexusForGamebarEnabled', 'ShowStartupPanel'
Show-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled', 'GameDVR_FSEBehaviorMode', 'GameDVR_HonorUserFSEBehaviorMode'
Show-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled'
$layers = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'
$gameLayers = @($layers.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' -and ($_.Name -match 'league|riot|deadlock|project8' -or "$($_.Value)" -match 'DISABLEDXMAXIMIZEDWINDOWEDMODE') })
Say '  Per-program compatibility flags on game files (DISABLEDXMAXIMIZEDWINDOWEDMODE = fullscreen optimizations off):'
if ($gameLayers) { $gameLayers | ForEach-Object { Say ('    {0} = {1}' -f $_.Name, $_.Value) } } else { Say '    (none set)' }

# ---- quick read ----
$vanguardHits = @($appEv + $sysEv | Where-Object { ("$($_.ProviderName) $($_.Message)") -match 'vgc|vgk|vanguard|riot|razer|synapse|lghub|icue|wootility|rewasd' }).Count
$q = New-Object System.Collections.Generic.List[string]
if ($flags['StickyKeys'] -band 1) { $q.Add('Sticky Keys is ON (cause 4).') }
if ($flags['Keyboard Response'] -band 1) { $q.Add('Filter Keys is ON (cause 4).') }
if ($tipCount -gt 1) { $q.Add("More than one keyboard layout is installed ($tipCount) (cause 4).") }
if ($overlayHit) { $q.Add('Overlay programs running: ' + ($overlayHit -join '; ') + ' (cause 2).') }
if ($periphHit) { $q.Add('Peripheral software running: ' + ($periphHit -join '; ') + ' (cause 3, esp. with Vanguard).') }
if ($vanguardHits) { $q.Add("$vanguardHits warning/error events mention Vanguard/Riot/peripheral software (cause 3).") }
$nDev = @($devEv | Where-Object { $_.Id -eq 219 }).Count + $cfg.Count + $wd.Count
if ($nDev) { $q.Add("$nDev USB/PnP driver events in the window (cause 5).") }
if (-not $q.Count) { $q.Add('Nothing suspicious in the logs or settings. That does NOT rule out cause 1 (game bug); run Watch-Input.ps1 next.') }
Head 'QUICK READ (hints, not proof - see causes.md)'
$q | ForEach-Object { Say ('  * ' + $_) }

# ---- write + print ----
$dir = Join-Path $env:USERPROFILE 'pc-doctor'
[void](New-Item -ItemType Directory -Force -Path $dir)
$out = Join-Path $dir ('read-logs-{0:yyyyMMdd-HHmmss}.txt' -f $now)
$L | Set-Content -Path $out -Encoding UTF8
$L
Write-Host ''
Write-Host "Report saved to: $out"
