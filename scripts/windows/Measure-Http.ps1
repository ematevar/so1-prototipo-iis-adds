[CmdletBinding()]
param([Parameter(Mandatory)][uri]$Url,[ValidateRange(5,3600)][int]$DurationSeconds=300,
 [ValidateRange(1,20)][int]$Rate=5,[string]$OutputDirectory=(Join-Path $PSScriptRoot '..\..\evidence\laboratorio'),
 [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9_-]+$')][string]$RunId)
$ErrorActionPreference='Stop'
if($Url.Scheme -notin @('http','https')){throw 'Sólo HTTP o HTTPS.'}
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$csv=Join-Path $OutputDirectory ($RunId+'.csv')
if(Test-Path -LiteralPath $csv){throw 'RunId existente: no se sobrescribe evidencia.'}
$rows=New-Object 'System.Collections.Generic.List[object]'
$clock=[Diagnostics.Stopwatch]::StartNew();$next=0.0
while($clock.Elapsed.TotalSeconds -lt $DurationSeconds){
 $wait=$next-$clock.Elapsed.TotalMilliseconds
 if($wait -gt 0){Start-Sleep -Milliseconds ([int]$wait)}
 if($clock.Elapsed.TotalSeconds -ge $DurationSeconds){break}
 $stamp=[DateTime]::UtcNow.ToString('o');$timer=[Diagnostics.Stopwatch]::StartNew();$status=0;$node='';$failure=''
 try{
  $r=Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 5 -Headers @{'Cache-Control'='no-cache'}
  $status=[int]$r.StatusCode;$node=[string]$r.Headers['X-Lab-Node']
 }catch{
  $failure=$_.Exception.Message
  if($_.Exception.Response){$status=[int]$_.Exception.Response.StatusCode}
 }
 $timer.Stop()
 $rows.Add([pscustomobject]@{utc=$stamp;status=$status;node=$node;elapsed_ms=[math]::Round($timer.Elapsed.TotalMilliseconds,3);error=$failure})
 $next += 1000.0/$Rate
 # No lanzar ráfagas para recuperar retrasos: medir y reportar tasa real.
 if($next -lt $clock.Elapsed.TotalMilliseconds){$next=$clock.Elapsed.TotalMilliseconds}
}
$clock.Stop();$rows | Export-Csv -LiteralPath $csv -NoTypeInformation -Encoding UTF8
$sorted=@($rows | ForEach-Object {$_.elapsed_ms} | Sort-Object)
$failed=@($rows | Where-Object {$_.status -lt 200 -or $_.status -ge 400}).Count
$summary=[ordered]@{run_id=$RunId;source='Windows HTTP client; confirmar IIS/ARR con configuración y logs';url=$Url.AbsoluteUri;requests=$rows.Count;failed=$failed;duration_seconds=$clock.Elapsed.TotalSeconds;target_rate=$Rate;achieved_rate=$rows.Count/$clock.Elapsed.TotalSeconds;p95_ms=$sorted[[math]::Max(0,[math]::Ceiling($sorted.Count*.95)-1)];note='No se infiere tiempo de detección de ARR ni disponibilidad anual a partir del primer éxito.'}
$summary | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $OutputDirectory ($RunId+'.json')) -Encoding UTF8
$summary
