$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

param([string]$TracePath)

$dir = Get-Location
$file = Join-Path $dir $TracePath

if (-not (Test-Path $file)) {
    Write-Host "ERROR: File not found: $file" -ForegroundColor Red
    exit 1
}

$json = Get-Content $file -Raw -Encoding UTF8 | ConvertFrom-Json
$events = $json.traceEvents

Write-Host "============================================"
Write-Host "  Analysis: $TracePath"
Write-Host "  Total events: $($events.Count)"
Write-Host "============================================"
Write-Host ""

# 1. GPU Memory Timeline
Write-Host "=== 1. GPU Memory Timeline ==="
$gpuEvents = $events | Where-Object { $_.name -eq 'GPUTask' -and $_.args -and $_.args.data -and $_.args.data.used_bytes }
$t0 = $null
$gpuData = [System.Collections.ArrayList]::new()
foreach ($evt in $gpuEvents) {
    $ts = [double]$evt.ts / 1000.0
    if ($null -eq $t0) { $t0 = $ts }
    $relMs = [Math]::Round($ts - $t0, 0)
    $rPid = $evt.args.data.renderer_pid
    $mb = [Math]::Round([long]$evt.args.data.used_bytes / 1MB, 2)
    [void]$gpuData.Add([PSCustomObject]@{TimeMs = $relMs; RendererPid = $rPid; UsedMB = $mb})
}
$durationSec = [Math]::Round($gpuData[-1].TimeMs / 1000.0, 0)

$uniquePids = $gpuData | Select-Object -ExpandProperty RendererPid -Unique
foreach ($rp in $uniquePids) {
    $subset = $gpuData | Where-Object { $_.RendererPid -eq $rp }
    $minMb = [Math]::Round(($subset | Measure-Object -Property UsedMB -Minimum).Minimum, 2)
    $maxMb = [Math]::Round(($subset | Measure-Object -Property UsedMB -Maximum).Maximum, 2)
    $cnt = $subset.Count
    $delta = [Math]::Round($maxMb - $minMb, 2)
    if ($cnt -gt 10) {
        Write-Host "  Renderer $rp : ${cnt} samples, ${minMb}MB -> ${maxMb}MB (delta=${delta}MB) [MAIN]"
    } else {
        Write-Host "  Renderer $rp : ${cnt} samples, ${minMb}MB -> ${maxMb}MB (delta=${delta}MB)"
    }
}

# 2. Identify growth cycles
Write-Host ""
Write-Host "=== 2. VRAM Growth Cycles ==="
foreach ($rp in $uniquePids) {
    $subset = $gpuData | Where-Object { $_.RendererPid -eq $rp } | Sort-Object TimeMs -Unique
    if ($subset.Count -lt 10) { continue }
    
    $prevMB = $subset[0].UsedMB
    $trend = "stable"
    $cycleStart = $subset[0]
    $cycleCount = 0
    $cycles = [System.Collections.ArrayList]::new()
    
    for ($i = 1; $i -lt $subset.Count; $i++) {
        $curr = $subset[$i]
        $delta = $curr.UsedMB - $prevMB
        
        if ($delta -gt 2) {
            if ($trend -ne "growing") {
                if ($trend -eq "dropping" -and $cycleCount -gt 0) {
                    [void]$cycles.Add("  Drop: $($cycleStart.TimeMs)ms ($($cycleStart.UsedMB)MB) -> $($curr.TimeMs)ms ($($curr.UsedMB)MB)")
                }
                $cycleStart = $curr
                $trend = "growing"
            }
        }
        elseif ($delta -lt -5) {
            if ($trend -eq "growing") {
                $cycleCount++
                $growth = [Math]::Round($prevMB - $cycleStart.UsedMB, 2)
                $dur = $curr.TimeMs - $cycleStart.TimeMs
                [void]$cycles.Add("  Cycle $cycleCount : $($cycleStart.TimeMs)ms ($($cycleStart.UsedMB)MB) -> $($curr.TimeMs)ms ($($curr.UsedMB)MB) growth=$growth MB dur=${dur}ms")
                $cycleStart = $curr
                $trend = "dropping"
            }
        }
        $prevMB = $curr.UsedMB
    }
    
    if ($cycles.Count -gt 0) {
        Write-Host "Renderer $rp cycles:"
        foreach ($c in $cycles) { Write-Host $c }
    }
}

# 3. Event categories
Write-Host ""
Write-Host "=== 3. Top Event Types ==="
$eventSummary = @{}
$events | ForEach-Object {
    $n = $_.name
    if ($n) {
        if (-not $eventSummary.ContainsKey($n)) { $eventSummary[$n] = 0 }
        $eventSummary[$n]++
    }
}
$eventSummary.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 30 | ForEach-Object {
    Write-Host "  $($_.Key): $($_.Value)"
}

# 4. Layer Analysis
Write-Host ""
Write-Host "=== 4. Layer Events ==="
$layerTypes = @('UpdateLayer', 'Layerize', 'SetLayerTreeId', 'ActivateLayerTree', 'Commit', 'CompositeLayers', 'BeginCommitCompositorFrame', 'SubmitCompositorFrameToPresentationCompositorFrame')
foreach ($lt in $layerTypes) {
    $cnt = ($events | Where-Object { $_.name -eq $lt }).Count
    Write-Host "  $lt : $cnt"
}

# 5. Raster & Paint
Write-Host ""
Write-Host "=== 5. Raster / Paint / Image ==="
$raster = @('RasterTask', 'Paint', 'PaintImage', 'PrePaint', 'DecodeImage', 'ResizeImage', 'GPURasterTask')
foreach ($r in $raster) {
    $cnt = ($events | Where-Object { $_.name -eq $r }).Count
    Write-Host "  $r : $cnt"
}

# 6. DrawingBuffer & Mailbox
Write-Host ""
Write-Host "=== 6. DrawingBuffer / Mailbox ==="
$dbEvts = $events | Where-Object { $_.name -eq 'DrawingBuffer::prepareMailbox' }
$dbCount = $dbEvts.Count
Write-Host "  DrawingBuffer::prepareMailbox: $dbCount"
if ($dbCount -gt 1) {
    $firstTs = [double]$dbEvts[0].ts / 1000.0
    $lastTs = [double]$dbEvts[-1].ts / 1000.0
    $span = $lastTs - $firstTs
    Write-Host "  Rate: $([Math]::Round($dbCount / $span * 1000, 1)) per second"
}

# 7. Frame Pipeline
Write-Host ""
Write-Host "=== 7. Frame Pipeline ==="
$frameEvts = @('BeginFrame', 'DrawFrame', 'Swap', 'BeginImplFrameToSendBeginMainFrame', 'SendBeginMainFrameToCommit', 'Commit', 'Activation')
foreach ($f in $frameEvts) {
    $cnt = ($events | Where-Object { $_.name -eq $f }).Count
    $rate = if ($durationSec -gt 0) { [Math]::Round($cnt / $durationSec, 1) } else { 0 }
    Write-Host "  $f : $cnt ($rate/sec)"
}

# 8. Navigation / Loading
Write-Host ""
Write-Host "=== 8. Navigation / Page Load ==="
$navEvts = $events | Where-Object { $_.cat -eq 'navigation' -or $_.cat -eq 'loading' -or $_.cat -eq 'blink.user_timing' }
$navNames = $navEvts | Group-Object name | Sort-Object Count -Descending | Select-Object -First 20
foreach ($n in $navNames) {
    Write-Host "  $($n.Name): $($n.Count)"
}

# 9. Memory / GC
Write-Host ""
Write-Host "=== 9. Memory / GC Events ==="
$memEvts = $events | Where-Object { $_.name -match 'V8.GC|Heap|Memory|PartitionAlloc|Purge' }
$memNames = $memEvts | Group-Object name | Sort-Object Count -Descending | Select-Object -First 15
foreach ($m in $memNames) {
    Write-Host "  $($m.Name): $($m.Count)"
}

# 10. Animation
Write-Host ""
Write-Host "=== 10. Animation Events ==="
$animEvts = $events | Where-Object { $_.name -match 'Animation' }
$animNames = $animEvts | Group-Object name | Sort-Object Count -Descending | Select-Object -First 15
foreach ($a in $animNames) {
    Write-Host "  $($a.Name): $($a.Count)"
}

# 11. Video / Media
Write-Host ""
Write-Host "=== 11. Video / Media Events ==="
$mediaEvts = $events | Where-Object { $_.name -match 'Video|Media|Demux|Demuxer|Audio|Picture' -or $_.cat -eq 'media' }
$mediaNames = $mediaEvts | Group-Object name | Sort-Object Count -Descending | Select-Object -First 20
foreach ($m in $mediaNames) {
    Write-Host "  $($m.Name): $($m.Count)"
}

# 12. Navigation patterns (for Ctrl+F5 detection)
Write-Host ""
Write-Host "=== 12. Navigation Patterns ==="
$navStart = $events | Where-Object { $_.name -eq 'NavigationStart' -or $_.name -eq 'navigationStart' -or $_.name -match 'Navigate' }
$navStart | Sort-Object { [double]$_.ts } -Unique | ForEach-Object {
    $ts = [Math]::Round(([double]$_.ts / 1000.0 - $t0) / 1000.0, 2)
    Write-Host "  ${ts}s: $($_.name) args=$($_.args | ConvertTo-Json -Compress -Depth 2)"
}

Write-Host ""
Write-Host "============================================"
Write-Host "  Analysis Complete"
Write-Host "============================================"