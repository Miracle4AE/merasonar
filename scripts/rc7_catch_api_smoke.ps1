# RC7 - Catch CRUD API smoke (requires backend on :8000)
$ErrorActionPreference = "Stop"
$base = "http://127.0.0.1:8000/api/v1/marine_intelligence"

Write-Host "RC7 Catch CRUD API smoke - $base"

try {
  Invoke-RestMethod -Uri "http://127.0.0.1:8000/health" -TimeoutSec 5 | Out-Null
  Write-Host "Backend health: OK"
} catch {
  Write-Error "Backend not reachable on port 8000. Start with scripts/start_backend_safe.bat"
}

$spotBody = @{
  name = "RC7 Smoke Spot"
  lat = 37.0
  lon = 27.0
} | ConvertTo-Json

$spot = Invoke-RestMethod -Method Post -Uri "$base/saved_spots" -ContentType "application/json" -Body $spotBody
$spotId = $spot.id
if (-not $spotId) { throw "Spot create failed: missing id" }
Write-Host "Created spot: $spotId"

$catchBody = @{
  species = "Levrek"
  length_cm = 45.0
  weight_kg = 2.1
  caught_at = "2026-07-04T06:00:00Z"
} | ConvertTo-Json

$created = Invoke-RestMethod -Method Post -Uri "$base/saved_spots/$spotId/catch" -ContentType "application/json" -Body $catchBody
$catchId = $created.catch.id
if (-not $catchId) { throw "Catch create failed: use .catch.id not top-level .id (RC6 root cause)" }
Write-Host "Created catch: $catchId"

$list = Invoke-RestMethod -Uri "$base/saved_spots/$spotId/catches"
if ($list.catches.Count -lt 1) { throw "Catch list empty" }
Write-Host "Listed catches: $($list.catches.Count)"

$patchBody = @{ species = "Cupura"; weight_kg = 2.5 } | ConvertTo-Json
$updated = Invoke-RestMethod -Method Patch -Uri "$base/catches/$catchId" -ContentType "application/json" -Body $patchBody
Write-Host "Updated species: $($updated.catch.species)"

$deleted = Invoke-RestMethod -Method Delete -Uri "$base/catches/$catchId"
Write-Host "Deleted: $($deleted.deleted)"

Invoke-RestMethod -Method Delete -Uri "$base/saved_spots/$spotId" | Out-Null
Write-Host "RC7 Catch CRUD API smoke: PASSED"
