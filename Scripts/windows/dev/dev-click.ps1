param(
  [int]$X = 0, [int]$Y = 0,
  [string]$Title = "",
  [long]$Hwnd = 0,
  [switch]$Double
)
# Raw mouse click at absolute screen coordinates.
# SetForegroundWindow is usually refused by Windows (foreground lock), so the
# target is raised with SetWindowPos(TOPMOST) instead -- that always works.
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class RawInput {
  [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr v);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, UIntPtr e);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RC r);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindow(string c, string n);
  public const uint LEFTDOWN = 0x0002, LEFTUP = 0x0004;
  public const uint SWP_NOSIZE = 0x1, SWP_NOMOVE = 0x2, SWP_NOACTIVATE = 0x10;
  public static readonly IntPtr TOPMOST = new IntPtr(-1), NOTOPMOST = new IntPtr(-2);
  [StructLayout(LayoutKind.Sequential)] public struct RC { public int L,T,R,B; }
}
"@
[void][RawInput]::SetProcessDpiAwarenessContext([IntPtr]-4)

$h = [IntPtr]$Hwnd
if ($h -eq [IntPtr]::Zero -and $Title -ne "") { $h = [RawInput]::FindWindow($null, $Title) }
if ($h -ne [IntPtr]::Zero) {
  [void][RawInput]::SetWindowPos($h, [RawInput]::TOPMOST, 0, 0, 0, 0, `
    [RawInput]::SWP_NOMOVE -bor [RawInput]::SWP_NOSIZE -bor [RawInput]::SWP_NOACTIVATE)
  [void][RawInput]::SetWindowPos($h, [RawInput]::NOTOPMOST, 0, 0, 0, 0, `
    [RawInput]::SWP_NOMOVE -bor [RawInput]::SWP_NOSIZE -bor [RawInput]::SWP_NOACTIVATE)
  Start-Sleep -Milliseconds 400
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
