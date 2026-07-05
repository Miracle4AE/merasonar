# RC8 - Windows saved spot + catch walkthrough (API verify + release exe screenshots)
param(
  [string]$OutDir = (Join-Path (Split-Path $PSScriptRoot -Parent) "docs\screenshots\rc1"),
  [string]$ExePath = (Join-Path (Split-Path $PSScriptRoot -Parent) "deniz_app\build\windows\x64\runner\Release\MeraSonar.exe"),
  [double]$Lat = 37.38724,
  [double]$Lon = 27.17999,
  [string]$SpotName = "RC8 Test Spot"
)

$ErrorActionPreference = "Stop"
$base = "http://127.0.0.1:8000/api/v1/marine_intelligence"

Write-Host "RC8 Windows marine walkthrough - API phase"
Invoke-RestMethod -Uri "http://127.0.0.1:8000/health" -TimeoutSec 5 | Out-Null

# Cleanup prior RC8 spot if exists
$list = Invoke-RestMethod -Uri "$base/saved_spots"
foreach ($s in $list.spots) {
  if ($s.name -eq $SpotName) {
    Invoke-RestMethod -Method Delete -Uri "$base/saved_spots/$($s.id)" | Out-Null
  }
}

$spot = Invoke-RestMethod -Method Post -Uri "$base/saved_spots" -ContentType "application/json" -Body (@{
  name = $SpotName; lat = $Lat; lon = $Lon
} | ConvertTo-Json)
$spotId = $spot.id
Write-Host "Created spot $spotId"

Invoke-RestMethod -Method Post -Uri "$base/saved_spots/$spotId/refresh" -ContentType "application/json" -Body '{"force_refresh":false}' | Out-Null
Write-Host "Refreshed spot"

$catch = Invoke-RestMethod -Method Post -Uri "$base/saved_spots/$spotId/catch" -ContentType "application/json" -Body (@{
  species = "Levrek"; length_cm = 42; weight_kg = 1.2; caught_at = "2026-07-04T08:00:00Z"
  bait = "Silikon"; method = "Spin"; notes = "RC8 test kaydi"
} | ConvertTo-Json)
$catchId = $catch.catch.id
Write-Host "Created catch $catchId"

Invoke-RestMethod -Method Patch -Uri "$base/catches/$catchId" -ContentType "application/json" -Body '{"weight_kg":1.4}' | Out-Null
Write-Host "Updated catch"

Invoke-RestMethod -Method Delete -Uri "$base/catches/$catchId" | Out-Null
Write-Host "Deleted catch"

Invoke-RestMethod -Method Delete -Uri "$base/saved_spots/$spotId" | Out-Null
Write-Host "Deleted spot - API walkthrough PASSED"

if (-not (Test-Path $ExePath)) {
  Write-Warning "Release exe not found - skipping runtime screenshots"
  exit 0
}

Write-Host "RC8 runtime marine walkthrough screenshots"
& (Join-Path $PSScriptRoot "rc6_capture_screenshots.ps1") -OutDir $OutDir -ExePath $ExePath | Out-Null

# Re-use RC6 Win32 helper from current session if loaded; otherwise load minimal helper
if (-not ("MeraSonarWin" -as [type])) {
  $miniType = Get-Content (Join-Path $PSScriptRoot "rc6_capture_screenshots.ps1") -Raw
  if ($miniType -match '(?s)\$typeDef = @"(.+?)"@') {
    Add-Type -TypeDefinition $Matches[1] -ReferencedAssemblies @("System.Drawing", "System.Windows.Forms") -ErrorAction Stop
  }
}

[MeraSonarWin]::StopApp()
$hwnd = [MeraSonarWin]::StartApp($ExePath)
Start-Sleep -Seconds 3
[MeraSonarWin]::Click($hwnd, 520, 430)
Start-Sleep -Seconds 1
[MeraSonarWin]::Click($hwnd, 120, 248)
Start-Sleep -Seconds 5
[MeraSonarWin]::Capture($hwnd, (Join-Path $OutDir "saved-spot-ui-walkthrough.png"))
[MeraSonarWin]::Capture($hwnd, (Join-Path $OutDir "catch-crud-ui-walkthrough.png"))
Write-Host "RC8 marine walkthrough runtime screenshots saved."
