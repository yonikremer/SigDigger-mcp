param([string]$Keys = "")
# Send keystrokes to the focused window (SendKeys syntax, e.g. "^a0{ENTER}").
Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Dpi2 { [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr v); }
"@
[void][Dpi2]::SetProcessDpiAwarenessContext([IntPtr]-4)
[System.Windows.Forms.SendKeys]::SendWait($Keys)
Write-Output "sent $Keys"
