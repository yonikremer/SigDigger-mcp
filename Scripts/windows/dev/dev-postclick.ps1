param(
  [long]$Hwnd,
  [int]$X, [int]$Y,
  [string]$Title = ""
)
# Click a control by posting WM_LBUTTONDOWN/UP straight to the window in CLIENT
# coordinates. Works even when Windows refuses foreground activation and works on
# windows that are not the active one, which plain mouse_event cannot do.
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class PostClick {
  [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr v);
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] public static extern bool ScreenToClient(IntPtr h, ref POINT p);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindow(string c, string n);
  public const uint WM_MOUSEMOVE = 0x0200, WM_LBUTTONDOWN = 0x0201, WM_LBUTTONUP = 0x0202;
  public const int MK_LBUTTON = 0x0001;
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
  public static IntPtr LP(int x, int y) { return (IntPtr)((y << 16) | (x & 0xFFFF)); }
}
"@
[void][PostClick]::SetProcessDpiAwarenessContext([IntPtr]-4)

$h = [IntPtr]$Hwnd
if ($h -eq [IntPtr]::Zero -and $Title -ne "") { $h = [PostClick]::FindWindow($null, $Title) }
if ($h -eq [IntPtr]::Zero) { Write-Output "window not found"; exit 1 }

$p = New-Object PostClick+POINT
$p.X = $X; $p.Y = $Y
[void][PostClick]::ScreenToClient($h, [ref]$p)

[void][PostClick]::PostMessage($h, [PostClick]::WM_MOUSEMOVE, [IntPtr]::Zero, [PostClick]::LP($p.X, $p.Y))
Start-Sleep -Milliseconds 100
[void][PostClick]::PostMessage($h, [PostClick]::WM_LBUTTONDOWN, [IntPtr][PostClick]::MK_LBUTTON, [PostClick]::LP($p.X, $p.Y))
Start-Sleep -Milliseconds 120
[void][PostClick]::PostMessage($h, [PostClick]::WM_LBUTTONUP, [IntPtr]::Zero, [PostClick]::LP($p.X, $p.Y))
Write-Output "posted click at screen $X,$Y -> client $($p.X),$($p.Y)"
