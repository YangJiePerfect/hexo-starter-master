$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$dir = Get-Location
$trace1 = Join-Path $dir "Trace-20260601T234645.json"
$trace2 = Join-Path $dir "Trace-20260601T235023.json"

function Analyze-Trace($filePath, $label) {
    $json = Get-Content $filePath -Raw -Encoding UTF8 | ConvertFrom-Json
    $events = $json.traceEvents

    Write-Host "============================================"
    Write-Host "  $label"
    Write-Host "  Events: $($events.Count)"
    Write-Host "============================================"
    Write-Host ""

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

    Write-Host "--- GPU Memory ---"
    $uniquePids = $gpuData | Select-Object -ExpandProperty RendererPid -Unique
    foreach ($rp in $uniquePids) {
        $subset = $gpuData | Where-Object { $_.RendererPid -eq $rp }
        $minMb = [Math]::Round(($subset | Measure-Object -Property UsedMB -Minimum).Minimum, 2)
        $maxMb = [Math]::Round(($subset | Measure-Object -Property UsedMB -Maximum).Maximum, 2)
        $cnt = $subset.Count
        $delta = [Math]::Round($maxMb - $minMb, 2)
        Write-Host "  Renderer $rp : ${cnt} samples, ${minMb}MB->${maxMb}MB (delta=${delta}MB)"
    }

    Write-Host ""
    Write-Host "--- Growth Cycles ---"
    foreach ($rp in $uniquePids) {
        $subset = $gpuData | Where-Object { $_.RendererPid -eq $rp } | Sort-Object TimeMs -Unique
        if ($subset.Count -lt 10) { continue }
        $prevMB = $subset[0].UsedMB
        $trend = "stable"
        $cycleStart = $subset[0]
        $cycleCount = 0
        for ($i = 1; $i -lt $subset.Count; $i++) {
            $curr = $subset[$i]
            $delta = $curr.UsedMB - $prevMB
            if ($delta -gt 2) {
                if ($trend -ne "growing") {
                    if ($trend -eq "dropping") {
                        Write-Host "  Drop: $($cycleStart.UsedMB)MB -> $($curr.UsedMB)MB"
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
                    Write-Host "  Cycle $cycleCount : $($cycleStart.UsedMB)MB->$($curr.UsedMB)MB growth=$growth MB dur=${dur}ms"
                    $cycleStart = $curr
                    $trend = "dropping"
                }
            }
            $prevMB = $curr.UsedMB
        }
    }

    Write-Host ""
    Write-Host "--- Top Events ---"
    $eventSummary = @{}
    $events | ForEach-Object {
        $n = $_.name
        if ($n) {
            if (-not $eventSummary.ContainsKey($n)) { $eventSummary[$n] = 0 }
            $eventSummary[$n]++
        }
    }
    $eventSummary.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 25 | ForEach-Object {
        Write-Host "  $($_.Key): $($_.Value)"
    }

    Write-Host ""
    Write-Host "--- Layer Events ---"
    foreach ($lt in @('UpdateLayer','Layerize','SetLayerTreeId','ActivateLayerTree','Commit','CompositeLayers','BeginCommitCompositorFrame','SubmitCompositorFrameToPresentationCompositorFrame')) {
        $cnt = ($events | Where-Object { $_.name -eq $lt }).Count
        Write-Host "  $lt : $cnt"
    }

    Write-Host ""
    Write-Host "--- Raster/Paint ---"
    foreach ($r in @('RasterTask','Paint','PaintImage','PrePaint','DecodeImage','ResizeImage','GPURasterTask')) {
        $cnt = ($events | Where-Object { $_.name -eq $r }).Count
        Write-Host "  $r : $cnt"
    }

    Write-Host ""
    Write-Host "--- DrawingBuffer ---"
    $dbEvts = $events | Where-Object { $_.name -eq 'DrawingBuffer::prepareMailbox' }
    $dbCount = $dbEvts.Count
    if ($dbCount -gt 1) {
        $firstTs = [double]$dbEvts[0].ts / 1000.0
        $lastTs = [double]$dbEvts[-1].ts / 1000.0
        $span = $lastTs - $firstTs
        Write-Host "  DrawingBuffer::prepareMailbox: $dbCount ($([Math]::Round($dbCount / $span * 1000, 1))/sec)"
    }

    Write-Host ""
    Write-Host "--- Frame Pipeline ---"
    foreach ($f in @('BeginFrame','DrawFrame','Swap','Commit','Activation')) {
        $cnt = ($events | Where-Object { $_.name -eq $f }).Count
        $rate = if ($durationSec -gt 0) { [Math]::Round($cnt / $durationSec, 1) } else { 0 }
        Write-Host "  $f : $cnt ($rate/sec)"
    }

    Write-Host ""
    Write-Host "--- Navigation ---"
    $navEvts = $events | Where-Object { $_.cat -eq 'navigation' -or $_.cat -eq 'loading' }
    $navNames = $navEvts | Group-Object name | Sort-Object Count -Descending | Select-Object -First 15
    foreach ($n in $navNames) {
        Write-Host "  $($n.Name): $($n.Count)"
    }

    Write-Host ""
    Write-Host "--- GC / Memory ---"
    $memEvts = $events | Where-Object { $_.name -match 'V8.GC|Heap|PartitionAlloc|Purge|Memory' }
    $memNames = $memEvts | Group-Object name | Sort-Object Count -Descending | Select-Object -First 15
    foreach ($m in $memNames) {
        Write-Host "  $($m.Name): $($m.Count)"
    }

    Write-Host ""
    Write-Host "--- Animation ---"
    $animEvts = $events | Where-Object { $_.name -match 'Animation' }
    $animNames = $animEvts | Group-Object name | Sort-Object Count -Descending | Select-Object -First 10
    foreach ($a in $animNames) {
        Write-Host "  $($a.Name): $($a.Count)"
    }

    Write-Host ""
    Write-Host "--- Video / Media ---"
    $mediaEvts = $events | Where-Object { $_.name -match 'Video|Media|Demux|Demuxer|Audio|Picture' -or $_.cat -eq 'media' }
    $mediaNames = $mediaEvts | Group-Object name | Sort-Object Count -Descending | Select-Object -First 15
    foreach ($m in $mediaNames) {
        Write-Host "  $($m.Name): $($m.Count)"
    }

    Write-Host ""
    return $gpuData
}

$data1 = Analyze-Trace $trace1 "Trace 1: 234645"
Write-Host ""
Write-Host ""
$data2 = Analyze-Trace $trace2 "Trace 2: 235023"