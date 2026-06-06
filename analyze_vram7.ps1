$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$dir = Get-Location
$file = Join-Path $dir "Trace-20260601T185457.json"

$json = Get-Content $file -Raw -Encoding UTF8 | ConvertFrom-Json
$events = $json.traceEvents

# Extract detailed GPU memory timeline with timestamps
Write-Host "=== GPU Memory Timeline with Time ==="
$t0 = 0
$first = $true
$gpuTimeline = @()

$gpuMemEvents = $events | Where-Object { $_.name -eq 'GPUTask' -and $_.args -and $_.args.data -and $_.args.data.used_bytes }

foreach ($evt in $gpuMemEvents) {
    $ts = [double]$evt.ts / 1000.0
    if ($first) { $t0 = $ts; $first = $false }
    $relTime = [Math]::Round($ts - $t0, 0)
    
    $gpuTimeline += [PSCustomObject]@{
        TimeMs = $relTime
        Pid = $evt.args.data.renderer_pid
        UsedMB = [Math]::Round([long]$evt.args.data.used_bytes / 1MB, 2)
    }
}

# Main renderer (PID 46856) VRAM over time
$mainGpu = $gpuTimeline | Where-Object { $_.Pid -eq '46856' } | Sort-Object TimeMs -Unique

Write-Host "Main renderer VRAM samples (first 30):"
$mainGpu | Select-Object -First 30 | ForEach-Object {
    Write-Host "  $($_.TimeMs)ms: $($_.UsedMB)MB"
}

# Look at UpdateLayer events
Write-Host "`n=== UpdateLayer Analysis ==="
$updateLayers = $events | Where-Object { $_.name -eq 'UpdateLayer' -and $_.args }
Write-Host "Total UpdateLayer: $($updateLayers.Count)"

# Sample with args
$layerWithArgs = $updateLayers | Where-Object { $_.args.layer }
$layerWithArgs | Select-Object -First 10 | ForEach-Object {
    $ts = [double]$_.ts / 1000.0
    $layer = $_.args.layer
    Write-Host "  ts=${ts}ms layerId=$($layer.layerId) $($layer.reason)"
}

# Check Chrome categories for raster
Write-Host "`n=== Raster/Composite Categories ==="
$rasterCat = $events | Where-Object { $_.cat -match 'cc,benchmark' }
$rasterNames = $rasterCat | Group-Object name | Sort-Object Count -Descending | Select-Object -First 20
foreach ($r in $rasterNames) {
    Write-Host "  $($r.Name): $($r.Count)"
}

# Check for pending tree activations
Write-Host "`n=== Pending Tree Events ==="
$pendingEvts = $events | Where-Object { $_.name -match 'Pending|activation' }
$pendingNames = $pendingEvts | Group-Object name | Sort-Object Count -Descending | Select-Object -First 15
foreach ($p in $pendingNames) {
    Write-Host "  $($p.Name): $($p.Count)"
}

# Check for property tree events
Write-Host "`n=== Property Tree Events ==="
$propEvts = $events | Where-Object { $_.name -match 'Property|transform|effect' }
$propNames = $propEvts | Group-Object name | Sort-Object Count -Descending | Select-Object -First 15
foreach ($p in $propNames) {
    Write-Host "  $($p.Name): $($p.Count)"
}