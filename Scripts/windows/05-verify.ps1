# SigDigger Windows verification suite.
#
# Upstream ships no automated tests (sigutils registers 0 CTest tests, suscan has
# no CTest file, SigDigger has no test target), so this exercises the installed
# artifact the way a user does: files present, self-contained runtime, SoapySDR
# modules load, GUI window fits the screen, window controls work, full screen
# toggles both ways.
#
# Usage: powershell -NoProfile -File 05-verify.ps1 [-InstallDir "C:\Program Files\SigDigger"]
# Exit code = number of failed checks.

param(
  [string]$InstallDir = "C:\Program Files\SigDigger",
  [string]$Msys = "C:\msys64\usr\bin\bash.exe"
)

$ErrorActionPreference = "Continue"
$script:fail = 0
$script:pass = 0
$script:hwnd = [IntPtr]::Zero
$tmp = Join-Path $env:TEMP ("sigdigger-verify-" + $PID)

function Check($name, [scriptblock]$test) {
  try {
    $detail = & $test
    if ($detail -eq $false) { throw "returned false" }
    Write-Output ("PASS  $name" + $(if ($detail) { "  ($detail)" } else { "" }))
    $script:pass++
  } catch {
    Write-Output ("FAIL  $name  -- " + $_.Exception.Message)
    $script:fail++
  }
}

# Native commands write logs to stderr; PS would turn that into error records.
# Capture both streams through a file instead.
function RunNative([string]$exe, [string[]]$argv) {
  $outFile = "$tmp.out"
  $errFile = "$tmp.err"
  $params = @{
    FilePath               = $exe
    NoNewWindow            = $true
    Wait                   = $true
    PassThru               = $true
    RedirectStandardOutput = $outFile
    RedirectStandardError  = $errFile
  }
  if ($argv -and $argv.Count -gt 0) { $params.ArgumentList = $argv }
  $p = Start-Process @params
  $out = ""
  if (Test-Path $outFile) { $out += (Get-Content $outFile -Raw) }
  if (Test-Path $errFile) { $out += (Get-Content $errFile -Raw) }
  return @{ code = $p.ExitCode; text = $out }
}

function Get-SigDiggerWindow() {
  # The splash screen is also titled "SigDigger"; the real window carries the
  # source description, and only that one reports a usable frame.
  for ($i = 0; $i -lt 60; $i++) {
    foreach ($proc in @(Get-Process SigDigger -ErrorAction SilentlyContinue)) {
      if ($proc.MainWindowHandle -eq 0) { continue }
      if ($proc.MainWindowTitle -notlike "SigDigger -*") { continue }
      $r = [V]::Rect($proc.MainWindowHandle)
      if (($r.R - $r.L) -gt 100 -and ($r.B - $r.T) -gt 100) { return $proc.MainWindowHandle }
    }
    Start-Sleep -Milliseconds 500
  }
  return [IntPtr]::Zero
}

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class V {
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RC r);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr a, int x, int y, int cx, int cy, uint f);
  public static readonly IntPtr TOPMOST = new IntPtr(-1), NOTOPMOST = new IntPtr(-2);
  [StructLayout(LayoutKind.Sequential)] public struct RC { public int L,T,R,B; }
  public static RC Rect(IntPtr h) { RC r; GetWindowRect(h, out r); return r; }
  public static int Width(RC r) { return r.R - r.L; }
}
"@
Add-Type -AssemblyName System.Windows.Forms

$exe    = Join-Path $InstallDir "SigDigger.exe"
$suscli = Join-Path $InstallDir "suscli.exe"
$screen = [System.Windows.Forms.Screen]::PrimaryScreen
$work   = $screen.WorkingArea
$bounds = $screen.Bounds

Write-Output "SigDigger Windows verification"
Write-Output ("install:  " + $InstallDir)
Write-Output ("screen:   " + $bounds.Width + "x" + $bounds.Height + " (work area " + $work.Width + "x" + $work.Height + ")")
Write-Output ""

# ---------------------------------------------------------------- install bits

Check "exe present" { Test-Path $exe }
Check "suscli present" { Test-Path $suscli }
Check "uninstaller present" { Test-Path (Join-Path $InstallDir "uninstall.exe") }

Check "runtime libs present" {
  $need = @("suwidgets0.dll", "libsuscan.dll", "libsigutils.dll", "Qt6Core.dll", "Qt6Widgets.dll")
  $missing = $need | Where-Object { -not (Test-Path (Join-Path $InstallDir $_)) }
  if ($missing) { throw ("missing: " + ($missing -join ", ")) }
  ($need.Count.ToString() + " libs")
}

Check "suscan config bundled next to exe" {
  $cfg = Join-Path $InstallDir "config"
  if (-not (Test-Path $cfg)) { throw "no config dir" }
  $need = @("autogains.yaml", "palettes.yaml", "frequency_allocations.yaml")
  $missing = $need | Where-Object { -not (Test-Path (Join-Path $cfg $_)) }
  if ($missing) { throw ("missing: " + ($missing -join ", ")) }
  "config db present"
}

Check "SoapySDR modules bundled next to exe" {
  $mods = Join-Path $InstallDir "modules0.8"
  if (-not (Test-Path $mods)) { throw "no modules0.8 dir" }
  $n = (Get-ChildItem $mods -Filter *.dll | Measure-Object).Count
  if ($n -lt 1) { throw "no module dlls" }
  ($n.ToString() + " modules")
}

Check "uninstall registry entry" {
  Test-Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\SigDigger"
}

Check "start menu shortcut" {
  $lnk = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\SigDigger\SigDigger.lnk"
  if (-not (Test-Path $lnk)) { throw "missing $lnk" }
  "SigDigger.lnk"
}

Check "desktop shortcut" {
  $lnk = Join-Path ([Environment]::GetFolderPath('Desktop')) "SigDigger.lnk"
  if (-not (Test-Path $lnk)) { throw "missing $lnk" }
  "SigDigger.lnk"
}

# ------------------------------------------------------- self-contained runtime
# PATH is cut down to the Windows system dirs: nothing from MSYS2 may be needed.

$cleanPath = "$env:SystemRoot\system32;$env:SystemRoot"
$oldPath   = $env:PATH

Check "suscli runs without MSYS2 on PATH" {
  $env:PATH = $cleanPath
  $r = RunNative $suscli @("list")
  if ($r.text -notmatch "Command list") { throw ("unexpected output: " + $r.text) }
  if ($r.text -notmatch "devices") { throw "devices command missing" }
  "commands listed"
}

Check "suscli reports suscan/sigutils version" {
  $env:PATH = $cleanPath
  $r = RunNative $suscli @()
  if ($r.text -notmatch "suscan 0\.3\.0") { throw "suscan version not reported" }
  if ($r.text -notmatch "sigutils version 0\.3\.0") { throw "sigutils version not reported" }
  "suscan 0.3.0 / sigutils 0.3.0"
}

Check "SoapySDR device scan runs cleanly" {
  $env:PATH = $cleanPath
  $r = RunNative $suscli @("devices")
  if ($r.text -match "(?i)failed to (load|open)|exception in") { throw ($r.text.Trim()) }
  if ($r.text -notmatch "Device name") { throw ("no device table: " + $r.text.Trim()) }
  "device table rendered"
}

Check "no unresolved DLL imports in the bundle" {
  $env:PATH = $oldPath
  $bashFile = "$tmp.sh"
  $dir = $InstallDir.Replace('\','/')
  $bash = @"
cd '$dir' || exit 1
bad=0
for f in SigDigger.exe suscli.exe *.dll modules0.8/*.dll platforms/*.dll; do
  [ -f "`$f" ] || continue
  ldd "`$f" 2>/dev/null | grep '=> not found' | while read -r line; do
    echo "MISSING: `$f -> `$line"
  done
  if ldd "`$f" 2>/dev/null | grep -q '=> not found'; then bad=1; fi
done
exit `$bad
"@
  Set-Content -Path $bashFile -Value $bash -Encoding ASCII
  $r = RunNative $Msys @("-c", $bashFile.Replace('\','/'))
  if ($r.code -ne 0) { throw ($r.text.Trim()) }
  "all imports resolve"
}

# --------------------------------------------------------------------- the GUI

Check "GUI launches and window fits the screen" {
  $env:PATH = $oldPath
  Get-Process SigDigger -ErrorAction SilentlyContinue | Stop-Process -Force
  Start-Sleep 2
  Start-Process -FilePath $exe | Out-Null
  $h = Get-SigDiggerWindow
  if ($h -eq [IntPtr]::Zero) { throw "window never appeared" }
  $script:hwnd = $h
  Start-Sleep 2
  $r = [V]::Rect($h)
  if ([V]::Width($r) -le 0) { throw "invalid window rect" }
  if ($r.T -lt 0) { throw ("title bar above screen: top=" + $r.T) }
  if ($r.T -gt 150) { throw ("window pushed too low: top=" + $r.T) }
  if ($r.B -gt ($bounds.Height + 20)) { throw ("window taller than screen: bottom=" + $r.B) }
  ("frame " + $r.L + "," + $r.T + " " + [V]::Width($r) + "x" + ($r.B - $r.T))
}

Check "minimize and restore work" {
  $h = $script:hwnd
  if ($h -eq [IntPtr]::Zero) { throw "no window handle" }
  [void][V]::ShowWindow($h, 6)
  Start-Sleep 1
  $mini = [V]::IsIconic($h)
  [void][V]::ShowWindow($h, 9)
  Start-Sleep 2
  if (-not $mini) { throw "window did not minimize" }
  if ([V]::IsIconic($h)) { throw "window did not restore" }
  "minimized and restored"
}

Check "full screen toggles both ways (F11)" {
  $h = $script:hwnd
  if ($h -eq [IntPtr]::Zero) { throw "no window handle" }
  [void][V]::SetWindowPos($h, [V]::TOPMOST, 0, 0, 0, 0, 3)
  [void][V]::SetWindowPos($h, [V]::NOTOPMOST, 0, 0, 0, 0, 3)
  Start-Sleep 1

  $covers = {
    param($r)
    (($r.R - $r.L) -ge ($bounds.Width - 20)) -and (($r.B - $r.T) -ge ($bounds.Height - 20))
  }

  $before = [V]::Rect($h)
  if (& $covers $before) { throw "window already covers the screen before F11" }

  [System.Windows.Forms.SendKeys]::SendWait('{F11}')
  Start-Sleep 2
  $full = [V]::Rect($h)

  [System.Windows.Forms.SendKeys]::SendWait('{F11}')
  Start-Sleep 2
  $back = [V]::Rect($h)

  if (-not (& $covers $full)) {
    throw ("F11 did not go full screen: " + ($full.R - $full.L) + "x" + ($full.B - $full.T))
  }
  if (& $covers $back) {
    throw ("second F11 did not leave full screen: " + ($back.R - $back.L) + "x" + ($back.B - $back.T))
  }
  ("windowed " + ($before.R - $before.L) + "x" + ($before.B - $before.T) +
   " -> full " + ($full.R - $full.L) + "x" + ($full.B - $full.T) +
   " -> windowed " + ($back.R - $back.L) + "x" + ($back.B - $back.T))
}

Get-Process SigDigger -ErrorAction SilentlyContinue | Stop-Process -Force
$env:PATH = $oldPath
Remove-Item "$tmp.*" -ErrorAction SilentlyContinue

Write-Output ""
Write-Output ("passed " + $script:pass + ", failed " + $script:fail)
exit $script:fail
