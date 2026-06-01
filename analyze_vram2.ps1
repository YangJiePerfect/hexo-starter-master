$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$dir = Get-Location
$file = Join-Path $dir "Trace-20260601T101911.json"

Write-Host "=== Deep GPU/VRAM Analysis ==="

$json = Get-Content $file -Raw -Encoding UTF8 | ConvertFrom-Json
$events = $json.traceEvents

# 1. DecodeImage events with args
Write-Host "`n=== DecodeImage Events (sample) ==="
$decodeEvents = $events | Where-Object { $_.name -eq 'DecodeImage' -and $_.args }
$decodeCount = $decodeEvents.Count
Write-Host "Total DecodeImage: $decodeCount"

if ($decodeCount -gt 0) {
    $decodeTypes = $decodeEvents | ForEach-Object { $_.args.imageType } | Group-Object | Sort-Object Count -Descending
    Write-Host "Image types:"
    foreach ($dt in $decodeTypes) {
        Write-Host "  $($dt.Name): $($dt.Count)"
    }
    
    # Sample first 5
    Write-Host "`nFirst 5 DecodeImage events:"
    $decodeEvents | Select-Object -First 5 | ForEach-Object {
        $ts = [double]$_.ts / 1000.0
        Write-Host "  ts=$ts type=$($_.args.imageType) size=$($_.args.width)x$($_.args.height)"
    }
}

# 2. ResizeImage events
Write-Host "`n=== ResizeImage Events ==="
$resizeEvents = $events | Where-Object { $_.name -eq 'ResizeImage' }
Write-Host "Total ResizeImage: $($resizeEvents.Count)"

# 3. GPUTask events - what kinds of tasks
Write-Host "`n=== GPUTask Events ==="
$gpuTasks = $events | Where-Object { $_.name -eq 'GPUTask' }
Write-Host "Total GPUTask: $($gpuTasks.Count)"

# Get GPUTask args to understand what's happening
if ($gpuTasks.Count -gt 0) {
    $taskArgs = $gpuTasks | ForEach-Object { 
        if ($_.args -and $_.args.data) {
            [PSCustomObject]@{ 
                ts = [double]$_.ts / 1000.0
                task = $_.args.data
            }
        }
    }
    Write-Host "Sample GPUTask events:"
    $taskArgs | Select-Object -First 10 | ForEach-Object {
        Write-Host "  ts=$($_.ts) task=$($_.task)"
    }
}

# 4. RasterTask events
Write-Host "`n=== RasterTask Events ==="
$rasterTasks = $events | Where-Object { $_.name -eq 'RasterTask' }
Write-Host "Total RasterTask: $($rasterTasks.Count)"

# 5. Layer events
Write-Host "`n=== Layer Events ==="
$layerEvents = $events | Where-Object { $_.name -match 'Layer' }
$layerNames = $layerEvents | Group-Object name | Sort-Object Count -Descending
foreach ($l in $layerNames) {
    Write-Host "  $($l.Name): $($l.Count)"
}

# 6. Video-related events
Write-Host "`n=== Video/Media Events ==="
$videoEvents = $events | Where-Object { 
    $_.name -match 'Video|Media|Decode|Demux|Audio|Play|Pause|Seek|Buffering' -or 
    $_.cat -match 'media'
}
$videoNames = $videoEvents | Group-Object name | Sort-Object Count -Descending
foreach ($v in $videoNames) {
    Write-Host "  $($v.Name): $($v.Count)"
}

# 7. WebGL events (excluding Live2D context)
Write-Host "`n=== WebGL Events ==="
$webglEvents = $events | Where-Object { $_.name -match 'WebGL' }
$webglNames = $webglEvents | Group-Object name | Sort-Object Count -Descending
foreach ($w in $webglNames) {
    Write-Host "  $($w.Name): $($w.Count)"
}

# 8. Canvas events
Write-Host "`n=== Canvas Events ==="
$canvasEvents = $events | Where-Object { $_.name -match 'Canvas|DrawingBuffer' }
$canvasNames = $canvasEvents | Group-Object name | Sort-Object Count -Descending
foreach ($c in $canvasNames) {
    Write-Host "  $($c.Name): $($c.Count)"
}

# 9. Texture events
Write-Host "`n=== Texture/Upload Events ==="
$textureEvents = $events | Where-Object { $_.name -match 'Texture|Upload|Mailbox|Buffer' }
$textureNames = $textureEvents | Group-Object name | Sort-Object Count -Descending
foreach ($t in $textureNames) {
    Write-Host "  $($t.Name): $($t.Count)"
}

# 10. Commit/Swap events
Write-Host "`n=== Commit/Swap Events ==="
$commitEvents = $events | Where-Object { $_.name -match 'Commit|Swap|Submit|Present' }
$commitNames = $commitEvents | Group-Object name | Sort-Object Count -Descending
foreach ($c in $commitNames) {
    Write-Host "  $($c.Name): $($c.Count)"
}

# 11. ImageDecodeTask events
Write-Host "`n=== ImageDecodeTask Events ==="
$imgDecodeTasks = $events | Where-Object { $_.name -eq 'ImageDecodeTask' }
Write-Host "Total ImageDecodeTask: $($imgDecodeTasks.Count)"

# 12. Check for specific image URLs being decoded
Write-Host "`n=== Image URLs in DecodeImage ==="
$imgUrls = $decodeEvents | ForEach-Object { 
    if ($_.args -and $_.args.url) { $_.args.url }
} | Group-Object | Sort-Object Count -Descending | Select-Object -First 20
foreach ($u in $imgUrls) {
    Write-Host "  $($u.Name): $($u.Count)"
}

# 13. Check for video frame decode events
Write-Host "`n=== Video Frame Decode Events ==="
$videoFrameEvents = $events | Where-Object { $_.name -match 'VideoFrame|DecodeFrame|VideoDecode' }
$vfNames = $videoFrameEvents | Group-Object name | Sort-Object Count -Descending
foreach ($vf in $vfNames) {
    Write-Host "  $($vf.Name): $($vf.Count)"
}

# 14. Check gc event details
Write-Host "`n=== Major GC Details ==="
$majorGCs = $events | Where-Object { $_.name -eq 'MajorGC' -and $_.args }
$majorGCs | Select-Object -First 5 | ForEach-Object {
    $ts = [double]$_.ts / 1000.0
    $args = $_.args | ConvertTo-Json -Compress
    Write-Host "  ts=$ts args=$args"
}

# 15. Look for any memory-related disabled-by-default events
Write-Host "`n=== Memory Categories ==="
$memCats = $events | Where-Object { $_.cat -match 'memory' } | Group-Object cat | Sort-Object Count -Descending
foreach ($mc in $memCats) {
    Write-Host "  $($mc.Name): $($mc.Count)"
}

# 16. Frame budget/exceeded events
Write-Host "`n=== Frame Budget Events ==="
$budgetEvents = $events | Where-Object { $_.name -match 'Budget|Exceeded|Dropped|Jank' }
$budgetNames = $budgetEvents | Group-Object name | Sort-Object Count -Descending
foreach ($b in $budgetNames) {
    Write-Host "  $($b.Name): $($b.Count)"
}

Write-Host "`n=== Deep Analysis Complete ==="