$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$dir = Get-Location
$file = Join-Path $dir "Trace-20260601T185457.json"

$json = Get-Content $file -Raw -Encoding UTF8 | ConvertFrom-Json
$events = $json.traceEvents

# Check Video events more thoroughly
Write-Host "=== All Video Related Events ==="
$videoAll = $events | Where-Object { $_.name -match 'Video|Media|Demux|Decode|picture|picturelayer' -or $_.cat -match 'media|GPU' }
$videoNames = $videoAll | Group-Object name | Sort-Object Count -Descending | Select-Object -First 30
foreach ($v in $videoNames) {
    Write-Host "  $($v.Name): $($v.Count)"
}

# Check all categories
Write-Host "`n=== All Categories ==="
$allCats = $events | Where-Object { $_.cat } | Group-Object cat | Sort-Object Count -Descending | Select-Object -First 20
foreach ($c in $allCats) {
    Write-Host "  $($c.Name): $($c.Count)"
}

# Check for ImageDecodeTask
Write-Host "`n=== Image Decode Tasks ==="
$imgDecode = $events | Where-Object { $_.name -eq 'ImageDecodeTask' -or $_.name -eq 'DecodeImage' -or $_.name -eq 'ResizeImage' }
$imgNames = $imgDecode | Group-Object name | Sort-Object Count -Descending
foreach ($i in $imgNames) {
    Write-Host "  $($i.Name): $($i.Count)"
}

# Sample DecodeImage events with URLs
Write-Host "`n=== Sample DecodeImage URLs ==="
$decodeImgs = $events | Where-Object { $_.name -eq 'DecodeImage' -and $_.args -and $_.args.url }
$decodeImgs | Select-Object -First 20 | ForEach-Object {
    Write-Host "  URL: $($_.args.url)"
}

# Check GPUTask events for more detail
Write-Host "`n=== GPUTask Sample ==="
$gpuTasks = $events | Where-Object { $_.name -eq 'GPUTask' -and $_.args -and $_.args.data }
$gpuTasks | Select-Object -First 10 | ForEach-Object {
    Write-Host "  PID=$($_.args.data.renderer_pid) UsedMB=$([Math]::Round([long]$_.args.data.used_bytes/1MB,2))"
}

# Check for RecreateRasterBackings
Write-Host "`n=== Raster Backing Events ==="
$rasterEvts = $events | Where-Object { $_.name -match 'Raster|Backing|Texture|Tile' }
$rasterNames = $rasterEvts | Group-Object name | Sort-Object Count -Descending | Select-Object -First 20
foreach ($r in $rasterNames) {
    Write-Host "  $($r.Name): $($r.Count)"
}