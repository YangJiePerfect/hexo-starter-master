$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$dir = Get-Location
$file = Join-Path $dir "Trace-20260601T185457.json"

$json = Get-Content $file -Raw -Encoding UTF8 | ConvertFrom-Json
$events = $json.traceEvents

# GPU Memory Timeline
Write-Host "=== GPU Memory Analysis ==="
$t0 = [double]($events[0].ts) / 1000.0

$gpuEvents = $events | Where-Object { $_.name -eq 'GPUTask' -and $_.args -and $_.args.data -and $_.args.data.used_bytes }

$vramTimeline = foreach ($evt in $gpuEvents) {
    [PSCustomObject]@{
        TimeMs = [Math]::Round(($_ts = [double]$evt.ts / 1000.0) - $t0, 0)
        Pid = $evt.args.data.renderer_pid
        UsedMB = [Math]::Round([long]$evt.args.data.used_bytes / 1MB, 2)
    }
}

$pids = $vramTimeline | Select-Object -ExpandProperty Pid -Unique
foreach ($rendererId in $pids) {
    $samples = $vramTimeline | Where-Object { $_.Pid -eq $rendererId }
    $first = ($samples | Measure-Object -Property UsedMB -Minimum).Minimum
    $last = ($samples | Measure-Object -Property UsedMB -Maximum).Maximum
    Write-Host "PID $rendererId : $($samples.Count) samples, min=$first MB, max=$last MB"
}

# UpdateLayer Analysis - check unique layer IDs
Write-Host "`n=== UpdateLayer Events ==="
$updateLayers = $events | Where-Object { $_.name -eq 'UpdateLayer' -and $_.args -and $_.args.layer }
$totalUpdateLayers = ($events | Where-Object { $_.name -eq 'UpdateLayer' }).Count
Write-Host "Total UpdateLayer: $totalUpdateLayers"

$layerIds = $updateLayers | Select-Object -ExpandProperty args | ForEach-Object { $_.layer.layerId } | Group-Object | Sort-Object Count -Descending | Select-Object -First 10
foreach ($lid in $layerIds) {
    Write-Host "  Layer $($lid.Name): $($lid.Count) updates"
}

# DrawingBuffer events
Write-Host "`n=== DrawingBuffer Events ==="
$dbEvents = ($events | Where-Object { $_.name -eq 'DrawingBuffer::prepareMailbox' }).Count
Write-Host "DrawingBuffer::prepareMailbox: $dbEvents"

# RasterTask
Write-Host "`n=== RasterTask Events ==="
$rasterEvents = ($events | Where-Object { $_.name -eq 'RasterTask' }).Count
Write-Host "RasterTask: $rasterEvents"

# Video events
Write-Host "`n=== Video Events ==="
$videoEvents = $events | Where-Object { $_.name -match 'Video|Media|Demux|Demuxer|Audio|picture' -or $_.cat -eq 'media' }
$videoNames = $videoEvents | Group-Object name | Sort-Object Count -Descending | Select-Object -First 20
foreach ($v in $videoNames) {
    Write-Host "  $($v.Name): $($v.Count)"
}

# Check for navigation/refresh patterns
Write-Host "`n=== Navigation Events ==="
$navEvents = $events | Where-Object { $_.name -match 'Navigate|Load|FrameNavigate|DidFinishLoad' -or $_.cat -eq 'loading' -or $_.cat -eq 'navigation' }
$navNames = $navEvents | Group-Object name | Sort-Object Count -Descending | Select-Object -First 15
foreach ($n in $navNames) {
    Write-Host "  $($n.Name): $($n.Count)"
}

# Memory pressure check
Write-Host "`n=== Memory Pressure Indicators ==="
$pressureEvts = $events | Where-Object { $_.args -and ($_.args.toString() -match 'low|pressure|memory|throttle|oom' -or $_.name -match 'Memory|pressure') }
$pressureNames = $pressureEvts | Group-Object name | Sort-Object Count -Descending | Select-Object -First 10
foreach ($p in $pressureNames) {
    Write-Host "  $($p.Name): $($p.Count)"
}