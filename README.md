# Continuidad · Prototipo IIS / AD DS

Repositorio académico de Sistemas Operativos I (UPT), preparado para subir a GitHub. Implementa una **PoC HTTP portable ejecutable** y contiene el sitio estático y las guías para el laboratorio Windows Server 2022. No afirma que la PoC Python sea IIS, ARR, AD DS o un ensayo en las estaciones universitarias.

## Probar ahora

Requisito: Python 3.10+; sin dependencias pip.

```sh
python demo/server.py
```

En Windows también puedes hacer doble clic en `INICIAR_DEMO.cmd`. Abre **http://127.0.0.1:8080**. El proxy usa 8080 y los dos backends 8081/8082. El panel puede detener e iniciar sus procesos HTTP internos, enviar solicitudes y exportar CSV. Los servidores sólo escuchan en loopback. Si un puerto está ocupado:

```sh
python demo/server.py --port 8090 --web1-port 8091 --web2-port 8092
```

`Ctrl+C` cierra los servidores. Un nodo detenido conserva su último estado hasta que el sondeo detecta el fallo: los errores transitorios son parte de lo que se registra.

## Comprobar funcionamiento

```sh
python -m unittest discover -s tests -v
python -m demo.validate
```

El segundo comando genera `evidence/portable/requests.csv` y `validation.json` con resultados reales de esa ejecución. Son ensayos cortos de Python en el equipo que los ejecuta; no sustituyen los 300 segundos, tres repeticiones ni la evidencia de Windows. `docs/downloads/validacion-portable.json` es la copia de la ejecución incluida en esta entrega, no una lectura en vivo.

## Qué contiene

| Ruta | Finalidad |
|---|---|
| `docs/` | Portal estático publicable en GitHub Pages, importador CSV y descargas |
| `web/` | Sitio HTML idéntico para desplegar en WEB01 y WEB02; endpoint `health.html` |
| `demo/` | Proxy y dos backends Python; Round Robin y sondeos HTTP |
| `scripts/windows/` | Inventario, validación de configuración, configuración explícita de red, dominio, IIS y ARR, medición HTTP |
| `config/lab.example.json` | Diseño de seis VMs; IP reales sin inventar |
| `guides/` | Despliegue, pruebas, evidencia y correspondencia con la evaluación |
| `evidence/portable/` | Evidencia de PoC ejecutada, con procedencia |
| `evidence/laboratorio/` | Sólo instrucciones; resultados Windows aún pendientes |

## Laboratorio que debes implementar

- HOST01: DC01, WEB01, LB01. HOST02: DC02, WEB02, CLIENT01.
- Cada estación: 32 GB RAM, SSD 512 GB, VirtualBox, red Ethernet existente.
- Cada VM: propuesta inicial de 4 GB RAM, 2 vCPU y VDI dinámico de 60 GB; validar CPU y espacio libre.
- Windows Server 2022 con Experiencia de Escritorio en los servidores; dominio propuesto `ad.so1.test`.
- Tres IP adicionales autorizadas por PC. Completa `config/lab.local.json` a partir del ejemplo; no lo publiques.
- Un balanceador ARR sigue siendo SPOF. GitHub Pages es documentación, no un balanceador ni un DC.

Lee [la guía de implementación](guides/laboratorio.md) y [los criterios de prueba](guides/criterios.md). Los scripts Windows que modifican servicios requieren elevación y admiten `-WhatIf`; no se ejecutaron contra IIS/AD DS durante esta entrega. No ejecutes scripts de roles en tu PC personal: corresponden a las VMs designadas.

## Subir a GitHub y activar Pages

1. Crea un repositorio vacío con la visibilidad que decida el equipo. Extrae el ZIP: sube **el contenido de esta carpeta**, incluidas `.github/`, `docs/`, `web/`, etc.
2. Revisa el PDF y la identidad de sus autores antes de hacerlo público. No subas `config/lab.local.json`, contraseñas, ISO, MSI, VDI, inventarios sin anonimizar o PDFs de terceros.
3. Si usas Git, desde esta carpeta:

   ```sh
   git init -b main
   git add .
   git commit -m "Agregar prototipo y portal académico"
   git remote add origin https://github.com/TU_USUARIO/TU_REPOSITORIO.git
   git push -u origin main
   ```

   Sustituye usuario y repositorio por los reales. No incrustes tokens en la URL.
4. En GitHub: **Settings → Pages → Source: GitHub Actions**. Ejecuta `Publicar portal en GitHub Pages` si no se lanzó al hacer push.
5. Guarda la URL real mostrada por Actions. El portal tiene rutas relativas compatibles con `https://usuario.github.io/repositorio/`.

No se ha creado un repositorio remoto ni publicado un sitio por este paquete. No se agregó una licencia de redistribución por defecto; el equipo debe decidirla para su código y documentación.

## Límites y resultado académico

La PoC demuestra routing HTTP, detección, failover y reintegración con sockets reales. No demuestra replicación de AD, SYSVOL, DNS de Windows, licencia, backup ni restauración de dominio. Para cerrar la evaluación faltan inventario real, configuración de IIS/ARR, seis IP, mediciones y evidencias según la guía. No se garantiza una nota por publicar el repositorio.
