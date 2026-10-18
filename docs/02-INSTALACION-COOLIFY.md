# 02 - Instalación con Coolify

Despliegue del servidor de coordinacion usando Coolify como orquestador.

---

## 1. Que cambia respecto de Docker directo

Coolify pone un proxy inverso propio (Traefik) delante de todo. Eso simplifica
el certificado TLS, pero introduce una diferencia importante:

> **Traefik no reenvia trafico UDP.** Solo HTTP y TCP.

Para este kit eso no es problema, porque la configuración entregada **no necesita
ningun puerto UDP en el servidor de coordinacion**. El DERP embebido esta
apagado. Si algun dia se enciende, Traefik no lo puede publicar y habria que
publicar ese puerto directamente en el host, fuera de Coolify.

---

## 2. Requisitos en Coolify

- Instancia de Coolify operativa.
- Un dominio apuntando al servidor, con el DNS gestionado por Coolify.
- Una base de datos en Coolify **no es necesaria**. Este kit usa SQLite.
  No crear ninguna.

---

## 3. Crear el recurso

1. New Resource.
2. Template de **Docker Compose**, no Dockerfile: este kit trae su propio
   `compose.yaml`.
3. Subir el directorio del kit.

Coolify detecta `compose.yaml` automáticamente. Si no lo hace, se indica el
archivo de forma explicita.

---

## 4. Ajustes que hay que hacer a mano

Coolify sobrescribe algunas cosas del compose. Revisar:

- **Variables de entorno**: copiar `.env.example` a `.env` en el repositorio o
  definirlas en la interfaz. Recordar que `HEADSCALE_BIND_ADDR` debe quedar en
  `127.0.0.1`.
- **Volumenes**: Coolify suele crear los bind mounts por su cuenta. Si se
  reemplaza el bind mount `./data` por un volumen nombrado, hay que confirmar que
  el usuario del contenedor pueda escribir. Este kit sigue el patron de upstream,
  que usa bind mounts.
- **Comando**: `serve`. Es el valor por defecto de la imagen.
- **Healthcheck**: `headscale health`. Es el mismo que usa el compose oficial de
  upstream.

---

## 5. Proxy y dominio

En Coolify, configurar un dominio para el servicio apuntando a un subdominio,
por ejemplo `acceso.ejemplo.cl`.

Coolify se encarga del certificado. Dos cosas que hay que tener presentes:

1. **`server_url` debe coincidir exactamente** con ese dominio, con `https` y sin
   barra final. Si no coincide, los clientes no se pueden autenticar.
2. **`trusted_proxies` hay que llenarlo.** Este es el punto que mas problemas da
   en Coolify. El proxy no esta en el mismo host: llega desde la red interna de
   Docker. Sin `trusted_proxies`, headscale no ve la direccion real de los
   clientes.

Determinar la IP del proxy y ponerla en `config.yaml`. Luego recargar:

```bash
docker kill -s HUP headscale
```

upstream advierte explicitamente en `config-example.yaml` v0.29.5 que declarar
`trusted_proxies` sin un proxy real delante permite que un cliente falsifique sus
cabeceras de origen. En Coolify si hay proxy real, así que la advertencia no
aplica, pero la IP debe ser la correcta.

---

## 6. Puertos

En Coolify, publicar **solo el puerto 443** hacia el exterior.

Los puertos 8080 y 9090 deben quedar accesibles **solo desde la red interna**,
para el proxy y para la supervision. Publicarlos hacia fuera anula el aislamiento.

| Puerto | Publicar en Coolify |
|---|---|
| 443 | **Si**, a traves del proxy |
| 8080 | Solo red interna |
| 9090 | Solo red interna |

---

## 7. Supervision

Coolify puede consultar el endpoint de salud:

```
/health
```

Devuelve 200 cuando el servicio responde. Es lo que usa el healthcheck oficial
también.

Para las metricas, el puerto 9090 expone metricas de Prometheus e información de
diagnóstico en `/debug`. **Esa información no debe salir a internet**: `debug`
da un volcado interno del proceso. Publicarlo es filtrar el estado del servidor
de coordinacion.

---

## 8. Actualizaciones

Coolify ofrece actualizar a la última imagen. **No usarlo con este kit.**

La imagen esta fijada por etiqueta y por digest. Si Coolify vuelve a resolver la
etiqueta, puede instalar una versión nueva sin avisar y sin que nadie haya
probado el cambio. Para actualizar hay que seguir el procedimiento de
`docs/06-ACTUALIZACIONES-Y-REVERSION.md`: leer la versión nueva, probarla en un
entorno de pruebas, y recien despues subirla.

---

## 9. Respaldo desde Coolify

Los scripts de respaldo de este kit asumen que el contenedor se llama
`headscale`, que es lo que fija el compose. En Coolify, el nombre puede
diferir. Si es el caso, cambiar la variable `CONTENEDOR` al principio de
`scripts/backup-headscale.sh` y de `scripts/restore-headscale.sh`.

El resto del procedimiento no cambia. Ver
`docs/05-RESPALDOS-Y-RESTAURACION.md`.

---

## 10. Cuando conviene Docker directo y no Coolify

Este kit es deliberadamente chico: un contenedor, un volumen, un proxy. Coolify
aporta valor cuando semanyan servicios en la misma VPS. Si es el caso de Hefesto,
Coolify es la opcion correcta y este documento aplica.

Si el servidor es exclusivo para el servicio de acceso remoto, Docker directo con
systemd es mas simple y deja menos piezas por mantener. Las dos opciones producen
el mismo resultado para el cliente.