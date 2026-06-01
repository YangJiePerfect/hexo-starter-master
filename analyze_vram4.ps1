$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$dir = Get-Location
$file = Join-Path $dir "Trace-20260601T101911.json"

$json = Get-Content $file -Raw -Encoding UTF8 | ConvertFrom-Json
$events = $json.traceEvents

# Extract GPUTask memory with timestamps for detailed analysis
Write-Host "=== GPU Memory Growth/Drop Cycles ==="
$t0 = 0
$first = $true
$gpuTimeline = [System.Collections.ArrayList]::new()

$gpuTasks = $events | Where-Object { $_.name -eq 'GPUTask' -and $_.args -and $_.args.data }

foreach ($task in $gpuTasks) {
    $ts = [double]$task.ts / 1000.0
    if ($first) { $t0 = $ts; $first = $false }
    $relTime = $ts - $t0
    
    $renderPid = $task.args.data.renderer_pid
    $bytes = [long]$task.args.data.used_bytes
    
    [void]$gpuTimeline.Add([PSCustomObject]@{
        TimeMs = [Math]::Round($relTime, 0)
        RenderPid = $renderPid
        UsedMB = [Math]::Round($bytes / 1MB, 2)
    })
}

# For PID 25108 (main renderer), find growth/drop cycles
$mainGpu = $gpuTimeline | Where-Object { $_.RenderPid -eq '25108' } | Sort-Object TimeMs -Unique

Write-Host "Main renderer PID 25108 GPU memory cycles:"
$prevMB = $mainGpu[0].UsedMB
$cycleStart = $mainGpu[0]
$trend = "stable"
$cycleCount = 0

for ($i = 1; $i -lt $mainGpu.Count; $i++) {
    $curr = $mainGpu[$i]
    $delta = $curr.UsedMB - $prevMB
    
    if ($delta -gt 2) {
        if ($trend -ne "growing") {
            if ($trend -eq "dropping") {
                $cycleCount++
                $dur = $curr.TimeMs - $cycleStart.TimeMs
                $growth = $prevMB - $cycleStart.UsedMB
                Write-Host "Cycle ${cycleCount} end: drop $([Math]::Round($($cycleStart.TimeMs),0))ms->$([Math]::Round($($curr.TimeMs),0))ms, min=$($cycleStart.UsedMB)MB, recovered to $($curr.UsedMB)MB"
            }
            $cycleStart = $curr
            $trend = "growing"
        }
    }
    elseif ($delta -lt -2) {
        if ($trend -ne "dropping") {
            if ($trend -eq "growing") {
                $cycleCount++
                $dur = $curr.TimeMs - $cycleStart.TimeMs
                $growth = $prevMB - $cycleStart.UsedMB
                Write-Host "Cycle ${cycleCount}: $([Math]::Round($($cycleStart.TimeMs),0))ms->$([Math]::Round($($curr.TimeMs),0))ms, $($cycleStart.UsedMB)MB->$($prevMB)MB->$($curr.UsedMB)MB, growth=$growth MB, dur=$dur ms"
            }
            $cycleStart = $curr
            $trend = "dropping"
        }
    }
    
    $prevMB = $curr.UsedMB
}

# Check UpdateLayer events for specific layer info
Write-Host "`n=== UpdateLayer Sample Analysis ==="
$updateLayers = $events | Where-Object { $_.name -eq 'UpdateLayer' -and $_.args -and $_.args.layer }

# Sample first 10 with layer info
$updateLayers | Select-Object -First 10 | ForEach-Object {
    $ts = [double]$_.ts / 1000.0
    $layerInfo = ""
    if ($_.args.layer) {
        $l = $_.args.layer
        $layerInfo = "layerId=$($l.layerId) bounds=$($l.bounds) reason=$($l.reason)"
    }
    Write-Host "  ts=$ts $layerInfo"
}

# Check for picture layer events
Write-Host "`n=== PictureLayer Events ==="
$picLayers = $events | Where-Object { $_.name -eq 'PictureLayer' -and $_.args }
$picCount = $picLayers.Count
Write-Host "Total PictureLayer: $picCount"

if ($picCount -gt 0) {
    $picLayers | Select-Object -First 5 | ForEach-Object {
        $ts = [double]$_.ts / 1000.0
        $args = $_ | Select-Object -ExpandProperty args | ConvertTo-Json -Compress -Depth 3
        if ($args.Length -gt 200) { $args = $args.Substring(0, 200) + "..." }
        Write-Host "  ts=$ts args=$args"
    }
}

# Check for compositor frame events
Write-Host "`n=== CompositorFrame Events ==="
$compFrameEvents = $events | Where-Object { $_.name -match 'CompositorFrame' -and $_.args }
$compFrameNames = $compFrameEvents | Group-Object name | Sort-Object Count -Descending
foreach ($c in $compFrameNames) {
    Write-Host "  $($c.Name): $($c.Count)"
}

# Check for video-related events in more detail
Write-Host "`n=== Detailed Video/Media Analysis ==="
$mediaEvents = $events | Where-Object { $_.cat -eq 'media' -or $_.cat -eq 'media,rail' }
Write-Host "Media category events: $($mediaEvents.Count)"
$mediaEvents | Group-Object name | Sort-Object Count -Descending | ForEach-Object {
    Write-Host "  $($_.Name): $($_.Count)"
}

# Check for any event with 'video' in args
Write-Host "`n=== Events with 'video' in args ==="
$videoInArgs = $events | Where-Object { 
    $_.args -and ($_.args.ToString() -match 'video' -or $_.args.ToString() -match 'header-bg' -or $_.args.ToString() -match 'webm')
}
$videoInArgsNames = $videoInArgs | Group-Object name | Sort-Object Count -Descending
foreach ($v in $videoInArgsNames) {
    Write-Host "  $($v.Name): $($v.Count)"
}

# Check for HTMLMediaElement or HTMLVideoElement events
Write-Host "`n=== HTMLMediaElement Events ==="
$htmlMedia = $events | Where-Object { $_.name -match 'HTMLMedia|HTMLVideo|MediaElement|VideoElement' }
$htmlMediaNames = $htmlMedia | Group-Object name | Sort-Object Count -Descending
foreach ($hm in $htmlMediaNames) {
    Write-Host "  $($hm.Name): $($hm.Count)"
}

# Check for animation-related events
Write-Host "`n=== Animation Events ==="
$animEvents = $events | Where-Object { $_.name -match 'Animation' }
$animNames = $animEvents | Group-Object name | Sort-Object Count -Descending
foreach ($a in $animNames) {
    Write-Host "  $($a.Name): $($a.Count)"
}

# Check for CSS animation/compositing events
Write-Host "`n=== CSS/Compositor Animation Events ==="
$cssAnim = $events | Where-Object { $_.name -match 'CSSAnimation|WebAnimation|CompositeAnimation|MainThreadAnimation' }
$cssAnimNames = $cssAnim | Group-Object name | Sort-Object Count -Descending
foreach ($c in $cssAnimNames) {
    Write-Host "  $($c.Name): $($c.Count)"
}

# Look at the frame sequence to understand rendering pipeline
Write-Host "`n=== Frame Pipeline Analysis ==="
$beginFrames = ($events | Where-Object { $_.name -eq 'BeginFrame' }).Count
$drawFrames = ($events | Where-Object { $_.name -eq 'DrawFrame' }).Count
$activateLayers = ($events | Where-Object { $_.name -eq 'ActivateLayerTree' }).Count
$beginCommits = ($events | Where-Object { $_.name -eq 'BeginCommitCompositorFrame' }).Count
$swaps = ($events | Where-Object { $_.name -eq 'Swap' }).Count

Write-Host "BeginFrame: $beginFrames"
Write-Host "DrawFrame: $drawFrames"
Write-Host "ActivateLayerTree: $activateLayers"
Write-Host "BeginCommitCompositorFrame: $beginCommits"
Write-Host "Swap: $swaps"

# Calculate frame rates
$duration = 89.5  # seconds
Write-Host "`nEffective rates:"
Write-Host "DrawFrame: $([Math]::Round($drawFrames/$duration, 1)) fps"
Write-Host "Swap: $([Math]::Round($swaps/$duration, 1)) fps"
Write-Host "BeginFrame: $([Math]::Round($beginFrames/$duration, 1)) fps"

# Check for any GPU memory-related metadata
Write-Host "`n=== GPU Memory Metadata ==="
$metadata = $events | Where-Object { $_.name -eq 'GPUTask' -and $_.args -and $_.args.data } | 
    ForEach-Object { $_.args.data.used_bytes } | 
    Measure-Object -Maximum -Minimum -Average

Write-Host "GPU memory (PID 25108): min=$([Math]::Round($metadata.Minimum/1MB,2))MB, max=$([Math]::Round($metadata.Maximum/1MB,2))MB, avg=$([Math]::Round($metadata.Average/1MB,2))MB"

Write-Host "`n=== Analysis Complete ==="