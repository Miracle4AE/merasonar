# RC1 Build9.6 — Map Calibration Confidence manual QA screenshots
param(
  [string]$OutDir = (Join-Path (Split-Path $PSScriptRoot -Parent) "docs\screenshots\rc1")
)

$ErrorActionPreference = "Stop"
$env:PATH = "C:\Users\sahin\.puro\envs\stable\flutter\bin;" + $env:PATH
$appDir = Join-Path (Split-Path $PSScriptRoot -Parent) "deniz_app"

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

Write-Host "=== RC1 Build9.6 calibration QA PNG export ==="
Push-Location $appDir
try {
  flutter test test/widget/calibration_confidence_manual_qa_test.dart --dart-define=CALIB_QA_OUT=$OutDir 2>&1
  if ($LASTEXITCODE -ne 0) { throw "flutter test export failed" }
} finally {
  Pop-Location
}

Get-ChildItem $OutDir -Filter "map-calibration-*.png" | ForEach-Object {
  Write-Host "OK $($_.Name) ($($_.Length) bytes)"
}

Write-Host "Calibration QA screenshots complete."
