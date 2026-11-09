param(
  [int]$X = 0, [int]$Y = 0,
  [int]$RelX = -1, [int]$RelY = -1,
  [string]$Title = "",
  [long]$Hwnd = 0,
  [switch]$Double
)
# Raw mouse click. DPI-aware so coordinates are physical pixels.
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class RawInput {
  [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr v);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, UIntPtr e);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RC r);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindow(string c, string n);
  public const uint LEFTDOWN = 0x0002, LEFTUP = 0x0004;
  [StructLayout(LayoutKind.Sequential)] public struct RC { public int L,T,R,B; }
}
"@
[void][RawInput]::SetProcessDpiAwarenessContext([IntPtr]-4)

$h = [IntPtr]$Hwnd
if ($h -eq [IntPtr]::Zero -and $Title -ne "") { $h = [RawInput]::FindWindow($null, $Title) }
if ($h -ne [IntPtr]::Zero) {
  [void][RawInput]::SetForegroundWindow($h)
  Start-Sleep -Milliseconds 400
}

if ($RelX -ge 0) {
  $r = New-Object RawInput+RC
  [void][RawInput]::GetWindowRect($h, [ref]$r)
  $X = $r.L + $RelX
  $Y = $r.T + $RelY
  Write-Output "rect=$($r.L),$($r.T) size $($r.R-$r.L)x$($r.B-$r.T) -> click $X,$Y"
}

[void][RawInput]::SetCursorPos($X, $Y)
Start-Sleep -Milliseconds 200
$times = if ($Double) { 2 } else { 1 }
for ($i = 0; $i -lt $times; $i++) {
  [RawInput]::mouse_event([RawInput]::LEFTDOWN, 0, 0, 0, [UIntPtr]::Zero)
  [RawInput]::mouse_event([RawInput]::LEFTUP, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 150
}
Write-Output "clicked $X,$Y"
