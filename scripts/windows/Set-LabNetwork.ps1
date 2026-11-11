[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
param(
 [Parameter(Mandatory)][string]$InterfaceAlias,
 [Parameter(Mandatory)][System.Net.IPAddress]$IPAddress,
 [Parameter(Mandatory)][ValidateRange(1,30)][int]$PrefixLength,
 [System.Net.IPAddress]$Gateway,
 [Parameter(Mandatory)][System.Net.IPAddress[]]$DnsServers
)
$ErrorActionPreference='Stop'
if ($IPAddress.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) { throw 'Se requiere IPv4.' }
$principal=New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Ejecutar como administrador dentro de la VM.' }
$adapter=Get-NetAdapter -Name $InterfaceAlias
$current=@(Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object {$_.IPAddress -notlike '169.254.*'})
if ($current | Where-Object {$_.IPAddress -ne $IPAddress.IPAddressToString}) { throw 'La interfaz ya tiene otra IPv4. Revisar manualmente; este script no elimina direcciones existentes.' }
if ($current | Where-Object {$_.PrefixLength -ne $PrefixLength}) { throw 'La IPv4 existente tiene otro prefijo. Revisar la interfaz antes de cambiarla.' }
if (-not $PSCmdlet.ShouldProcess($InterfaceAlias, "Asignar $IPAddress/$PrefixLength y DNS del laboratorio")) { return }
if (-not $current) {
 $arguments=@{InterfaceIndex=$adapter.ifIndex;IPAddress=$IPAddress.IPAddressToString;PrefixLength=$PrefixLength}
 if ($Gateway) { $arguments.DefaultGateway=$Gateway.IPAddressToString }
 New-NetIPAddress @arguments | Out-Null
}
Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses @($DnsServers | ForEach-Object {$_.IPAddressToString})
Get-NetIPConfiguration -InterfaceIndex $adapter.ifIndex
