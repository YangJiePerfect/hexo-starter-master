$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$dir = Get-Location
$file = Join-Path $dir "Trace-20260601T101911.json"

$json = Get-Content $file -Raw -Encoding UTF8 | ConvertFrom-Json
$events = $json.traceEvents

# Extract GPU memory timeline from GPUTask events
Write-Host "=== GPU Memory Timeline (from GPUTask) ==="
$t0 = 0
$first = $true
$gpuMemByPid = @{}

$gpuTasks = $events | Where-Object { $_.name -eq 'GPUTask' -and $_.args -and $_.args.data }

foreach ($task in $gpuTasks) {
    $ts = [double]$task.ts / 1000.0
    if ($first) { $t0 = $ts; $first = $false }
    $relTime = $ts - $t0
    
    $renderPid = $task.args.data.renderer_pid
    $bytes = [long]$task.args.data.used_bytes
    
    if (-not $gpuMemByPid.ContainsKey($renderPid)) {
        $gpuMemByPid[$renderPid] = [System.Collections.ArrayList]::new()
    }
    [void]$gpuMemByPid[$renderPid].Add([PSCustomObject]@{
        TimeMs = $relTime
        UsedBytes = $bytes
        UsedMB = [Math]::Round($bytes / 1MB, 2)
    })
}

Write-Host "GPU renderer processes:"
foreach ($renderPid in $gpuMemByPid.Keys) {
    $data = $gpuMemByPid[$renderPid]
    $firstPt = $data[0]
    $lastPt = $data[$data.Count - 1]
    $maxBytes = ($data | Measure-Object -Property UsedBytes -Maximum).Maximum
    $minBytes = ($data | Measure-Object -Property UsedBytes -Minimum).Minimum
    
    Write-Host "  PID $renderPid : $($data.Count) samples"
    Write-Host "    First: $([Math]::Round($firstPt.TimeMs,0))ms = $($firstPt.UsedMB)MB"
    Write-Host "    Last:  $([Math]::Round($lastPt.TimeMs,0))ms = $($lastPt.UsedMB)MB"
    Write-Host "    Max:   $([Math]::Round($maxBytes/1MB, 2))MB"
    Write-Host "    Min:   $([Math]::Round($minBytes/1MB, 2))MB"
    
    Write-Host "    Growth timeline (sampled):"
    $sampleCount = [Math]::Max(1, [Math]::Floor($data.Count / 40))
    for ($i = 0; $i -lt $data.Count; $i += $sampleCount) {
        $pt = $data[$i]
        Write-Host "      $([Math]::Round($pt.TimeMs,0))ms: $($pt.UsedMB)MB"
    }
}

# Total GPU memory (all PIDs summed)
Write-Host "`n=== Total GPU Memory (all PIDs) ==="
$allGpuMem = [System.Collections.ArrayList]::new()
$seenTimes = @{}

foreach ($task in $gpuTasks) {
    $ts = [double]$task.ts / 1000.0
    $relTime = [Math]::Round($ts - $t0, 0)
    $bytes = [long]$task.args.data.used_bytes
    
    $key = "$($relTime)_$($task.args.data.renderer_pid)"
    if (-not $seenTimes.ContainsKey($key)) {
        $seenTimes[$key] = $true
        [void]$allGpuMem.Add([PSCustomObject]@{
            TimeMs = $relTime
            RenderPid = $task.args.data.renderer_pid
            UsedMB = [Math]::Round($bytes / 1MB, 2)
        })
    }
}

$gpuTotal = $allGpuMem | Group-Object TimeMs | ForEach-Object {
    $total = ($_.Group | Measure-Object -Property UsedMB -Sum).Sum
    [PSCustomObject]@{ TimeMs = [double]$_.Name; TotalMB = $total }
} | Sort-Object TimeMs

Write-Host "Total GPU memory samples: $($gpuTotal.Count)"
$firstTotal = $gpuTotal | Select-Object -First 1
$lastTotal = $gpuTotal | Select-Object -Last 1
$maxTotal = ($gpuTotal | Measure-Object -Property TotalMB -Maximum).Maximum
$minTotal = ($gpuTotal | Measure-Object -Property TotalMB -Minimum).Minimum

Write-Host "First: $($firstTotal.TotalMB)MB at $($firstTotal.TimeMs)ms"
Write-Host "Last: $($lastTotal.TotalMB)MB at $($lastTotal.TimeMs)ms"
Write-Host "Max: $maxTotal MB"
Write-Host "Min: $minTotal MB"
Write-Host "Growth: $([Math]::Round($lastTotal.TotalMB - $firstTotal.TotalMB, 2))MB"

Write-Host "`nGPU total timeline (sampled):"
$step = [Math]::Max(1, [Math]::Floor($gpuTotal.Count / 40))
for ($i = 0; $i -lt $gpuTotal.Count; $i += $step) {
    $pt = $gpuTotal[$i]
    Write-Host "  $($pt.TimeMs)ms: $($pt.TotalMB)MB"
}

# UpdateLayer analysis
Write-Host "`n=== UpdateLayer Analysis ==="
$updateLayers = $events | Where-Object { $_.name -eq 'UpdateLayer' }
Write-Host "Total UpdateLayer: $($updateLayers.Count)"

if ($updateLayers.Count -gt 0) {
    $layerIds = $updateLayers | ForEach-Object { 
        if ($_.args -and $_.args.layer) {
            [PSCustomObject]@{ 
                ts = [double]$_.ts / 1000.0
                layerId = $_.args.layer.layerId
            }
        }
    }
    
    if ($layerIds.Count -gt 0) {
        $layerIdCounts = $layerIds | Group-Object layerId | Sort-Object Count -Descending | Select-Object -First 10
        Write-Host "Top layer IDs:"
        foreach ($l in $layerIdCounts) {
            Write-Host "  Layer $($l.Name): $($l.Count) updates"
        }
    }
}

# DrawingBuffer events
Write-Host "`n=== DrawingBuffer::prepareMailbox Timeline ==="
$dbEvents = $events | Where-Object { $_.name -eq 'DrawingBuffer::prepareMailbox' }
Write-Host "Total prepareMailbox: $($dbEvents.Count)"
if ($dbEvents.Count -gt 0) {
    $firstDb = $dbEvents | Select-Object -First 1
    $lastDb = $dbEvents | Select-Object -Last 1
    $firstTs = ([double]$firstDb.ts / 1000.0) - $t0
    $lastTs = ([double]$lastDb.ts / 1000.0) - $t0
    Write-Host "First: $([Math]::Round($firstTs,0))ms  Last: $([Math]::Round($lastTs,0))ms"
    Write-Host "Rate: $([Math]::Round($dbEvents.Count / ($lastTs - $firstTs) * 1000, 1)) per second"
}

# RAF events
Write-Host "`n=== RequestAnimationFrame / FireAnimationFrame ==="
$rafCount = ($events | Where-Object { $_.name -eq 'RequestAnimationFrame' }).Count
$fafCount = ($events | Where-Object { $_.name -eq 'FireAnimationFrame' }).Count
Write-Host "RequestAnimationFrame: $rafCount"
Write-Host "FireAnimationFrame: $fafCount"

# All video-related events
Write-Host "`n=== All Video-Related Events ==="
$allVideo = $events | Where-Object { 
    $_.name -match 'Video|video|Demux|demux|Audio|audio|Decode|decode|Media|media' -and
    $_.name -notmatch 'DecodeImage|ImageDecode|ResizeImage'
}
$allVideoNames = $allVideo | Group-Object name | Sort-Object Count -Descending
foreach ($v in $allVideoNames) {
    Write-Host "  $($v.Name): $($v.Count)"
}

# Media pipeline events
Write-Host "`n=== Media Pipeline Events ==="
$mediaPipe = $events | Where-Object { $_.cat -match 'media' }
$mediaNames = $mediaPipe | Group-Object name | Sort-Object Count -Descending
foreach ($mp in $mediaNames) {
    Write-Host "  $($mp.Name): $($mp.Count)"
}

# RasterTask analysis
Write-Host "`n=== RasterTask Analysis ==="
$rasterTasks = $events | Where-Object { $_.name -eq 'RasterTask' -and $_.args -and $_.args.data }
Write-Host "Total RasterTask with data: $($rasterTasks.Count)"

# Check paint event rate
Write-Host "`n=== Paint Event Rate ==="
$paintEvents = $events | Where-Object { $_.name -eq 'Paint' }
$firstPaint = $paintEvents | Select-Object -First 1
$lastPaint = $paintEvents | Select-Object -Last 1
$paintDuration = ([double]$lastPaint.ts - [double]$firstPaint.ts) / 1000.0
Write-Host "Paint events: $($paintEvents.Count) over $([Math]::Round($paintDuration,1))s"
Write-Host "Paint rate: $([Math]::Round($paintEvents.Count / $paintDuration, 1)) per second"

# Check CompositeLayers event rate
Write-Host "`n=== CompositeLayers Rate ==="
$compEvents = $events | Where-Object { $_.name -eq 'CompositeLayers' }
$firstComp = $compEvents | Select-Object -First 1
$lastComp = $compEvents | Select-Object -Last 1
$compDuration = ([double]$lastComp.ts - [double]$firstComp.ts) / 1000.0
Write-Host "CompositeLayers: $($compEvents.Count) over $([Math]::Round($compDuration,1))s"
Write-Host "Composite rate: $([Math]::Round($compEvents.Count / $compDuration, 1)) per second"

# Check Swap rate
Write-Host "`n=== Swap Rate ==="
$swapEvents = $events | Where-Object { $_.name -eq 'Swap' }
$firstSwap = $swapEvents | Select-Object -First 1
$lastSwap = $swapEvents | Select-Object -Last 1
$swapDuration = ([double]$lastSwap.ts - [double]$firstSwap.ts) / 1000.0
Write-Host "Swap events: $($swapEvents.Count) over $([Math]::Round($swapDuration,1))s"
Write-Host "Swap rate: $([Math]::Round($swapEvents.Count / $swapDuration, 1)) per second"

# Check specific event timestamps for correlation
Write-Host "`n=== Event Rate Correlation ==="
Write-Host "Total duration: ~$([Math]::Round(($lastSwap.ts - $t0 * 1000) / 1000, 1))s"
Write-Host "RAF: $rafCount events"
Write-Host "FAF: $fafCount events"
Write-Host "DrawingBuffer::prepareMailbox: $($dbEvents.Count)"
Write-Host "Swap: $($swapEvents.Count)"
Write-Host "CompositeLayers: $($compEvents.Count)"
Write-Host "Paint: $($paintEvents.Count)"
Write-Host "RasterTask: $($rasterTasks.Count)"
Write-Host "GPUTask: $($gpuTasks.Count)"
Write-Host "UpdateLayer: $($updateLayers.Count)"

Write-Host "`n=== Analysis Complete ==="