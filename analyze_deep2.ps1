$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$dir = Get-Location

# Trace 2 - the Ctrl+F5 trace with the worst VRAM leak
$file2 = Join-Path $dir "Trace-20260601T235023.json"
$json2 = Get-Content $file2 -Raw -Encoding UTF8 | ConvertFrom-Json
$events2 = $json2.traceEvents

Write-Host "=== DEEP ANALYSIS: Trace 2 (After Ctrl+F5) ==="
Write-Host ""

# 1. GPU Memory timeline for main renderer (PID 51604 - the leaker)
Write-Host "--- GPU Memory Timeline (PID 51604, every 2000ms) ---"
$gpuEvents = $events2 | Where-Object { $_.name -eq 'GPUTask' -and $_.args -and $_.args.data -and $_.args.data.used_bytes }

$t0_main = $null
$mainMem = [System.Collections.ArrayList]::new()
foreach ($evt in $gpuEvents) {
    $ts = [double]$evt.ts / 1000.0
    if ($null -eq $t0_main) { $t0_main = $ts }
    $relMs = [Math]::Round($ts - $t0_main, 0)
    $rPid = $evt.args.data.renderer_pid
    $mb = [Math]::Round([long]$evt.args.data.used_bytes / 1MB, 2)
    [void]$mainMem.Add([PSCustomObject]@{TimeMs = $relMs; RendererPid = $rPid; UsedMB = $mb})
}

$pid51604 = $mainMem | Where-Object { $_.RendererPid -eq '51604' } | Sort-Object TimeMs -Unique

$lastTime = -2000
foreach ($pt in $pid51604) {
    if ($pt.TimeMs -ge $lastTime + 2000) {
        Write-Host "  $($pt.TimeMs)ms -> $($pt.UsedMB)MB"
        $lastTime = $pt.TimeMs
    }
}

# 2. Find when video was first created
Write-Host ""
Write-Host "--- Video Element Lifecycle ---"
$videoRelated = $events2 | Where-Object { $_.name -match 'Video|video|Demux' -or ($_.args -and ($_.args.toString() -match 'video|\.webm')) }
Write-Host "Video-related events in Trace 2: $($videoRelated.Count)"
$videoRelated | Sort-Object { [double]$_.ts } -Unique | Select-Object -First 10 | ForEach-Object {
    $ts = [Math]::Round([double]$_.ts/1000.0 - $t0_main, 0)
    Write-Host "  ${ts}ms: $($_.name)"
}

# 3. Check what categories the events belong to
Write-Host ""
Write-Host "--- All Categories in Trace 2 ---"
$cats = $events2 | Where-Object { $_.cat } | Group-Object cat | Sort-Object Count -Descending | Select-Object -First 15
foreach ($c in $cats) {
    Write-Host "  $($c.Name): $($c.Count)"
}

# 4. Check for multiple navigations / document loads
Write-Host ""
Write-Host "--- Document Lifecycle ---"
$docEvents = $events2 | Where-Object { $_.name -match 'DocumentLoader|FrameLoader|DidCommitProvisionalLoad|DidFinishLoad|DocumentOnLoad' }
$docNames = $docEvents | Group-Object name | Sort-Object Count -Descending | Select-Object -First 15
foreach ($d in $docNames) {
    Write-Host "  $($d.Name): $($d.Count)"
}

# 5. Check Commit events for duplicate frame submissions
Write-Host ""
Write-Host "--- Commit Analysis ---"
$commits = $events2 | Where-Object { $_.name -eq 'Commit' }
Write-Host "Commit events: $($commits.Count)"

# 6. Check for BeginMainFrame events
Write-Host ""
Write-Host "--- BeginMainFrame Events ---"
$bmfCount = ($events2 | Where-Object { $_.name -eq 'BeginMainFrame' }).Count
Write-Host "BeginMainFrame: $bmfCount"

# 7. Swap rate
Write-Host ""
Write-Host "--- Swap Analysis ---"
$swaps = $events2 | Where-Object { $_.name -eq 'Swap' }
if ($swaps.Count -gt 1) {
    $firstSwap = [double]$swaps[0].ts / 1000.0
    $lastSwap = [double]$swaps[-1].ts / 1000.0
    $span = $lastSwap - $firstSwap
    Write-Host "Swaps: $($swaps.Count) over ${span}s = $([Math]::Round($swaps.Count/$span, 1))/sec"
}

# 8. Check for multiple RequestAnimationFrame sources
Write-Host ""
Write-Host "--- RAF Fire Events Sample ---"
$fires = $events2 | Where-Object { $_.name -eq 'FireAnimationFrame' }
Write-Host "FireAnimationFrame: $($fires.Count)"
if ($fires.Count -gt 0) {
    $firstFire = [double]$fires[0].ts / 1000.0
    $lastFire = [double]$fires[-1].ts / 1000.0
    Write-Host "Rate: $([Math]::Round($fires.Count / ($lastFire - $firstFire) * 1000, 1))/sec"
}

# 9. Check for overdraw / redundant paint
Write-Host ""
Write-Host "--- Paint Analysis ---"
$paints = $events2 | Where-Object { $_.name -eq 'Paint' }
$paintImgs = $events2 | Where-Object { $_.name -eq 'PaintImage' }
Write-Host "Paint: $($paints.Count)"
Write-Host "PaintImage: $($paintImgs.Count)"
Write-Host "PaintImage/Paint ratio: $([Math]::Round($paintImgs.Count / [Math]::Max(1, $paints.Count) * 100, 1))%"

# 10. Check BeginFrame pacing
Write-Host ""
Write-Host "--- BeginFrame Pacing ---"
$bfEvents = $events2 | Where-Object { $_.name -eq 'BeginFrame' } | Sort-Object { [double]$_.ts }
if ($bfEvents.Count -gt 5) {
    $intervals = @()
    for ($i = 1; $i -lt [Math]::Min($bfEvents.Count, 100); $i++) {
        $prev_ts = [double]$bfEvents[$i-1].ts / 1000.0
        $curr_ts = [double]$bfEvents[$i].ts / 1000.0
        $intervals += [Math]::Round(($curr_ts - $prev_ts), 1)
    }
    $avgInterval = [Math]::Round(($intervals | Measure-Object -Average).Average, 1)
    $minInterval = ($intervals | Measure-Object -Minimum).Minimum
    $maxInterval = ($intervals | Measure-Object -Maximum).Maximum
    Write-Host "BeginFrame intervals: avg=${avgInterval}ms min=${minInterval}ms max=${maxInterval}ms"
    Write-Host "Implied FPS: $([Math]::Round(1000 / $avgInterval, 1))"
}

Write-Host ""
Write-Host "=== Analysis Complete ==="