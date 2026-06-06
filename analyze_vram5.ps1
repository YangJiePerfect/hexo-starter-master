$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$dir = Get-Location
$file = Join-Path $dir "Trace-20260601T185457.json"

Write-Host "=== Analyzing Trace File ==="
Write-Host "Path: $file"

if (-not (Test-Path $file)) {
    Write-Host "ERROR: File not found!" -ForegroundColor Red
    exit 1
}

$json = Get-Content $file -Raw -Encoding UTF8 | ConvertFrom-Json
$events = $json.traceEvents

Write-Host "Total events: $($events.Count)"
Write-Host ""

# GPU Memory Timeline
Write-Host "=== GPU Memory Timeline ==="
$t0 = 0
$first = $true
$gpuTimeline = @()

$gpuMemEvents = $events | Where-Object { $_.name -eq 'GPUTask' -and $_.args -and $_.args.data -and $_.args.data.used_bytes }

foreach ($evt in $gpuMemEvents) {
    $ts = [double]$evt.ts / 1000.0
    if ($first) { $t0 = $ts; $first = $false }
    $relTime = [Math]::Round(($ts - $t0) / 1000.0, 2)
    
    $gpuTimeline += [PSCustomObject]@{
        TimeSec = $relTime
        Pid = $evt.args.data.renderer_pid
        UsedMB = [Math]::Round([long]$evt.args.data.used_bytes / 1MB, 2)
    }
}

$uniquePids = $gpuTimeline | Select-Object -ExpandProperty Pid -Unique
Write-Host "Renderer PIDs found:"
foreach ($rendererPid in $uniquePids) {
    $pidData = $gpuTimeline | Where-Object { $_.Pid -eq $rendererPid }
    $minMb = ($pidData | Measure-Object -Property UsedMB -Minimum).Minimum
    $maxMb = ($pidData | Measure-Object -Property UsedMB -Maximum).Maximum
    $count = $pidData.Count
    Write-Host "  PID $rendererPid : ${count} samples, min=${minMb}MB, max=${maxMb}MB"
}

# Find growth patterns
Write-Host ""
Write-Host "=== Memory Growth Analysis ==="
$trendStats = @()
$growthCount = 0
$dropCount = 0
$prevMb = 0

foreach ($sample in $gpuTimeline) {
    if ($prevMb -gt 0) {
        $delta = $sample.UsedMB - $prevMb
        if ($delta -gt 2) { $growthCount++ }
        elseif ($delta -lt -2) { $dropCount++ }
    }
    $prevMb = $sample.UsedMB
}

Write-Host "Growth events (>2MB): $growthCount, Drop events (>2MB): $dropCount"

# Check for patterns
$sortedTimeline = $gpuTimeline | Sort-Object TimeSec, UsedMB -Unique
$firstSample = $sortedTimeline[0]
$lastSample = $sortedTimeline[-1]
$totalGrowth = $lastSample.UsedMB - $firstSample.UsedMB
Write-Host "Total VRAM change: ${firstSample.UsedMB}MB -> ${lastSample.UsedMB}MB (growth: ${totalGrowth}MB)"

# Check Layer Events
Write-Host ""
Write-Host "=== Layer Events ==="
$layerEvents = $events | Where-Object { $_.name -match 'Layer' }
$layerNames = $layerEvents | Group-Object name | Sort-Object Count -Descending | Select-Object -First 10
foreach ($l in $layerNames) {
    Write-Host "  $($l.Name): $($l.Count)"
}

# Check DrawingBuffer events
Write-Host ""
Write-Host "=== DrawingBuffer Events ==="
$dbEvents = $events | Where-Object { $_.name -match 'DrawingBuffer|prepareMailbox|Mailbox' }
$dbNames = $dbEvents | Group-Object name | Sort-Object Count -Descending
foreach ($d in $dbNames) {
    Write-Host "  $($d.Name): $($d.Count)"
}

# Check video-related events
Write-Host ""
Write-Host "=== Video/Decode Events ==="
$videoEvents = $events | Where-Object { $_.name -match 'DecodeImage|ResizeImage|Video|Media|picture' }
$videoNames = $videoEvents | Group-Object name | Sort-Object Count -Descending | Select-Object -First 15
foreach ($v in $videoNames) {
    Write-Host "  $($v.Name): $($v.Count)"
}

# Check for will-change related patterns
Write-Host ""
Write-Host "=== Compositor Frame Events ==="
$compEvents = $events | Where-Object { $_.name -match 'Compositor|Composite' }
$compNames = $compEvents | Group-Object name | Sort-Object Count -Descending | Select-Object -First 15
foreach ($c in $compNames) {
    Write-Host "  $($c.Name): $($c.Count)"
}

# Check RAF events
Write-Host ""
Write-Host "=== Animation Frame Events ==="
$rafEvents = $events | Where-Object { $_.name -match 'AnimationFrame|RequestAnimationFrame|FireAnimationFrame' }
$rafNames = $rafEvents | Group-Object name | Sort-Object Count -Descending
foreach ($r in $rafNames) {
    Write-Host "  $($r.Name): $($r.Count)"
}

Write-Host ""
Write-Host "=== Analysis Complete ==="