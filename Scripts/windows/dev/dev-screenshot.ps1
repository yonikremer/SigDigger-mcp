param(
  [int]$X = 0, [int]$Y = 0, [int]$W = 800, [int]$H = 600, [string]$Out = "shot.png"
)
# Screen region capture. DPI-aware so parameters are physical pixels.
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Dpi { [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr v); }
"@
[void][Dpi]::SetProcessDpiAwarenessContext([IntPtr]-4)
$bmp = New-Object System.Drawing.Bitmap $W, $H
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($X, $Y, 0, 0, $bmp.Size)
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Output "saved $Out ($W x $H at $X,$Y)"
