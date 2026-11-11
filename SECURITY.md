# Seguridad y publicación

- La API de control sólo existe en la PoC local y escucha en 127.0.0.1. No la expongas mediante túneles, port-forwarding o bind público.
- Las peticiones de control requieren encabezado propio; un origen web ajeno es rechazado. No es una API de producción ni una plataforma multiusuario.
- Revisa datos personales, hostnames e IP antes de subir evidencias. El documento de diseño contiene autores: confirma su publicación con el equipo.
- Conserva contraseñas, DSRM, archivos de configuración locales, certificados privados e inventarios de red fuera de Git.
- Los scripts de red y roles están destinados a VMs del proyecto, requieren elevación y deben revisarse con `-WhatIf`.
- La carpeta de laboratorio se excluye por defecto. Agrega sólo evidencia revisada; nunca discos virtuales, instaladores o material bibliográfico de terceros.
