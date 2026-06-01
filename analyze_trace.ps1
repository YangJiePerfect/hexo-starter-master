$tracePath = Join-Path $PSScriptRoot 'Trace-20260601T083026.json'
$json = Get-Content $tracePath -Raw -Encoding UTF8 | ConvertFrom-Json
$events = $json.traceEvents

# Extract memory timeline
$memData = @()
foreach ($e in $events) {
  if ($e.name -eq 'UpdateCounters' -and $e.args -and $e.args.data) {
    $d = $e.args.data
    $obj = [PSCustomObject]@{
      TimeMs = [double]$e.ts / 1000.0
      HeapUsed = [double]$d.jsHeapSizeUsed
      Nodes = [int]$d.nodes
      Listeners = [int]$d.jsEventListeners
    }
    $memData += $obj
  }
}

if ($memData.Count -gt 0) {
  $t0 = $memData[0].TimeMs
  foreach ($m in $memData) { $m.TimeMs = $m.TimeMs - $t0 }
}

# Find cycles: when nodes drop significantly
Write-Host "=== Node Count Drop Events (drop > 500) ==="
for ($i = 1; $i -lt $memData.Count; $i++) {
  $prev = $memData[$i-1]
  $curr = $memData[$i]
  $delta = $curr.Nodes - $prev.Nodes
  if ($delta -lt -500) {
    Write-Host "T+$([Math]::Round($curr.TimeMs, 0))ms  nodes: $($prev.Nodes)->$($curr.Nodes)  drop=$($delta)  heap: $([Math]::Round($prev.HeapUsed/1048576,2))MB->$([Math]::Round($curr.HeapUsed/1048576,2))MB"
  }
}

Write-Host "`n=== Node Count Rises (rise > 200) ==="
$lastDrop = 0
for ($i = 1; $i -lt $memData.Count; $i++) {
  $prev = $memData[$i-1]
  $curr = $memData[$i]
  $delta = $curr.Nodes - $prev.Nodes
  if ($delta -gt 200) {
    $elapsed = [Math]::Round($curr.TimeMs - $lastDrop, 0)
    Write-Host "T+$([Math]::Round($curr.TimeMs, 0))ms  nodes: $($prev.Nodes)->$($curr.Nodes)  rise=$($delta)  elapsed_since_last_drop=$elapsed ms"
    $lastDrop = $curr.TimeMs
  }
}

# Look at what events happen around the time of node drops
Write-Host "`n=== Events around node drops ==="
$dropTimes = @()
for ($i = 1; $i -lt $memData.Count; $i++) {
  $prev = $memData[$i-1]
  $curr = $memData[$i]
  if ($curr.Nodes - $prev.Nodes -lt -500) {
    $dropTimes += $curr.TimeMs
  }
}

# Find events near each drop time
foreach ($dt in $dropTimes) {
  $window = 200  # ms
  $nearby = $events | Where-Object {
    $_.ts -and $_.name -and ([double]$_.ts / 1000.0 - $t0 - $dt -lt $window) -and ([double]$_.ts / 1000.0 - $t0 - $dt -gt -$window)
  } | Select-Object -First 10
  Write-Host "`nNear T+$([Math]::Round($dt, 0))ms:"
  $nearby | ForEach-Object {
    $relTime = [Math]::Round([double]$_.ts / 1000.0 - $t0 - $dt, 0)
    Write-Host "  $relTime ms  $($_.cat)::$($_.name)"
  }
}