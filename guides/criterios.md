# Requisitos, criterios y evidencias

Todos los umbrales son metas de diseño del documento. La ejecución portable no aprueba los casos Windows por equivalencia.

| Caso | Requisito o límite | Criterio y evidencia necesaria |
|---|---|---|
| CP-01 | RF-01 | Ambos IIS responden HTTP 200; hashes del contenido común iguales; cabeceras identifican el nodo. |
| CP-02 | RF-02 / RNF-03 | Cinco solicitudes/s durante 300 s; registrar tasa alcanzada. Meta éxito ≥99%, p95 ≤2 s; ambos nodos observados. |
| CP-03 | RF-02 / RNF-01 | Fallo de un backend a los 120 s; conservar t0, td y tr. Meta nuevas peticiones estables en ≤30 s, con todos los errores de transición. |
| CP-04 | RF-03 | Objeto de prueba visible en el otro DC en ≤120 s; repetir sentido inverso. No es garantía del protocolo. |
| CP-05 | RF-03 | DNS y operación de dominio con un DC apagado; evitar validar sólo caché o sesiones existentes. |
| CP-06 | RF-04 | CSV del cliente y logs de IIS exportados, identificados y con referencia horaria. |
| CP-07 | RF-05 / RNF-05 | Recuperación aislada desde copia; meta RPO 24 h y RTO 60 min. Medio independiente y resultado real registrados. |
| CP-08 | RNF-02 | Backend HTTP desde LB01 permitido y desde origen no autorizado bloqueado; dominio funcional. |
| CP-09 | RNF-04 | Procedimiento revisado para incorporar un nodo y estimación de recursos; no exige una séptima VM en el alcance inicial. |
| CP-10 | RNF-05/06 | Otro integrante reproduce la lista operativa y reintegra un nodo, sin pasos críticos omitidos, en ≤20 min. |
| CP-11 | Límite LB01 | Su apagado produce el corte esperado; registrar el SPOF, no declararlo mitigado. |
| CP-12 | DC01 / FSMO | Titulares, DNS, autenticación nueva y efecto del fallo temporal registrados; no incautar FSMO ni agotar RID. |
| CP-13 | HOST01 | CLIENT01 observa pérdida de LB01 y pares supervivientes. |
| CP-14 | HOST02 | Observador previo en HOST01; medir continuidad por WEB01. Sin observador, caso no ejecutado. |

## Formato de bitácora por ejecución

```text
RunId:
Fecha UTC / responsable:
Plataforma: Windows Server IIS/ARR o PoC Python (elegir la real)
Versiones / archivo de configuración:
URL / carga propuesta / tasa alcanzada:
Health check: intervalo / timeout / umbral efectivo:
Caché / afinidad / reintentos:
t0 fallo / td detección / tr inicio de 30 s de éxito:
Errores y solicitudes totales / p95:
Archivos CSV / logs / capturas:
Resultado: aprobado, fallido o no ejecutado
Incidencias / cambios / limitaciones:
```

Separa un backend de referencia, dos backends activos y fallo/reintegración. Conserva tres repeticiones por escenario, incluso las fallidas. No proyectes disponibilidad anual a partir de minutos de ensayo.

## Correspondencia con la evaluación

| Exigencia | Incluido en el repositorio | Pendiente de campo o del equipo |
|---|---|---|
| Diseño de 14 secciones | PDF descargable y cuatro diagramas | Revisión y sustentación de autores |
| Citas y referencias | Registro de consulta de DOI y bibliografía del informe | Comprobación crítica de pertinencia y fuentes restantes |
| Prototipo funcional | HTTP real portable, pruebas y datos brutos | IIS/ARR, AD DS/DNS, SYSVOL y restore reales |
| Infraestructura y red | Seis VMs, guía y validación de configuración | CPU, espacio libre, seis IP, máscara y MAC puente |
| Seguridad | Límites, controles y guías | Configuración aplicada y evidencia del firewall/backup |
| GitHub / sitio con descargas | Workflow Pages y portal estático | Crear repositorio, activar Pages y registrar URL real |
| Drive/OneDrive | Lista de archivos que se pueden subir | Carpeta real y enlace del usuario |
| Word / presentación | PDF y guía de exposición | Crear y revisar esos entregables por separado |

Subir la PoC y sus logs no elimina la falta de datos de las estaciones del laboratorio. No se promete una nota.
