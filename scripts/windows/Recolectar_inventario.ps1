param([string]$Destino = (Join-Path $PSScriptRoot 'evidencia_inventario'))
$ErrorActionPreference = 'Stop'
# Sólo consulta datos locales. No instala ni modifica red, roles o máquinas virtuales.
New-Item -ItemType Directory -Path $Destino -Force | Out-Null
$equipoNombre = $env:COMPUTERNAME
$marcaTiempo = Get-Date -Format 'yyyyMMdd_HHmmss'
$prefijoSalida = Join-Path $Destino ($equipoNombre + '_' + $marcaTiempo)
$equipoInfo = Get-CimInstance Win32_ComputerSystem
$procesadoresInfo = Get-CimInstance Win32_Processor
$sistemaInfo = Get-CimInstance Win32_OperatingSystem
$datosInventario = [ordered]@{
    FechaLocal = (Get-Date).ToString('o')
    Equipo = $equipoNombre
    SistemaOperativo = $sistemaInfo.Caption
    VersionSO = $sistemaInfo.Version
    RAM_GB = [math]::Round($equipoInfo.TotalPhysicalMemory / 1GB, 2)
    Procesadores = @($procesadoresInfo | Select-Object Name, NumberOfCores, NumberOfLogicalProcessors, VirtualizationFirmwareEnabled, SecondLevelAddressTranslationExtensions)
    DiscosLocales = @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | Select-Object DeviceID, @{N='CapacidadGB';E={[math]::Round($_.Size/1GB,2)}}, @{N='LibreGB';E={[math]::Round($_.FreeSpace/1GB,2)}})
    InterfacesIPv4 = @(Get-NetIPConfiguration | Select-Object InterfaceAlias, InterfaceDescription, @{N='IPv4';E={$_.IPv4Address.IPAddress}}, @{N='Prefijo';E={$_.IPv4Address.PrefixLength}}, @{N='Gateway';E={$_.IPv4DefaultGateway.NextHop}}, @{N='DNS';E={$_.DNSServer.ServerAddresses}})
}
$vboxComando = Get-Command VBoxManage.exe -ErrorAction SilentlyContinue
$vboxRuta = if ($vboxComando) { $vboxComando.Source } else { Join-Path $env:ProgramFiles 'Oracle\VirtualBox\VBoxManage.exe' }
if (Test-Path -LiteralPath $vboxRuta) {
    $datosInventario.VirtualBox = (& $vboxRuta --version | Out-String).Trim()
} else {
    $datosInventario.VirtualBox = 'No detectado; comprobar instalación y ruta.'
}
$datosInventario | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath ($prefijoSalida + '.json') -Encoding UTF8
$datosInventario | Format-List | Out-String -Width 160 | Set-Content -LiteralPath ($prefijoSalida + '.txt') -Encoding UTF8
Write-Output ('Inventario local guardado en: ' + $prefijoSalida + '.json')
Write-Output 'Revisar antes de compartir: contiene nombre del equipo y configuración de red. No incluye contraseñas.'
