$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$dir = Get-Location
$file = Join-Path $dir "Trace-20260601T185457.json"

$json = Get-Content $file -Raw -Encoding UTF8 | ConvertFrom-Json
$events = $json.traceEvents

# Extract detailed GPU memory timeline
$gpuMemEvents = $events | Where-Object { $_.name -eq 'GPUTask' -and $_.args -and $_.args.data -and $_.args.data.used_bytes }

$t0 = 0
$first = $true

$gpuByPid = @{}
foreach ($evt in $gpuMemEvents) {
    $ts = [double]$evt.ts / 1000.0
    if ($first) { $t0 = $ts; $first = $false }
    $relTime = [Math]::Round($ts - $t0, 0)
    $rendererPid = $evt.args.data.renderer_pid
    $usedMb = [Math]::Round([long]$evt.args.data.used_bytes / 1MB, 2)
    
    if (-not $gpuByPid.ContainsKey($rendererPid)) {
        $gpuByPid[$rendererPid] = @()
    }
    $gpuByPid[$rendererPid] += [PSCustomObject]@{
        TimeMs = $relTime
        UsedMB = $usedMb
    }
}

# Main renderer (PID 46856) timeline
$mainTimeline = $gpuByPid['46856'] | Sort-Object TimeMs -Unique

Write-Host "Main renderer VRAM over time (every 5000ms):"
$lastTime = 0
foreach ($pt in $mainTimeline) {
    if ($pt.TimeMs -ge $lastTime + 5000 -or $lastTime -eq 0) {
        Write-Host "  $($pt.TimeMs)ms: $($pt.UsedMB)MB"
        $lastTime = $pt.TimeMs
    }
}

# Get min/max
$minVram = ($mainTimeline | Measure-Object -Property UsedMB -Minimum).Minimum
$maxVram = ($mainTimeline | Measure-Object -Property UsedMB -Maximum).Maximum
$lastVram = ($mainTimeline[-1]).UsedMB
$firstVram = ($mainTimeline[0]).UsedMB

Write-Host ""
Write-Host "VRAM Summary: first=$firstVram MB, last=$lastVram MB, min=$minVram MB, max=$maxVram MB, growth=$([Math]::Round($lastVram - $firstVram, 2)) MB"

# Check DrawingBuffer::prepareMailbox rate
Write-Host "`n=== DrawingBuffer::prepareMailbox Analysis ==="
$dbEvts = $events | Where-Object { $_.name -eq 'DrawingBuffer::prepareMailbox' }
Write-Host "Total prepareMailbox: $($dbEvts.Count)"
if ($dbEvts.Count -gt 0) {
    $firstDb = [double]($dbEvts[0].ts) / 1000.0
    $lastDb = [double]($dbEvts[-1].ts) / 1000.0
    $duration = $lastDb - $firstDb
    Write-Host "Rate: $([Math]::Round($dbEvts.Count / $duration * 1000, 1)) per second"
}

# Check RasterTask rate
Write-Host "`n=== RasterTask Rate ==="
$rasterEvts = $events | Where-Object { $_.name -eq 'RasterTask' }
Write-Host "Total RasterTask: $($rasterEvts.Count)"

# Check if there are multiple video elements through UpdateLayer
Write-Host "`n=== Unique Layer IDs ==="
$uniqueLayerIds = $events | Where-Object { $_.name -eq 'UpdateLayer' -and $_.args -and $_.args.layer -and $_.args.layer.layerId } | 
    ForEach-Object { $_.args.layer.layerId } | Group-Object | Sort-Object Count -Descending | Select-Object -First 20
foreach ($lid in $uniqueLayerIds) {
    Write-Host "  Layer $($lid.Name): $($lid.Count) updates"
}

# Check for specific video-related events in UpdateLayer
Write-Host "`n=== UpdateLayer Args Sample ==="
$updateLayers = $events | Where-Object { $_.name -eq 'UpdateLayer' -and $_.args }
$updateLayers | Select-Object -First 20 | ForEach-Object {
    $ts = [double]$_.ts / 1000.0
    $argsJson = $_.args | ConvertTo-Json -Compress -Depth 5
    if ($argsJson.Length -gt 150) { $argsJson = $argsJson.Substring(0, 150) + "..." }
    Write-Host "  ts=${ts}ms args=$argsJson"
}