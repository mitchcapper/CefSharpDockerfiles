$max = 0;
$max_ws = 0;
while($true){
    $proc = Get-Process Link -ErrorAction SilentlyContinue;
    if ($proc){
        $proc = $proc[0];
        $memory = $proc.PM;
        $memory_ws = $proc.WS;
        if (! $memory){
            $memory=0;
        }
        if (! $memory_ws){
            $memory_ws=0;
        }
        $memory/=1024*1024*1024;
        if ($memory -gt $max){
            $max = $memory;
        }
        $memory_ws/=1024*1024*1024;
        if ($memory_ws -gt $max_ws){
            $max_ws = $memory_ws;
        }
        Write-Host  $(Get-Date -Format u) $memory.ToString("0.00")G Max: $max.ToString("0.00")G  WS: $memory_ws.ToString("0.00")G Max: $max_ws.ToString("0.00")G;
        Start-Sleep -Seconds 60;
    }
}