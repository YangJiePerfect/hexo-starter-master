$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$dir = Get-Location
$file = Join-Path $dir "Trace-20260601T185457.json"

$json = Get-Content $file -Raw -Encoding UTF8 | ConvertFrom-Json
$events = $json.traceEvents

$durationSec = 0

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
Write-Host "Duration: ${durationSec}s"
Write-Host ""
foreach ($rp in $uniquePids) {
    $subset = $gpuData | Where-Object { $_.RendererPid -eq $rp }
    $minMb = [Math]::Round(($subset | Measure-Object -Property UsedMB -Minimum).Minimum, 2)
    $maxMb = [Math]::Round(($subset | Measure-Object -Property UsedMB -Maximum).Maximum, 2)
    $cnt = $subset.Count
    Write-Host "  Renderer $rp : ${cnt} samples, min=${minMb}MB, max=${maxMb}MB, delta=$([Math]::Round($maxMb - $minMb, 2))MB"
}

Write-Host ""
Write-Host "=== 2. Event Summary ==="
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

Write-Host ""
Write-Host "=== 3. Layer Analysis ==="
$updateLayers = $events | Where-Object { $_.name -eq 'UpdateLayer' }
Write-Host "UpdateLayer: $($updateLayers.Count)"

$layerize = $events | Where-Object { $_.name -eq 'Layerize' }
Write-Host "Layerize: $($layerize.Count)"

$setLayerTree = $events | Where-Object { $_.name -eq 'SetLayerTreeId' }
Write-Host "SetLayerTreeId: $($setLayerTree.Count)"

$activateLayer = $events | Where-Object { $_.name -eq 'ActivateLayerTree' }
Write-Host "ActivateLayerTree: $($activateLayer.Count)"

Write-Host ""
Write-Host "=== 4. DrawingBuffer / Mailbox ==="
$dbEvts = $events | Where-Object { $_.name -eq 'DrawingBuffer::prepareMailbox' }
Write-Host "DrawingBuffer::prepareMailbox: $($dbEvts.Count)"
if ($dbEvts.Count -gt 1) {
    $firstTs = [double]$dbEvts[0].ts / 1000.0
    $lastTs = [double]$dbEvts[-1].ts / 1000.0
    $span = $lastTs - $firstTs
    Write-Host "  Rate: $([Math]::Round($dbEvts.Count / $span * 1000, 1)) per second"
}

Write-Host ""
Write-Host "=== 5. RasterTask ==="
$raster = $events | Where-Object { $_.name -eq 'RasterTask' }
Write-Host "RasterTask: $($raster.Count)"

Write-Host ""
Write-Host "=== 6. Video / Media Events ==="
$media = $events | Where-Object { $_.name -match 'Video|Media|Demux|Demuxer|Audio|Picture' -or $_.cat -eq 'media' }
$mediaNames = $media | Group-Object name | Sort-Object Count -Descending | Select-Object -First 20
foreach ($m in $mediaNames) {
    Write-Host "  $($m.Name): $($m.Count)"
}

Write-Host ""
Write-Host "=== 7. Animation Events ==="
$anim = $events | Where-Object { $_.name -match 'Animation' }
$animNames = $anim | Group-Object name | Sort-Object Count -Descending | Select-Object -First 15
foreach ($a in $animNames) {
    Write-Host "  $($a.Name): $($a.Count)"
}

Write-Host ""
Write-Host "=== 8. Navigation / Loading ==="
$nav = $events | Where-Object { $_.cat -eq 'navigation' -or $_.cat -eq 'loading' }
$navNames = $nav | Group-Object name | Sort-Object Count -Descending | Select-Object -First 15
foreach ($n in $navNames) {
    Write-Host "  $($n.Name): $($n.Count)"
}

Write-Host ""
Write-Host "=== 9. Frame Pipeline ==="
$beginFrame = ($events | Where-Object { $_.name -eq 'BeginFrame' }).Count
$drawFrame = ($events | Where-Object { $_.name -eq 'DrawFrame' }).Count
$commit = ($events | Where-Object { $_.name -eq 'BeginCommitCompositorFrame' }).Count
$swap = ($events | Where-Object { $_.name -eq 'Swap' }).Count

Write-Host "BeginFrame: $beginFrame ($([Math]::Round($beginFrame/$durationSec, 1)) fps)"
Write-Host "DrawFrame: $drawFrame ($([Math]::Round($drawFrame/$durationSec, 1)) fps)"
Write-Host "BeginCommitCompositorFrame: $commit ($([Math]::Round($commit/$durationSec, 1)) fps)"
Write-Host "Swap: $swap ($([Math]::Round($swap/$durationSec, 1)) fps)"

Write-Host ""
Write-Host "=== 10. Analysis Complete ==="