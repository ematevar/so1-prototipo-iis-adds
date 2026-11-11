[CmdletBinding()]
param([Parameter(Mandatory)][string]$Path)
$ErrorActionPreference='Stop'
$cfg=Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
if($cfg.nodes.Count -ne 6){throw 'Se requieren seis nodos.'}
$addresses=@();$names=@()
foreach($node in $cfg.nodes){
 $parsed=$null
 if(-not $node.ip -or -not [System.Net.IPAddress]::TryParse([string]$node.ip,[ref]$parsed)){throw "IP real pendiente o inválida para $($node.name)."}
 if($parsed.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork){throw 'Sólo IPv4 en este diseño.'}
 $addresses += $parsed.IPAddressToString;$names += $node.name
}
if(@($addresses | Select-Object -Unique).Count -ne 6){throw 'Hay IP repetidas.'}
if(@($names | Select-Object -Unique).Count -ne 6){throw 'Hay nombres repetidos.'}
if(-not $cfg.network.prefixLength -or $cfg.network.prefixLength -lt 1 -or $cfg.network.prefixLength -gt 30){throw 'Falta prefijo válido del segmento.'}
function Convert-IPv4Number([string]$Value){
 $octets=([System.Net.IPAddress]::Parse($Value)).GetAddressBytes()
 return [uint64]$octets[0]*16777216+[uint64]$octets[1]*65536+[uint64]$octets[2]*256+[uint64]$octets[3]
}
$mask=[uint64]4294967295 -band ([uint64]4294967295 -shl (32-[int]$cfg.network.prefixLength))
$hostMask=[uint64]4294967295 -bxor $mask
$subnets=@()
foreach($address in $addresses){
 $octets=([System.Net.IPAddress]::Parse($address)).GetAddressBytes()
 $private=($octets[0] -eq 10) -or ($octets[0] -eq 172 -and $octets[1] -ge 16 -and $octets[1] -le 31) -or ($octets[0] -eq 192 -and $octets[1] -eq 168)
 if(-not $private){throw "La dirección $address no pertenece a RFC 1918. Confirmar un segmento privado autorizado para el diseño."}
 $number=Convert-IPv4Number $address
 if(($number -band $hostMask) -eq 0 -or ($number -band $hostMask) -eq $hostMask){throw "La dirección $address es de red o difusión para el prefijo indicado."}
 $subnets += ($number -band $mask)
}
if(@($subnets | Select-Object -Unique).Count -ne 1){throw 'Las seis IP no pertenecen a la misma subred.'}
if($cfg.network.gateway){
 if(((Convert-IPv4Number $cfg.network.gateway) -band $mask) -ne $subnets[0]){throw 'Gateway fuera de la subred.'}
}
Write-Output 'Formato, seis IP privadas distintas, hosts y subred común validados. La disponibilidad de IP, máscara autorizada y exclusión DHCP requieren confirmación del laboratorio.'
