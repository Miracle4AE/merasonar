# RC1 Build9.5 — Windows device smoke (CI artifact)
param(
  [string]$ExePath = (Join-Path (Split-Path $PSScriptRoot -Parent) "ci_artifacts_build95\MeraSonar-windows-release\MeraSonar.exe"),
  [string]$OutDir = (Join-Path (Split-Path $PSScriptRoot -Parent) "docs\screenshots\rc1\build95-smoke")
)

$ErrorActionPreference = "Stop"
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
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
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
  public static void Maximize(IntPtr hwnd) {
    SetForegroundWindow(hwnd);
    ShowWindow(hwnd, 3);
    System.Threading.Thread.Sleep(600);
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

if (-not (Test-Path -LiteralPath $ExePath)) { throw "Exe not found: $ExePath" }

$results = @{}
function Shot($name, [scriptblock]$Nav) {
  [MeraSonarWin]::StopApp()
  $hwnd = [MeraSonarWin]::StartApp($ExePath)
  [MeraSonarWin]::Maximize($hwnd)
  Start-Sleep -Seconds 4
  [MeraSonarWin]::Click($hwnd, 520, 430)
  Start-Sleep -Seconds 1
  & $Nav $hwnd
  Start-Sleep -Seconds 3
  $path = Join-Path $OutDir "$name.png"
  [MeraSonarWin]::Capture($hwnd, $path)
  $results[$name] = $true
  Write-Host "OK $name ($((Get-Item $path).Length) bytes)"
}

$sidebarX = 120
try {
  # App may restore last route (Map); return to dashboard first.
  Shot "01-launch-dashboard" { param($h) [MeraSonarWin]::Click($h, $sidebarX, 152) }
  # Premium Settings — header gear (maximized ~1280x720)
  Shot "02-settings" { param($h)
    [MeraSonarWin]::Click($h, $sidebarX, 152)
    Start-Sleep -Seconds 2
    [MeraSonarWin]::Click($h, 1185, 48)
  }
  # Map via sidebar Harita
  Shot "03-map" { param($h)
    [MeraSonarWin]::Click($h, $sidebarX, 152)
    Start-Sleep -Seconds 2
    [MeraSonarWin]::Click($h, $sidebarX, 340)
  }
  Shot "04-map-hotspot-strip" { param($h)
    [MeraSonarWin]::Click($h, $sidebarX, 340)
    Start-Sleep -Seconds 4
    [MeraSonarWin]::Click($h, 280, 720)
  }
  # Captain Atlas Command Center — sidebar bottom CTA from dashboard
  Shot "05-captain-atlas" { param($h)
    [MeraSonarWin]::Click($h, $sidebarX, 152)
    Start-Sleep -Seconds 2
    [MeraSonarWin]::Click($h, 115, 668)
  }

  $proc = Get-Process -Name MeraSonar -ErrorAction SilentlyContinue
  if ($proc -and -not $proc.HasExited) {
    $results["crash"] = $false
    Write-Host "Process alive after smoke"
  }
} catch {
  Write-Host "FAIL: $_"
  $results["error"] = $_.Exception.Message
  exit 1
} finally {
  [MeraSonarWin]::StopApp()
}

Write-Host "Build9.5 Windows smoke complete: $($results.Count) shots"
