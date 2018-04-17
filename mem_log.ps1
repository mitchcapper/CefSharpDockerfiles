$max = 0;

while($true){
    $proc = Get-Process Link -ErrorAction SilentlyContinue;
    if ($proc){
        $proc = $proc[0];
        $memory = $proc.PM;
        if (! $memory){
            $memory=0;
        }
        $memory/=1024*1024*1024;
        if ($memory -gt $max){
            $max = $memory;
        }
        Write-Host  $(Get-Date -Format u) $memory.ToString("0.00") Max: $max.ToString("0.00");
        Start-Sleep -Seconds 60;
    }
}