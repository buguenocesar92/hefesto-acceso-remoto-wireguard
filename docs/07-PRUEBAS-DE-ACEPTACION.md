# 07 - Pruebas de aceptacion y estado real del kit

Este documento separa dos cosas que a menudo se mezclan:

- **Lo verificado**: leido de fuentes oficiales, con direccion.
- **Lo pendiente**: razonado, pero no ejecutado.

---

## 1. Estado del kit

| Aspecto | Estado |
|---|---|
| Estado declarado | **preparado** |
| Contenedores construidos | Ninguno |
| Despliegues de prueba | Ninguno |
| Pruebas de penetracion | Ninguna |

**No se ejecuto nada.** En el equipo donde se escribio este kit no hay Docker ni
servidor. Todo lo que sigue se verifico leyendo documentacion y código fuente
oficial, no probando.

La diferencia importa: un `compose.yaml` verificado contra la documentacion
oficial tiene probabilidades altas de funcionar a la primera, pero no esta
probado. Un kit que se declara probado sin pruebas es una mentira comercial.

---

## 2. Lo que SI se verifico, con fuente

Todo lo de esta tabla se leyo directamente del tag v0.29.5 de Headscale, el
17 de octubre de 2026.

### 2.1 Licencia

| Afirmacion | Fuente |
|---|---|
| BSD 3-Clause, sin excepciones | [`LICENSE`](https://github.com/juanfont/headscale/blob/v0.29.5/LICENSE) |
| NetBird es BSD-3 **salvo** `management/`, `signal/`, `relay/`, `combined/`, que son AGPLv3 | [`LICENSE`](https://github.com/netbirdio/netbird/blob/v0.81.2/LICENSE) |

### 2.2 Versión e imagen

| Afirmacion | Fuente |
|---|---|
| Versión estable v0.29.5, publicada el 2026-10-13 | API de releases de GitHub |
| Digest del indice multiarquitectura | `sha256:780ed2f9e85719a2211277433f2c8afb45105d0d25031949a6848a485f9e216d` |
| Digest linux/amd64 | `sha256:0c6299f9333c072922a22c58dcec23af88be8bea4150be4475cdf0ad4f87a682` |
| Digest linux/arm64 | `sha256:8ba61f76dc7ac48daf302a06cbb17788e2db06164c14266cc89782cdc5bf7287` |

Fuente de los digests: <https://hub.docker.com/r/headscale/headscale/tags/0.29.5>

### 2.3 Base de datos

| Afirmacion | Fuente |
|---|---|
| SQLite es el valor por omision | `config-example.yaml` v0.29.5 |
| upstream dice que PostgreSQL es "highly discouraged" y "only supported for legacy reasons" | `config-example.yaml` v0.29.5 |
| Ruta de la base: `/var/lib/headscale/db.sqlite` | `config-example.yaml` v0.29.5 |

**De ahi sale la exclusion de Supabase.** No es una preferencia del kit: es lo
que dice upstream. Si la opcion elegida no usa PostgreSQL, no se fuerza.

### 2.4 Puertos

De `docs/setup/requirements.md` del tag v0.29.5:

| Puerto | Protocolo | Upstream dice |
|---|---|---|
| 80 | TCP | Si se usa el certificado interno de Let's Encrypt |
| 443 | TCP | **Obligatorio** para los clientes |
| 3478 | UDP | **Solo** si se usa el DERP embebido |
| 50443 | TCP | **Solo** si se usa la interfaz gRPC |
| 9090 | TCP | **No** exponer publicamente |

De ahi sale que este kit abre **solo TCP 443**.

### 2.5 Comandos de incorporacion

De `docs/ref/registration.md` del tag v0.29.5:

| Comando | Verificado |
|---|---|
| `headscale users create <NOMBRE>` | Si |
| `headscale preauthkeys create --user <ID>` | Si |
| `headscale preauthkeys create --tags tag:<ETIQUETA>` | Si |
| `tailscale up --login-server <URL> --authkey <CLAVE>` | Si |
| Las claves expiran en una hora | Si |
| Los nodos con etiqueta no caducan | Si |

### 2.6 Comandos de revocacion

Verificados leyendo el código fuente de `cmd/headscale/cli/nodes.go` del tag
v0.29.5, no solo la documentacion:

| Comando | Alias en el fuente | Verificado |
|---|---|---|
| `headscale nodes expire --identifier <ID>` | `logout`, `exp`, `e` | Si |
| `headscale nodes delete --identifier <ID>` | `del` | Si, pide confirmacion |
| `headscale nodes rename <NOMBRE> --identifier <ID>` | - | Si |
| `headscale nodes tag --identifier <ID> --tags <...>` | - | Si |
| `headscale nodes approve-routes --identifier <ID> --routes <...>` | - | Si |
| `headscale nodes backfillips` | - | Si |
| `headscale nodes register` | - | **Deprecado** en el fuente |
| `headscale auth register --user <U> --auth-id <ID>` | - | Si, es el reemplazo |

### 2.7 Política de segmentacion

De `docs/ref/policy.md` del tag v0.29.5:

| Afirmacion | Verificado |
|---|---|
| Sin política, headscale **permite todo** el trafico entre nodos | Si |
| Denegar todo es `{"grants": []}` | Si |
| upstream recomienda `grants` y considera `acls` legado | Si |
| Formato huJSON, admite comentarios | Si |
| Autogroups: `member`, `tagged`, `self`, `internet`, `nonroot`, `danger-all` | Si |
| `randomizeClientPort` existe y usa un puerto UDP aleatorio en vez del 41641 | Si |
| Recargar la política requiere `systemctl reload` o SIGHUP | Si |
| No soporta `postures` ni conjuntos de IP | Si |

### 2.8 Construccion de la imagen

De `.goreleaser.yml` del tag v0.29.5:

- Se construye con **KO**, sobre `gcr.io/distroless/base-debian13`.
- Pública en `ghcr.io/juanfont/headscale` y en Docker Hub.

---

## 3. Lo que NO se verifico, y queda pendiente de prueba

Esta lista es el trabajo real que queda. Cada punto necesita una prueba
ejecutada, no una lectura.

### 3.1 Antes de poner esto en un cliente

| Prueba | Como | Por que importa |
|---|---|---|
| El contenedor levanta con el `compose.yaml` de este kit | `docker compose up -d` | Ninguna combinacion fue probada |
| El healthcheck reporta `healthy` | `docker compose ps` | Es el detector de fallos |
| La CLI funciona sobre el socket Unix | `docker compose exec headscale headscale users list` | La administración depende de esto |
| Se crea un usuario y una clave | `users create`, `preauthkeys create` | Es el arranque del servicio |
| Un equipo real se une por HTTPS | `tailscale up --login-server ... --authkey ...` | La función central del producto |
| Se entra por SSH a un servidor usando la IP privada | `ssh usuario@100.64.x.x` | La promesa comercial |
| La política segmenta de verdad | Intentar un flujo **no** permitido y comprobar que se rechaza | **La mas importante de todas** |

### 3.2 Riesgo conocido, sin probar

- **Permisos de `data/`.** La imagen se construye con KO sobre una base
  distroless, y el usuario efectivo del contenedor **no se verifico**
  experimentalmente. upstream usa montajes bind en su compose oficial y este kit
  sigue el mismo patron, pero hay que confirmar en el primer despliegue que el
  contenedor puede escribir en `data/`.
- **`trusted_proxies` con proxy en otro contenedor.** La direccion desde la que
  llega la peticion en Coolify no se verifico. Queda como ajuste por instalación.
- **`config/policy.hujson`:** se escribio con sintaxis verificada contra la
  documentacion, pero **nunca se hizo que headscale lo cargara**. Si hubiera un
  error de sintaxis, el servicio no levanta. Probarlo es lo primero.
- **`tagOwners`:** se deja comentado justamente porque el formato exacto del
  nombre de usuario en la política debe verificarse.
- **Formato del segmento `ip`:** se usaron las formas que aparecen en la
  documentacion (`"*"` y `"80,443"`). Confirmar que `"22"` a secas es aceptado.
- **Cliente Tailscale en Windows, macOS, Android, iOS y tvOS:** upstream
  documenta pasos adicionales para esas plataformas. Si el cliente final usa
  esos sistemas, hay que probarlos uno por uno.

### 3.3 DERP

Este kit entrega el mapa DERP público de Tailscale. Hay que decidir con el
cliente si eso es aceptable.

- Si la red tiene pocos nodos, casi siempre hay conexión directa y el relay no
  se usa. Se puede comprobar mirando el estado de los nodos.
- Si hay nodos detras de CGNAT, el relay se usa y el trafico pasa por un tercero.
  Sigue cifrado, pero el tercero ve metadatos de conexión.

Medirlo en `docs/07`, seccion siguiente, antes de venderlo como "red privada
autosuficiente".

---

## 4. Lista de aceptacion para desplegar en un cliente

Ejecutar en orden. **No cerrar hasta que todo quede en OK.**

```
[ ]  1.  docker compose config valida
[ ]  2.  contenedor en estado healthy
[ ]  3.  headscale health responde
[ ]  4.  usuario creado
[ ]  5.  clave de incorporacion emitida y usada una sola vez
[ ]  6.  maquina piloto unida a la red
[ ]  7.  la politica segmenta carga sin error
[ ]  8.  SSH permitido desde la red privada
[ ]  9.  SSH DENEGADO entre segmentos no autorizados   <- la mas importante
[ ] 10.  puerto 22 del servidor cerrado al exterior
[ ] 11.  solo TCP 443 abierto en el firewall
[ ] 12.  respaldo generado
[ ] 13.  sha256sum -c del respaldo da OK
[ ] 14.  respaldo restaurado en aislamiento y verificado
[ ] 15.  documento lo que se abrio al mundo, firmado por el cliente
```

Los puntos 9, 11 y 15 son los que sostienen la promesa comercial. Si alguno falla,
no es un detalle: es el servicio que se vendio.

---

## 5. DERP: comprobar si se usa o no

```bash
tailscale status
# columna "direct" o columna de tipo de conexión
```

Y en el lado del servidor:

```bash
docker compose logs headscale | grep -i derp
```

Si los nodos se conectan directos, el DERP no participa y el mapa público de
Tailscale es irrelevante en la práctica. Si hay relaying, hay que decidir
explicitamente si el cliente lo acepta.

---

## 6. Conclusion honesta

El kit esta **preparado**: la configuración es coherente con la documentacion
oficial del tag exacto, las versiones estan fijadas por digest, los puertos estan
minimizados y los comandos de revocacion se verificaron en el código fuente.

No esta **probado**: no se levanto un contenedor.

La distancia entre las dos cosas es corta y se cierra con una tarde de pruebas
en un entorno limpio. Hasta que se cierre, **no prometer al cliente que ya esta
funcionando**: prometer que Hefesto lo instala, lo prueba y lo deja andando. Esa
es una promesa que se puede cumplir, y es parte del servicio.