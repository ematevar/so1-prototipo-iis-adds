# Despliegue real: VirtualBox y Windows Server 2022

## 0. Qué debes confirmar

Dos estaciones, permisos, RAM e ISO ya fueron informados por el equipo. Todavía debes obtener: CPU y virtualización habilitada, espacio libre, versión de VirtualBox, seis IP autorizadas, máscara, gateway si corresponde y autorización de MAC virtuales. Ejecuta `scripts/windows/Recolectar_inventario.ps1` en **cada estación**; no utilices el inventario de otro equipo como evidencia universitaria.

Completa `config/lab.local.json` copiando el ejemplo. Usa tres IP adicionales para las tres VMs de cada estación, no las IP de los anfitriones. Valida formato:

```powershell
.\scripts\windows\Test-LabConfig.ps1 -Path .\config\lab.local.json
```

Esto no prueba que estén libres. Confirma su asignación y exclusión DHCP con el responsable del laboratorio. No escanees rangos universitarios para inventariar equipos ajenos.

## 1. Aprovisionar seis VMs

| Anfitrión | VMs | Recursos iniciales por VM |
|---|---|---|
| HOST01 | DC01, WEB01, LB01 | 4 GB RAM; 2 vCPU; 60 GB VDI dinámico |
| HOST02 | DC02, WEB02, CLIENT01 | 4 GB RAM; 2 vCPU; 60 GB VDI dinámico |

Usa adaptador puente asociado a la NIC Ethernet activa. No uses Red Interna como enlace entre hosts. La instalación inicial se realiza desde la ISO con Experiencia de Escritorio. Comprueba la licencia o evaluación válida; disponer de ISO no acredita licencia.

Antes de la sesión prepara instaladores oficiales de URL Rewrite y ARR 3, actualizaciones aplicables y hashes SHA256. El laboratorio puede instalar desde ese paquete sin asumir Internet. No incluimos ni redistribuimos ISO/MSI. Verifica firmas digitales y procedencia.

En cada VM, renombra y reinicia antes de instalar roles:

```powershell
# Ejemplo en la VM que será WEB01; adapta al nombre asignado.
Rename-Computer -NewName WEB01 -Restart
```

Luego asigna red con los valores reales; el siguiente patrón se debe completar, no ejecutar literalmente:

```powershell
# Primero revisa -WhatIf. IP_REAL y prefijo provienen del laboratorio.
.\scripts\windows\Set-LabNetwork.ps1 -InterfaceAlias 'Ethernet' -IPAddress IP_REAL -PrefixLength PREFIJO_REAL -DnsServers IP_DC01,IP_DC02 -WhatIf
```

El script no elimina otras IPv4: si hay configuración previa, revisa la NIC manualmente. Si se necesita salida, añade `-Gateway GATEWAY_REAL`. Para promover DC01, usa su propia IP como DNS inicial; para DC02 antes de promoción, usa DC01. Revisa ambos DNS tras comprobar replicación. No configures DNS públicos como servidores alternativos de los miembros del dominio.

## 2. Crear dominio y controlador adicional

En DC01:

```powershell
.\scripts\windows\Configure-Domain.ps1 -Mode Forest -WhatIf
.\scripts\windows\Configure-Domain.ps1 -Mode Forest
```

El script solicita DSRM de forma segura. Comprueba el resultado y reinicia. En DC02, con DNS apuntando a DC01:

```powershell
.\scripts\windows\Configure-Domain.ps1 -Mode AdditionalDC -WhatIf
.\scripts\windows\Configure-Domain.ps1 -Mode AdditionalDC
```

Solicita credencial de dominio; no la escribas en un archivo. Reinicia y verifica:

```powershell
repadmin /replsummary
dcdiag /test:dns
Get-ADDomainController -Filter *
Get-SmbShare -Name SYSVOL,NETLOGON
```

Comprueba SYSVOL/DFSR además de DRS. Une WEB01, WEB02, LB01 y CLIENT01 al dominio, con credencial solicitada en consola:

```powershell
Add-Computer -DomainName ad.so1.test -Credential (Get-Credential) -Restart
```

En DNS crea el registro `portal` de la zona `ad.so1.test` con la **IP real de LB01**. Documenta N/M/G y reenviadores; si no se requiere Internet, no añadas reenviadores externos por suposición.

## 3. Instalar el sitio en WEB01 y WEB02

Copia el repositorio completo a cada VM. En WEB01, desde PowerShell elevado:

```powershell
.\scripts\windows\Configure-WebNode.ps1 -NodeName WEB01 -BalancerIP IP_REAL_LB01 -ReplaceDefaultSite -WhatIf
.\scripts\windows\Configure-WebNode.ps1 -NodeName WEB01 -BalancerIP IP_REAL_LB01 -ReplaceDefaultSite
```

En WEB02 usa `-NodeName WEB02`. El parámetro `-ReplaceDefaultSite` autoriza detener el sitio predeterminado en una VM nueva; no se usa sobre un IIS ajeno. El sitio queda en `C:\LabIIS\web`, con cabecera `X-Lab-Node` distinta por nodo. Los archivos HTML son iguales.

Comprueba localmente `http://localhost/health.html`; debe responder `LAB_HEALTHY`. Desde LB01 comprueba ambos servidores. Para una prueba directa desde CLIENT01 crea una excepción de firewall temporal y retírala al terminar. Audita otras reglas permisivas de TCP 80: añadir una regla restringida no cancela una regla amplia existente.

## 4. Configurar LB01 con IIS y ARR

Instala el rol IIS con consola de administración y los paquetes oficiales URL Rewrite y ARR. Conserva versión, firmas y hashes. Comprueba que IIS Manager muestre **Server Farms**; si no aparece, detén el procedimiento y revisa la instalación.

```powershell
Install-WindowsFeature Web-Server,Web-Mgmt-Console -IncludeManagementTools
.\scripts\windows\Configure-Arr.ps1 -Web01 web01.ad.so1.test -Web02 web02.ad.so1.test -WhatIf
.\scripts\windows\Configure-Arr.ps1 -Web01 web01.ad.so1.test -Web02 web02.ad.so1.test
```

El script sigue las secciones de configuración documentadas y se detiene si la granja ya existe; respalda la configuración antes de modificarla. No fue probado sobre Windows Server durante la entrega portable. Si falla una operación intermedia, inspecciona el respaldo e IIS Manager antes de reintentar; no elimines reglas ajenas.

En IIS Manager revisa y guarda capturas:

1. Granja **SO1Lab** con dos destinos de puerto HTTP 80.
2. **Load Balance:** Weighted round robin con distribución igual.
3. **Health Test:** URL del portal terminada en `/health.html`, coincidencia `LAB_HEALTHY`. Propón intervalo 5 s y timeout 1 s; registra valores que acepte la instalación y mide su efecto. No infieras que cumplen 30 s sin ensayo.
4. **Server Affinity:** cookies desactivadas para esta página sin sesión.
5. Revisa caché de ARR e IIS; desactívala para la campaña comparativa y documenta reintentos.
6. HTTP entrante a LB01 permitido desde CLIENT01 y el observador autorizado. No añadas reglas de dominio incompletas: conserva las del rol, revisa alcance y valida DNS, RPC, Kerberos, SMB y DFSR.

## 5. Medir y obtener evidencia

Desde CLIENT01:

```powershell
.\scripts\windows\Measure-Http.ps1 -Url http://portal.ad.so1.test/health.html -RunId CP02_R1
```

Produce CSV y JSON, con tasa realmente alcanzada. El medidor secuencial no promete sostener 5 solicitudes/s cuando las respuestas tardan: si no sostiene carga comparable, ajusta y documenta el generador antes de comparar resultados.

Para CP-03 registra t0 al detener **LabWeb** en una VM backend. Conserva la pantalla de ARR que muestre la exclusión, los logs y los eventos. Restablece con `Start-Website -Name LabWeb`. No apagues el DC accidentalmente. Repite cada escenario tres veces. El primer éxito no es automáticamente td ni tr; aplica los criterios del documento.

Para CP-12 registra titulares FSMO antes de apagar temporalmente DC01 y prueba DNS y autenticación **nueva** contra DC02. No incautes roles ni agotes pools RID en un ensayo temporal.

Para CP-13, CLIENT01 observa el apagado de HOST01: debe registrar el corte previsto de LB01. Para CP-14 prepara primero un medidor en HOST01; CLIENT01 desaparece cuando se apaga HOST02. Si el observador no está listo, registra el caso como no ejecutado.

## 6. Recuperación y cierre

Windows Server Backup y el respaldo de estado del sistema requieren un destino definido y una prueba de restauración aislada. Un VDI en el mismo SSD no protege de pérdida física de ese SSD. No declares regla 3-2-1 cumplida hasta tener copias y medios reales. Nunca restaures un DC por snapshot indiscriminadamente.

Exporta evidencias y apaga cliente, proxy y backends antes de cerrar los DC. Documenta incidencias, cambios y resultados. Publica sólo la evidencia revisada y sin secretos.

## Referencias técnicas primarias

- [Creación de granja ARR](https://learn.microsoft.com/en-us/iis/extensions/configuring-application-request-routing-arr/define-and-configure-an-application-request-routing-server-farm)
- [Balanceo y comprobaciones ARR](https://learn.microsoft.com/en-us/iis/extensions/configuring-application-request-routing-arr/http-load-balancing-using-application-request-routing)
- [Descarga oficial ARR](https://www.iis.net/downloads/microsoft/application-request-routing)
- [Redes VirtualBox](https://docs.oracle.com/en/virtualization/virtualbox/7.2/user/networkingdetails.html)
- [Restauración de DC virtualizados](https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/get-started/virtual-dc/virtualized-domain-controller-deployment-and-configuration)
