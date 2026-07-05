# RC8 - Android full QA matrix (emulator-5554)
# Uses approved PowerShell verbs to keep PSScriptAnalyzer clean.
param(
  [string]$Device = "emulator-5554",
  [string]$ApkPath = (Join-Path (Split-Path $PSScriptRoot -Parent) "deniz_app\build\app\outputs\flutter-apk\app-release.apk"),
  [string]$OutDir = (Join-Path (Split-Path $PSScriptRoot -Parent) "docs\screenshots\rc1"),
  [string]$Package = "com.example.deniz_app"
)

$ErrorActionPreference = "Stop"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

function Save-Screenshot([string]$name) {
  $fileName = if ($name.EndsWith('.png')) { $name } else { "$name.png" }
  $remote = "/sdcard/rc8-$fileName"
  $local = Join-Path $OutDir $fileName
  adb -s $Device shell screencap -p $remote | Out-Null
  adb -s $Device pull $remote $local | Out-Null
  Write-Host "Saved $fileName ($((Get-Item $local).Length) bytes)"
}

function Invoke-TextTap([string]$text) {
  adb -s $Device shell uiautomator dump /sdcard/ui.xml | Out-Null
  adb -s $Device pull /sdcard/ui.xml "$env:TEMP\rc8-ui.xml" | Out-Null
  [xml]$xml = Get-Content "$env:TEMP\rc8-ui.xml"
  $node = $xml.SelectNodes('//*') | Where-Object { $_.text -eq $text } | Select-Object -First 1
  if (-not $node) { return $false }
  if ($node.bounds -match '\[(\d+),(\d+)\]\[(\d+),(\d+)\]') {
    $x = ([int]$Matches[1] + [int]$Matches[3]) / 2
    $y = ([int]$Matches[2] + [int]$Matches[4]) / 2
    adb -s $Device shell input tap $x $y | Out-Null
    return $true
  }
  return $false
}

function Invoke-CoordinateTap([int]$x, [int]$y) {
  adb -s $Device shell input tap $x $y | Out-Null
}

Write-Host "RC8 Android QA - device $Device"

$online = adb devices | Select-String "${Device}\s+device"
if (-not $online) {
  Write-Error "Device $Device not available"
}

if (Test-Path $ApkPath) {
  adb -s $Device install -r $ApkPath | Write-Host
} else {
  Write-Warning "APK not found at $ApkPath - using existing install"
}

adb -s $Device shell am force-stop $Package
adb -s $Device shell am start -n "$Package/.MainActivity" | Out-Null
Start-Sleep -Seconds 6

# Dismiss onboarding/server modal if present
Invoke-CoordinateTap 540 1200 | Out-Null
Start-Sleep -Seconds 2

Save-Screenshot "android-dashboard.png"

# Open drawer / menu
Invoke-CoordinateTap 80 120 | Out-Null
Start-Sleep -Seconds 2

# Marine intelligence via sidebar text or coord tap
if (-not (Invoke-TextTap "Koordinat Deniz Analizi")) { Invoke-CoordinateTap 180 520 | Out-Null }
Start-Sleep -Seconds 4
Save-Screenshot "android-marine-intelligence.png"

# Back then map
adb -s $Device shell input keyevent 4 | Out-Null
Start-Sleep -Seconds 1
Invoke-CoordinateTap 80 120 | Out-Null
Start-Sleep -Seconds 1
if (-not (Invoke-TextTap "Harita")) { Invoke-CoordinateTap 180 620 | Out-Null }
Start-Sleep -Seconds 4
Save-Screenshot "android-map.png"

# Captain Atlas via dashboard card or sidebar
adb -s $Device shell input keyevent 4 | Out-Null
Start-Sleep -Seconds 1
Invoke-CoordinateTap 80 120 | Out-Null
Start-Sleep -Seconds 1
if (-not (Invoke-TextTap "Genel Bakis")) { Invoke-CoordinateTap 180 320 | Out-Null }
Start-Sleep -Seconds 2
if (-not (Invoke-TextTap "Captain'a sor")) { Invoke-CoordinateTap 540 1100 | Out-Null }
Start-Sleep -Seconds 4
Save-Screenshot "android-captain-atlas.png"

# Battery saver via performance icon (top bar)
adb -s $Device shell input keyevent 4 | Out-Null
Start-Sleep -Seconds 1
Invoke-CoordinateTap 900 100 | Out-Null
Start-Sleep -Seconds 1
Invoke-TextTap "Pil tasarrufu" | Out-Null
Start-Sleep -Seconds 1

Write-Host "RC8 Android QA capture complete."
