# RC9 — Premium Settings screen screenshot (Windows release exe)
param(
  [string]$OutDir = (Join-Path (Split-Path $PSScriptRoot -Parent) "docs\screenshots\rc1"),
  [string]$ExePath = (Join-Path (Split-Path $PSScriptRoot -Parent) "deniz_app\build\windows\x64\runner\Release\MeraSonar.exe")
)

$typeDef = @"
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Windows.Forms;
public static class MeraSonarWin {
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr hWnd, ref POINT p);
  [DllImport("user32.dll")] static extern void mouse_event(int f, int dx, int dy, int c, int e);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X; public int Y; }
  public static void StopApp() {
    foreach (var p in System.Diagnostics.Process.GetProcessesByName("MeraSonar")) {
      try { p.Kill(); } catch { }
    }
    System.Threading.Thread.Sleep(800);
  }
  public static IntPtr StartApp(string exePath) {
    var p = System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo {
      FileName = exePath,
      WorkingDirectory = System.IO.Path.GetDirectoryName(exePath),
      UseShellExecute = true
    });
    for (int i = 0; i < 40; i++) {
      System.Threading.Thread.Sleep(500);
      p.Refresh();
      if (p.MainWindowHandle != IntPtr.Zero) return p.MainWindowHandle;
    }
    throw new Exception("MeraSonar window not ready");
  }
  public static void Click(IntPtr hwnd, int cx, int cy) {
    SetForegroundWindow(hwnd);
    System.Threading.Thread.Sleep(250);
    POINT pt = new POINT { X = cx, Y = cy };
    ClientToScreen(hwnd, ref pt);
    Cursor.Position = new Point(pt.X, pt.Y);
    mouse_event(0x0002, 0, 0, 0, 0);
    mouse_event(0x0004, 0, 0, 0, 0);
  }
  public static void Capture(IntPtr hwnd, string path) {
    SetForegroundWindow(hwnd);
    System.Threading.Thread.Sleep(800);
    RECT r;
    GetWindowRect(hwnd, out r);
    int w = r.Right - r.Left, h = r.Bottom - r.Top;
    using (var bmp = new Bitmap(w, h)) {
      using (var g = Graphics.FromImage(bmp)) {
        g.CopyFromScreen(new Point(r.Left, r.Top), Point.Empty, new Size(w, h));
      }
      bmp.Save(path, ImageFormat.Png);
    }
  }
}
"@

Add-Type -TypeDefinition $typeDef -ReferencedAssemblies @("System.Drawing", "System.Windows.Forms") -ErrorAction Stop
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

if (-not (Test-Path $ExePath)) {
  Write-Error "Release exe not found: $ExePath"
  exit 1
}

[MeraSonarWin]::StopApp()
$hwnd = [MeraSonarWin]::StartApp($ExePath)
Start-Sleep -Seconds 3

# Dismiss offline modal if present
[MeraSonarWin]::Click($hwnd, 520, 430)
Start-Sleep -Seconds 1

# Sidebar Ayarlar nav item (~1280x720 layout)
$sidebarX = 120
[MeraSonarWin]::Click($hwnd, $sidebarX, 536)
Start-Sleep -Seconds 3

$path = Join-Path $OutDir "settings-premium-screen.png"
[MeraSonarWin]::Capture($hwnd, $path)
Write-Host "Saved settings-premium-screen.png ($((Get-Item $path).Length) bytes)"
