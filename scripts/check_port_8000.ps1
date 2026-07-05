# Check whether port 8000 is free; show owning process if not.
param(
  [int]$Port = 8000
)

$listeners = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
if (-not $listeners) {
  Write-Host "Port $Port is free."
  exit 0
}

foreach ($conn in $listeners) {
  $proc = Get-Process -Id $conn.OwningProcess -ErrorAction SilentlyContinue
  $name = if ($proc) { $proc.ProcessName } else { "unknown" }
  Write-Host "Port $Port in use - PID $($conn.OwningProcess) ($name)"
}
exit 1
