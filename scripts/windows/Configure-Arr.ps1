[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
param([Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9.-]+$')][string]$Web01,
 [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9.-]+$')][string]$Web02,
 [string]$Portal='portal.ad.so1.test')
$ErrorActionPreference='Stop'
$appcmd=Join-Path $env:windir 'System32\inetsrv\appcmd.exe'
if(-not(Test-Path -LiteralPath $appcmd)){throw 'Instalar IIS en LB01 y luego URL Rewrite y ARR oficiales; ver guides/laboratorio.md.'}
if(-not $PSCmdlet.ShouldProcess($env:COMPUTERNAME,'Crear granja SO1Lab y regla global de proxy; sólo para LB01 dedicado')){return}
function Invoke-LabAppCmd { param([string[]]$Arguments)
 & $appcmd @Arguments
 if($LASTEXITCODE -ne 0){throw ('Falló AppCmd: '+($Arguments -join ' ')+'. Revisar el respaldo antes de reintentar.')}
}
Invoke-LabAppCmd @('list','config','-section:webFarms')
$existing=(& $appcmd list config '-section:webFarms' | Out-String)
if($existing -match 'name="SO1Lab"'){throw 'La granja SO1Lab ya existe. No se sobreescribe; revisar con IIS Manager.'}
Invoke-LabAppCmd @('add','backup',('Antes-SO1Lab-'+(Get-Date -Format yyyyMMddHHmmss)))
Invoke-LabAppCmd @('set','config','-section:system.webServer/proxy','/enabled:true','/commit:apphost')
Invoke-LabAppCmd @('set','config','-section:webFarms',"/+[name='SO1Lab']",'/commit:apphost')
foreach($backend in @($Web01,$Web02)){
 Invoke-LabAppCmd @('set','config','-section:webFarms',"/+[name='SO1Lab'].[address='$backend']",'/commit:apphost')
}
Invoke-LabAppCmd @('set','config','-section:system.webServer/rewrite/globalRules',"/+[name='SO1Lab_routes',patternSyntax='Wildcard',stopProcessing='True']",'/commit:apphost')
Invoke-LabAppCmd @('set','config','-section:system.webServer/rewrite/globalRules',"/[name='SO1Lab_routes'].match.url:*",'/commit:apphost')
Invoke-LabAppCmd @('set','config','-section:system.webServer/rewrite/globalRules',"/[name='SO1Lab_routes'].action.type:Rewrite","/[name='SO1Lab_routes'].action.url:http://SO1Lab/{R:0}",'/commit:apphost')
Invoke-LabAppCmd @('set','config','-section:webFarms',"/[name='SO1Lab'].applicationRequestRouting.healthCheck.url:http://$Portal/health.html","/[name='SO1Lab'].applicationRequestRouting.healthCheck.responseMatch:LAB_HEALTHY",'/commit:apphost')
Invoke-LabAppCmd @('set','config','-section:webFarms',"/[name='SO1Lab'].applicationRequestRouting.affinity.useCookie:False",'/commit:apphost')
Write-Output 'Revisar en IIS Manager: Weighted round robin / Even distribution, health interval 5 s propuesto, timeout 1 s propuesto; registrar valores efectivamente aceptados. Desactivar caché para los ensayos y verificar sondeos.'
Write-Output 'La automatización ARR no se ejecutó durante la validación portable. Comprobar antes de medir y exportar applicationHost.config.'
