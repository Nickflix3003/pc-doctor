<#
.SYNOPSIS
  pc-doctor step 2 (optional, only if you agree): record WHEN the keyboard stops reaching Windows.
.DESCRIPTION
  WHAT IS RECORDED (one local CSV: %USERPROFILE%\pc-doctor\watch-<stamp>.csv - it never leaves this PC):
    fg      the program name (and window title, unless -NoTitles) each time the foreground window changes
    keys    once per second: HOW MANY keys were pressed in that second, plus the foreground program name.
            COUNTS ONLY. Which key was pressed is never written to the file or shown on screen. THIS IS NOT A KEYLOGGER.
            (To count a held key once, it remembers which keys are down right now. That list stays in memory, is overwritten every 250 ms and is gone when it stops.)
    device  a keyboard device plugged in or removed (name + device id), or "change-event" when Windows
            reported any device change (not only keyboards) - a timing clue even if the keyboard list looks the same
    marker  the moment you pressed the marker key (default Pause/Break) or clicked the optional marker window
    start / stop   when the monitor began and ended
  HOW IT WORKS (built to be safe next to anti-cheat such as Riot Vanguard):
    Polling only: GetForegroundWindow / GetAsyncKeyState every 250 ms, and a list of present keyboards.
    NO keyboard hooks, NO injection, NO reading any game's memory, NO handle opened to any game process.
    Nothing is sent over the network. Nothing is installed or changed.
.PARAMETER Minutes
  Stop after this many minutes (fractions ok). Default 0 = run until you press Ctrl+C in this window.
.PARAMETER MarkerKey
  Key that means "it just happened": Pause (default), ScrollLock, Insert or F12.
.PARAMETER NoWindow
  The default, accepted for clarity: no window is ever shown.
.PARAMETER MarkerWindow
  OPT-IN: show a tiny always-on-top "It just happened" button you can click with the mouse
  (the keyboard may be the dead part). Never takes focus. Needs the game in borderless/windowed mode to be visible.
.PARAMETER NoTitles
  Record only program names, not window titles (titles can include chat or tab names).
#>
[CmdletBinding()]
param(
  [double]$Minutes = 0,
  [ValidateSet('Pause', 'ScrollLock', 'Insert', 'F12')][string]$MarkerKey = 'Pause',
  [switch]$NoWindow,
  [switch]$MarkerWindow,
  [switch]$NoTitles
)
$ErrorActionPreference = 'Stop'
if ($NoWindow -and $MarkerWindow) { throw '-NoWindow and -MarkerWindow cannot be used together.' }

if (-not ('PcDoctor.Native' -as [type])) {
  $refs = @()
  if ($MarkerWindow) { $refs = 'System.Windows.Forms', 'System.Drawing' }
  $src = @'
using System; using System.Text; using System.Runtime.InteropServices;
namespace PcDoctor {
  public static class Native {
    [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] static extern int GetWindowThreadProcessId(IntPtr h, out int pid);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowText(IntPtr h, StringBuilder sb, int max);
    [DllImport("user32.dll")] static extern short GetAsyncKeyState(int vk);
    static bool[] prev = new bool[256];
    public static bool IsDown(int vk) { return (GetAsyncKeyState(vk) & 0x8000) != 0; }
    // Returns ONLY how many keys went down since the last call. The up/down table above stays in memory, is overwritten every poll and is never returned or written.
    public static int CountNewKeyDowns(int skipVk) {
      int n = 0;
      for (int vk = 8; vk < 255; vk++) {
        if (vk == skipVk || vk == 0x10 || vk == 0x11 || vk == 0x12) continue; // marker key; generic Shift/Ctrl/Alt (L/R variants counted)
        short s = GetAsyncKeyState(vk);
        bool down = (s & 0x8000) != 0;
        if ((down || (s & 1) != 0) && !prev[vk]) n++;   // low bit catches taps shorter than one poll
        prev[vk] = down;
      }
      return n;
    }
    public static void Foreground(out int pid, out string title) {
      IntPtr h = GetForegroundWindow(); pid = 0; title = "";
      if (h == IntPtr.Zero) return;
      GetWindowThreadProcessId(h, out pid);
      StringBuilder sb = new StringBuilder(256); GetWindowText(h, sb, 256); title = sb.ToString();
    }
  }
'@
  if ($MarkerWindow) {
    $src += @'
  public class MarkerForm : System.Windows.Forms.Form {
    public bool Clicked;
    protected override bool ShowWithoutActivation { get { return true; } }
    protected override System.Windows.Forms.CreateParams CreateParams {
      get { var cp = base.CreateParams; cp.ExStyle |= 0x08000000 | 0x8; return cp; }   // NOACTIVATE | TOPMOST
    }
    public MarkerForm() {
      FormBorderStyle = System.Windows.Forms.FormBorderStyle.FixedToolWindow; ShowInTaskbar = false; TopMost = true;
      Width = 190; Height = 80; Text = "pc-doctor"; StartPosition = System.Windows.Forms.FormStartPosition.Manual;
      var r = System.Windows.Forms.Screen.PrimaryScreen.WorkingArea; Location = new System.Drawing.Point(r.Right - Width - 10, r.Bottom - Height - 10);
      var b = new System.Windows.Forms.Button(); b.Text = "It just happened"; b.Dock = System.Windows.Forms.DockStyle.Fill;
      b.Click += delegate { Clicked = true; }; Controls.Add(b);
    }
  }
'@
  }
  $src += '}'
  Add-Type -TypeDefinition $src -ReferencedAssemblies $refs
}

$vkMap = @{ Pause = 0x13; ScrollLock = 0x91; Insert = 0x2D; F12 = 0x7B }
$markerVk = $vkMap[$MarkerKey]
$dir = Join-Path $env:USERPROFILE 'pc-doctor'
[void](New-Item -ItemType Directory -Force -Path $dir)
$csv = Join-Path $dir ('watch-{0:yyyyMMdd-HHmmss}.csv' -f (Get-Date))
$fs = New-Object System.IO.FileStream($csv, 'Append', 'Write', 'ReadWrite')
$w = New-Object System.IO.StreamWriter($fs, (New-Object System.Text.UTF8Encoding($false)))
$w.AutoFlush = $true
function Row([string]$type, [string]$detail = '', [string]$value = '') {
  $q = { param($s) '"' + ($s -replace '"', '""') + '"' }
  $w.WriteLine(('{0:yyyy-MM-dd HH:mm:ss.fff},{1},{2},{3}' -f (Get-Date), $type, (& $q $detail), (& $q $value)))
}
function Get-Kbd { @(Get-PnpDevice -Class Keyboard -PresentOnly -ErrorAction SilentlyContinue | ForEach-Object { "$($_.InstanceId)|$($_.FriendlyName)" }) }

$form = $null
if ($MarkerWindow) { $form = New-Object PcDoctor.MarkerForm; $form.Show() }

$w.WriteLine('time,type,detail,value')
Row 'start' "marker=$MarkerKey window=$([bool]$MarkerWindow) titles=$(-not $NoTitles)" "poll=250ms minutes=$Minutes"
Write-Host "pc-doctor monitor running. Recording counts only (not which keys) to: $csv"
Write-Host "Play as normal. When the keyboard dies, press $MarkerKey$(if ($MarkerWindow) { ' or click the small window' }). Stop with Ctrl+C."

$known = Get-Kbd
$subscribed = $false
try { Register-WmiEvent -Class Win32_DeviceChangeEvent -SourceIdentifier PcDoctorDev | Out-Null; $subscribed = $true } catch { Row 'note' 'device-event subscription failed; using timed diff only' }
$deadline = if ($Minutes -gt 0) { (Get-Date).AddMinutes($Minutes) } else { $null }
$sw = [Diagnostics.Stopwatch]::StartNew()
$nextSec = 1000; $nextDiff = 30000; $count = 0
$lastPid = -1; $lastName = ''; $markerHeld = $false; $rows = 0

try {
  while (-not $deadline -or (Get-Date) -lt $deadline) {
    $count += [PcDoctor.Native]::CountNewKeyDowns($markerVk)

    $fpid = 0; $title = ''
    [PcDoctor.Native]::Foreground([ref]$fpid, [ref]$title)
    if ($fpid -ne $lastPid) {
      $proc = try { [Diagnostics.Process]::GetProcesses() | Where-Object { $_.Id -eq $fpid } | Select-Object -First 1 } catch { $null }   # system process snapshot: no handle to the game is opened
      $name = if ($proc) { $proc.ProcessName } else { '?' }
      Row 'fg' $name $(if ($NoTitles) { '' } else { $title })
      $lastPid = $fpid; $lastName = $name
    }

    $down = [PcDoctor.Native]::IsDown($markerVk)
    $click = $false
    if ($form) { [System.Windows.Forms.Application]::DoEvents(); if ($form.Clicked) { $form.Clicked = $false; $click = $true } }
    if (($down -and -not $markerHeld) -or $click) { Row 'marker' $(if ($click) { 'window' } else { $MarkerKey }) $lastName; Write-Host ('{0:HH:mm:ss} marker recorded' -f (Get-Date)) }
    $markerHeld = $down

    $devEvt = $subscribed -and (Get-Event -SourceIdentifier PcDoctorDev -ErrorAction SilentlyContinue)
    if ($devEvt -or $sw.ElapsedMilliseconds -ge $nextDiff) {
      if ($devEvt) { Row 'device' 'change-event' ''; Get-Event -SourceIdentifier PcDoctorDev | Remove-Event }
      $nextDiff = $sw.ElapsedMilliseconds + 30000
      $now = Get-Kbd
      foreach ($d in $now) { if ($known -notcontains $d) { Row 'device' 'arrived' $d } }
      foreach ($d in $known) { if ($now -notcontains $d) { Row 'device' 'removed' $d } }
      $known = $now
    }

    if ($sw.ElapsedMilliseconds -ge $nextSec) {
      Row 'keys' $lastName "$count"; $rows++
      $count = 0; $nextSec = $sw.ElapsedMilliseconds - ($sw.ElapsedMilliseconds % 1000) + 1000
    }
    Start-Sleep -Milliseconds 250
  }
}
finally {
  Row 'stop' '' "$rows seconds recorded"
  if ($subscribed) { Unregister-Event -SourceIdentifier PcDoctorDev -ErrorAction SilentlyContinue }
  if ($form) { $form.Close() }
  $w.Dispose()
  Write-Host "Stopped. Saved: $csv"
}
