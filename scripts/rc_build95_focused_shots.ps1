# RC1 Build9.5 — focused screenshots (CI exe, map back → home/settings/atlas)
param(
  [string]$ExePath = (Join-Path (Split-Path $PSScriptRoot -Parent) "ci_artifacts_build95\MeraSonar-windows-release\MeraSonar.exe"),
  [string]$OutDir = (Join-Path (Split-Path $PSScriptRoot -Parent) "docs\screenshots\rc1\build95-smoke")
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
    System.Threading.Thread.Sleep(300);
    POINT pt = new POINT { X = cx, Y = cy };
    ClientToScreen(hwnd, ref pt);
    Cursor.Position = new Point(pt.X, pt.Y);
    mouse_event(0x0002, 0, 0, 0, 0);
    mouse_event(0x0004, 0, 0, 0, 0);
  }
  public static void Capture(IntPtr hwnd, string path) {
    SetForegroundWindow(hwnd);
    System.Threading.Thread.Sleep(900);
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

function GoHome($h) {
  [MeraSonarWin]::Click($h, 55, 98)
  Start-Sleep -Seconds 2
}

function Shot($name, [scriptblock]$Nav) {
  [MeraSonarWin]::StopApp()
  $hwnd = [MeraSonarWin]::StartApp($ExePath)
  [MeraSonarWin]::Maximize($hwnd)
  Start-Sleep -Seconds 4
  [MeraSonarWin]::Click($hwnd, 520, 430)
  Start-Sleep -Seconds 1
  GoHome $hwnd
  & $Nav $hwnd
  Start-Sleep -Seconds 3
  $path = Join-Path $OutDir "$name.png"
  [MeraSonarWin]::Capture($hwnd, $path)
  Write-Host "Saved $name ($((Get-Item $path).Length) bytes)"
}

try {
  Shot "win-dashboard" { param($h) }
  Shot "win-settings" { param($h)
    [MeraSonarWin]::Click($h, 120, 580)
  }
  Shot "win-settings-gear" { param($h)
    [MeraSonarWin]::Click($h, 1185, 48)
  }
  Shot "win-map" { param($h)
    [MeraSonarWin]::Click($h, 120, 340)
  }
  Shot "win-hotspot-detail" { param($h)
    [MeraSonarWin]::Click($h, 120, 340)
    Start-Sleep -Seconds 4
    [MeraSonarWin]::Click($h, 280, 720)
  }
  Shot "win-captain-atlas" { param($h)
    [MeraSonarWin]::Click($h, 115, 668)
  }
  Shot "win-captain-atlas-map-dock" { param($h)
    [MeraSonarWin]::Click($h, 120, 340)
    Start-Sleep -Seconds 3
    [MeraSonarWin]::Click($h, 980, 680)
  }
} finally {
  [MeraSonarWin]::StopApp()
}

Write-Host "Focused shots complete."
