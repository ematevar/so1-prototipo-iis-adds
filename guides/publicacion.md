# Publicación y paquete de entrega

1. Publica el contenido de la raíz en un repositorio propio. El workflow Pages sólo publica `docs/`; `demo/` y los scripts no se ejecutan en GitHub Pages.
2. En **Settings → Pages** selecciona **GitHub Actions**. Guarda la URL real devuelta por el workflow. La disponibilidad depende de la configuración y plan de GitHub.
3. Los resultados de las pruebas CI se encuentran en **Actions → Comprobar prototipo → Artifacts**. La primera ejecución debe terminar antes de presentarla como evidencia.
4. Descarga el PDF desde el portal y comprueba sus rutas. Si actualizas el informe, reemplaza `docs/downloads/informe.pdf` y revisa coherencia con los scripts.
5. Copia a tu Drive/OneDrive el informe, presentación cuando exista, resultados y vínculo al repositorio. No se crea un enlace ficticio en este paquete.
6. Entrega las URL reales del repositorio, Pages y Drive. Mantén visibles las diferencias entre demostración Python y laboratorio Windows.

## Antes de hacer público

- Revisa los autores del PDF y acuerda su publicación.
- Elimina datos institucionales sensibles de capturas/logs.
- No publiques `lab.local.json`, credenciales, contraseñas DSRM, certificados privados, instaladores o discos.
- No publiques la carpeta FUENTES con PDFs de terceros. La bibliografía y los enlaces son suficientes para este paquete.
- Este repositorio no asigna automáticamente una licencia. Define con el equipo los permisos de su código y documento.
