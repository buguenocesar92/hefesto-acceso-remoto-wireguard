# VERSIÓN.md - Hefesto Studio, kit de acceso remoto seguro

Estado del kit: **preparado** (ver `docs/07-PRUEBAS-DE-ACEPTACION.md`)

---

## Componente elegido

| Dato | Valor |
|---|---|
| Producto | Headscale, servidor de coordinacion del ecosistema Tailscale |
| Versión fijada | **v0.29.5** |
| Fecha de publicación | 2026-10-13 |
| Licencia | BSD 3-Clause (archivo LICENSE en el tag v0.29.5) |
| Imagen | `docker.io/headscale/headscale:0.29.5` |

### Digests de la imagen

El `compose.yaml` fija etiqueta **y** digest. El digest que se usa es el indice
multiarquitectura, de modo que el mismo valor sirve en amd64 y en arm64.

```
indice (amd64 + arm64) : sha256:780ed2f9e85719a2211277433f2c8afb45105d0d25031949a6848a485f9e216d
linux/amd64            : sha256:0c6299f9333c072922a22c58dcec23af88be8bea4150be4475cdf0ad4f87a682
linux/arm64            : sha256:8ba61f76dc7ac48daf302a06cbb17788e2db06164c14266cc89782cdc5bf7287
```

Fuente de los digests: Docker Hub API para la etiqueta `0.29.5`.
<https://hub.docker.com/r/headscale/headscale/tags/0.29.5>

Espejo oficial alternativo en GitHub Container Registry:
`ghcr.io/juanfont/headscale`. El `.goreleaser.yml` del tag v0.29.5 pública en los
dos registros, pero este kit usa Docker Hub por ser el registro de distribucion
por defecto de la documentacion oficial.

### Imagen de cliente

No hay imagen de cliente propia. Los nodos usan las **aplicaciones oficiales de
Tailscale**. Eso es parte de la eleccion: el cliente ya existe, ya funciona en
Windows, macOS, Linux, Android, iOS y tvOS, y no hay que soportarlo a mano.

---

## Cliente Tailscale: que versiones son compatibles

Verificado en `docs/about/clients.md` del tag v0.29.5:

> We aim to support the **last 10 releases** of the Tailscale client on all
> provided operating systems and platforms.

Fuente: <https://github.com/juanfont/headscale/blob/v0.29.5/docs/about/clients.md>

Este punto es el principal riesgo técnico del producto y esta tratado de forma
deliberada. Ver la seccion "Riesgos" en `README.md` y el criterio de eleccion en
`LICENCIAS.md`.

**Regla operativa que Hefesto debe aplicar:** fijar por versión el cliente
Tailscale que se instala en los servidores del cliente, y probar el salto antes
de propagarlo. El cliente Tailscale se actualiza solo por defecto; en los
servidores hay que desactivar esa actualización automática o controlarla.

---

## Base de datos

| Dato | Valor |
|---|---|
| Motor | **SQLite** |
| Ruta | `/var/lib/headscale/db.sqlite` |
| Modo | WAL activado |

Este kit **no usa PostgreSQL** y **no es compatible con Supabase**. El motivo esta
documentado en `LICENCIAS.md` y es una cita textual de upstream, no una
preferencia de Hefesto.

---

## Puertos publicados por este kit

| Puerto en el host | Direccion | Propósito |
|---|---|---|
| 8080 | `127.0.0.1` | API de coordinacion, solo la consume el proxy inverso local |
| 9090 | `127.0.0.1` | Metricas y `/debug`, upstream lo marca como no público |

**Único puerto que debe abrirse en el firewall de la VPS: TCP 443.**
Todo lo demas es opcional y esta justificado en `docs/01-INSTALACION-DOCKER.md`.

No se abre ningun puerto UDP porque el DERP embebido esta apagado.

---

## Puerto WireGuard en los nodos

Los nodos usan el puerto UDP **41641** por defecto. Ese puerto se elige en el
cliente, no en el servidor de coordinacion, así que no se abre en la VPS.

En redes con CGNAT o conflictos de NAT, la política de este kit activa
`randomizeClientPort`, que hace que cada nodo use un puerto UDP aleatorio en vez
del fijo. Clave verificada en `docs/ref/policy.md` del tag v0.29.5.

---

## Dependencias del kit

| Dependencia | Versión usada | Nota |
|---|---|---|
| Docker Engine | 24 o superior | minimo recomendado |
| Docker Compose v2 | 2.24 o superior | usa `docker compose`, no `docker-compose` |
| bash 4 o superior | en el host | para los scripts de respaldo |
| `sha256sum` (coreutils) | cualquiera | obligatoria en backup y restauración |
| Tailscale (cliente) | ultimas 10 versiones | en los nodos del cliente |

---

## Fecha de verificación

Toda la información de este documento fue leida de los archivos del tag v0.29.5
el **17 de octubre de 2026**. No se ejecuto ningun contenedor: el kit se declara
`preparado` y no `probado`. El detalle de lo verificado y lo pendiente esta en
`docs/07-PRUEBAS-DE-ACEPTACION.md`.