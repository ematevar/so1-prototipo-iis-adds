[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
param([Parameter(Mandatory)][ValidateSet('WEB01','WEB02')][string]$NodeName,
 [Parameter(Mandatory)][System.Net.IPAddress]$BalancerIP,
 [switch]$ReplaceDefaultSite,
 [string]$PhysicalPath='C:\LabIIS\web')
$ErrorActionPreference='Stop'
$source=Join-Path $PSScriptRoot '..\..\web'
if(-not(Test-Path -LiteralPath (Join-Path $source 'index.html'))){throw 'No se encontró el directorio web del repositorio.'}
if(-not $PSCmdlet.ShouldProcess($env:COMPUTERNAME,"Configurar LabWeb con identidad $NodeName y HTTP sólo desde $BalancerIP")){return}
Install-WindowsFeature Web-Server,Web-Static-Content,Web-Http-Logging,Web-Mgmt-Console -IncludeManagementTools | Out-Null
Import-Module WebAdministration
if(Get-Website -Name LabWeb -ErrorAction SilentlyContinue){throw 'LabWeb ya existe. Revisar su configuración antes de aplicar cambios.'}
$port80=@(Get-WebBinding | Where-Object {$_.bindingInformation -match ':80:'})
if($port80.Count -gt 0){
 if(-not $ReplaceDefaultSite){throw 'Hay un sitio en puerto 80. Usar -ReplaceDefaultSite sólo en una VM de laboratorio nueva.'}
 if(@(Get-Website | Where-Object {$_.Name -ne 'Default Web Site'}).Count -gt 0){throw 'Existen sitios distintos del predeterminado; no se modifican automáticamente.'}
}
Backup-WebConfiguration -Name ('Antes-LabWeb-'+(Get-Date -Format yyyyMMddHHmmss))
if($port80.Count -gt 0){Stop-Website -Name 'Default Web Site'}
New-Item -ItemType Directory -Force -Path $PhysicalPath | Out-Null
Copy-Item -Path (Join-Path $source '*') -Destination $PhysicalPath -Recurse -Force
New-WebAppPool -Name LabWebPool | Out-Null
New-Website -Name LabWeb -Port 80 -PhysicalPath $PhysicalPath -ApplicationPool LabWebPool | Out-Null
Set-WebConfigurationProperty -PSPath 'IIS:\' -Location LabWeb -Filter 'system.webServer/security/authentication/anonymousAuthentication' -Name enabled -Value $true
Add-WebConfigurationProperty -PSPath 'IIS:\' -Location LabWeb -Filter 'system.webServer/httpProtocol/customHeaders' -Name '.' -Value @{name='X-Lab-Node';value=$NodeName}
# No eliminar ACL heredadas: dar lectura a las identidades empleadas.
& icacls.exe $PhysicalPath /grant 'IUSR:(OI)(CI)(RX)' 'IIS_IUSRS:(OI)(CI)(RX)' | Out-Null
if($LASTEXITCODE -ne 0){throw 'No fue posible aplicar permisos de lectura.'}
# Las reglas amplias del rol deben revisarse: una regla restrictiva no anula otra permisiva.
Get-NetFirewallRule -Name 'IIS-WebServerRole-HTTP-In-TCP' -ErrorAction SilentlyContinue | Disable-NetFirewallRule
New-NetFirewallRule -DisplayName 'SO1 LabWeb HTTP desde LB01' -Direction Inbound -Protocol TCP -LocalPort 80 -RemoteAddress $BalancerIP.IPAddressToString -Action Allow | Out-Null
Write-Output 'Configurado. Auditar todas las reglas entrantes de TCP 80 y comprobar X-Lab-Node. Respaldar no equivale a probar restauración.'
