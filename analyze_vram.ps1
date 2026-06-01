$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$dir = Get-Location
$file = Join-Path $dir "Trace-20260601T101911.json"

Write-Host "=== Loading Trace File ==="
Write-Host "Path: $file"
Write-Host "Size: $([Math]::Round((Get-Item $file).Length / 1MB, 1)) MB"

$json = Get-Content $file -Raw -Encoding UTF8 | ConvertFrom-Json
$events = $json.traceEvents

Write-Host "Total events: $($events.Count)"

# Extract memory timeline (UpdateCounters)
Write-Host "`n=== Memory Timeline (UpdateCounters) ==="
$memData = [System.Collections.ArrayList]::new()
$t0 = 0
$first = $true
$gcEvents = [System.Collections.ArrayList]::new()

foreach ($e in $events) {
    if ($e.name -eq 'UpdateCounters' -and $e.args -and $e.args.data) {
        $d = $e.args.data
        $ts = [double]$e.ts / 1000.0
        if ($first) { $t0 = $ts; $first = $false }
        $relTime = $ts - $t0
        
        [void]$memData.Add([PSCustomObject]@{
            TimeMs = $relTime
            HeapUsed = [double]$d.jsHeapSizeUsed
            HeapTotal = [double]$d.jsHeapTotalSize
            Nodes = [int]$d.nodes
            Listeners = [int]$d.jsEventListeners
            Documents = [int]$d.documents
            LayoutCount = [int]$d.layoutCount
            RecalcStyleCount = [int]$d.recalcStyleCount
        })
    }
    
    if ($e.name -match 'MajorGC|MinorGC' -and $e.args) {
        $ts = [double]$e.ts / 1000.0
        $relTime = $ts - $t0
        [void]$gcEvents.Add([PSCustomObject]@{
            TimeMs = $relTime
            Type = $e.name
            UsedHeapBefore = if ($e.args.usedHeapSizeBefore) { [double]$e.args.usedHeapSizeBefore } else { 0 }
            UsedHeapAfter = if ($e.args.usedHeapSizeAfter) { [double]$e.args.usedHeapSizeAfter } else { 0 }
        })
    }
}

Write-Host "Memory samples: $($memData.Count)"
Write-Host "GC events: $($gcEvents.Count)"

# Memory timeline summary
Write-Host "`n=== Memory Timeline Summary ==="
if ($memData.Count -gt 0) {
    $firstPt = $memData[0]
    $lastPt = $memData[$memData.Count - 1]
    $maxHeap = ($memData | Measure-Object -Property HeapUsed -Maximum).Maximum
    $maxNodes = ($memData | Measure-Object -Property Nodes -Maximum).Maximum
    $minNodes = ($memData | Measure-Object -Property Nodes -Minimum).Minimum
    
    Write-Host "Duration: $([Math]::Round($lastPt.TimeMs - $firstPt.TimeMs, 0))ms"
    Write-Host "Heap Used: start=$([Math]::Round($firstPt.HeapUsed/1MB,1))MB, max=$([Math]::Round($maxHeap/1MB,1))MB, end=$([Math]::Round($lastPt.HeapUsed/1MB,1))MB"
    Write-Host "Nodes: start=$($firstPt.Nodes), max=$maxNodes, min=$minNodes, end=$($lastPt.Nodes)"
    Write-Host "Listeners: start=$($firstPt.Listeners), end=$($lastPt.Listeners)"
    Write-Host "Documents: start=$($firstPt.Documents), end=$($lastPt.Documents)"
}

# All unique event categories
Write-Host "`n=== All Event Categories (top 50) ==="
$eventNames = $events | Where-Object { $_.name } | Group-Object name | Sort-Object Count -Descending | Select-Object -First 50
foreach ($g in $eventNames) {
    Write-Host "  $($g.Name): $($g.Count)"
}

# GPU categories
Write-Host "`n=== All Categories ==="
$allCats = $events | Where-Object { $_.cat } | Group-Object cat | Sort-Object Count -Descending
foreach ($c in $allCats) {
    Write-Host "  $($c.Name): $($c.Count)"
}

# Node growth cycles
Write-Host "`n=== Node Growth Cycles ==="
$cycleStart = 0
$cycleStartTime = 0
$cycleStartNodes = 0
$maxNodes = 0
$cycleCount = 0

for ($i = 0; $i -lt $memData.Count; $i++) {
    $m = $memData[$i]
    if ($i -eq 0) {
        $cycleStart = $i
        $cycleStartTime = $m.TimeMs
        $cycleStartNodes = $m.Nodes
        $maxNodes = $m.Nodes
        continue
    }
    
    if ($m.Nodes -gt $maxNodes) { $maxNodes = $m.Nodes }
    
    $prev = $memData[$i-1]
    if ($m.Nodes - $prev.Nodes -lt -300) {
        $duration = $m.TimeMs - $cycleStartTime
        $growth = $maxNodes - $cycleStartNodes
        $rate = if ($duration -gt 0) { [Math]::Round($growth / $duration * 1000, 1) } else { 0 }
        $cycleCount++
        Write-Host "Cycle $($cycleCount): $([Math]::Round($cycleStartTime,0))ms->$([Math]::Round($m.TimeMs,0))ms  dur=$([Math]::Round($duration,0))ms  nodes: $cycleStartNodes->$maxNodes(max)->$($m.Nodes)  growth=$growth  rate=$rate n/s"
        $cycleStart = $i
        $cycleStartTime = $m.TimeMs
        $cycleStartNodes = $m.Nodes
        $maxNodes = $m.Nodes
    }
}

# Heap growth cycles
Write-Host "`n=== Heap Growth Cycles (>2MB drop) ==="
$hCycleStart = 0
$hCycleStartTime = 0
$hCycleStartHeap = 0
$hMaxHeap = 0
$hCycleCount = 0

for ($i = 0; $i -lt $memData.Count; $i++) {
    $m = $memData[$i]
    if ($i -eq 0) {
        $hCycleStart = $i
        $hCycleStartTime = $m.TimeMs
        $hCycleStartHeap = $m.HeapUsed
        $hMaxHeap = $m.HeapUsed
        continue
    }
    
    if ($m.HeapUsed -gt $hMaxHeap) { $hMaxHeap = $m.HeapUsed }
    
    $prev = $memData[$i-1]
    $drop = $prev.HeapUsed - $m.HeapUsed
    if ($drop -gt 2MB) {
        $duration = $m.TimeMs - $hCycleStartTime
        $growth = $hMaxHeap - $hCycleStartHeap
        $rate = if ($duration -gt 0) { [Math]::Round($growth / $duration * 1000 / 1MB, 1) } else { 0 }
        $hCycleCount++
        Write-Host "HeapCycle $($hCycleCount): $([Math]::Round($hCycleStartTime,0))ms->$([Math]::Round($m.TimeMs,0))ms  dur=$([Math]::Round($duration,0))ms  heap: $([Math]::Round($hCycleStartHeap/1MB,1))MB->$([Math]::Round($hMaxHeap/1MB,1))MB(max)->$([Math]::Round($m.HeapUsed/1MB,1))MB  growth=$([Math]::Round($growth/1MB,1))MB  drop=$([Math]::Round($drop/1MB,1))MB"
        $hCycleStart = $i
        $hCycleStartTime = $m.TimeMs
        $hCycleStartHeap = $m.HeapUsed
        $hMaxHeap = $m.HeapUsed
    }
}

# GC events detail
Write-Host "`n=== GC Events ==="
foreach ($gc in $gcEvents) {
    Write-Host "  $([Math]::Round($gc.TimeMs,0))ms  $($gc.Type)  before=$([Math]::Round($gc.UsedHeapBefore/1MB,1))MB  after=$([Math]::Round($gc.UsedHeapAfter/1MB,1))MB"
}

# Extract specific paint/raster/layer events
Write-Host "`n=== Graphics/Paint Events ==="
$paintTypes = @('Paint', 'CompositeLayers', 'RasterTask', 'GPUTask', 'BeginFrame', 'DrawFrame', 'ActivateLayer', 'PictureLayer', 'TextureLayer', 'ImageDecodeTask', 'DecodeImage', 'ResizeImage', 'UploadResource')
foreach ($pt in $paintTypes) {
    $count = ($events | Where-Object { $_.name -like "*$pt*" }).Count
    if ($count -gt 0) {
        Write-Host "  *$pt*: $count"
    }
}

# Look for frame-related events
Write-Host "`n=== Frame Events ==="
$frameEvents = $events | Where-Object { $_.name -match 'BeginFrame|DrawFrame|ActivatePendingTree|BeginMainFrame|Commit|SwapBuffers|DidNotSwap' }
$frameNames = $frameEvents | Group-Object name | Sort-Object Count -Descending
foreach ($f in $frameNames) {
    Write-Host "  $($f.Name): $($f.Count)"
}

# Look for WebGL specifically
Write-Host "`n=== WebGL Events ==="
$webglEvents = $events | Where-Object { $_.name -match 'WebGL' }
$webglNames = $webglEvents | Group-Object name | Sort-Object Count -Descending
foreach ($w in $webglNames) {
    Write-Host "  $($w.Name): $($w.Count)"
}

# Image-related events
Write-Host "`n=== Image Events ==="
$imgEvents = $events | Where-Object { $_.name -match 'Image|Bitmap|Decode|Resize' }
$imgNames = $imgEvents | Group-Object name | Sort-Object Count -Descending | Select-Object -First 20
foreach ($i in $imgNames) {
    Write-Host "  $($i.Name): $($i.Count)"
}

Write-Host "`n=== Analysis Complete ==="