# 10 - Licencias, fuentes y trazabilidad

Este documento deja por escrito de donde salio cada afirmacion técnica del kit,
para que cualquiera pueda verificarla sin confiar en Hefesto.

Fecha de verificación: **17 de octubre de 2026**.

---

## 1. Software incluido

| Componente | Versión | Licencia | Rol |
|---|---|---|---|
| Headscale | v0.29.5 | BSD 3-Clause | Servidor de coordinacion |
| Tailscale (cliente) | Ultimas 10 versiones soportadas | Licencia propia de Tailscale Inc. | Cliente en los nodos |

### 1.1 Headscale

BSD 3-Clause, verificada en el archivo LICENSE del tag v0.29.5:

<https://github.com/juanfont/headscale/blob/v0.29.5/LICENSE>

Permite uso comercial, redistribucion, modificacion y reventa. Condiciones:

1. Conservar el aviso de copyright.
2. Conservar el texto de la licencia.
3. No usar el nombre de los autores para respaldar sin permiso.

Ninguna de las tres impide cobrar por un servicio gestionado.

### 1.2 Tailscale

**Este kit no distribuye ni reempaqueta el cliente.** Los nodos instalan las
aplicaciones oficiales de Tailscale, que se gobiernan por los terminos de
Tailscale Inc. y que Hefesto no controla ni modifica.

Hay que decirlo con claridad en el contrato con el cliente: **la licencia de
Headscale es del kit; la del cliente es de Tailscale.** Son dos cosas distintas y
no hay que mezclarlas.

Fuente: <https://tailscale.com/>

### 1.3 Lo que este kit NO incluye

| No incluido | Motivo |
|---|---|
| NetBird | Opcion evaluada y descartada. Ver `LICENCIAS.md` |
| Código de NetBird | Nunca se uso. La comparacion fue documental |
| Servicios de coturn, relay o signal | No aplican a la opcion elegida |
| Componentes AGPLv3 de NetBird | Fuera del alcance de este kit |

---

## 2. La eleccion, en corto

Detalle completo en `LICENCIAS.md`.

**Headscale v0.29.5, BSD 3-Clause.** NetBird v0.81.2 fue evaluada y descartada.

Criterio, en orden: primero las licencias (ambas permiten reventa, pero NetBird
tiene AGPLv3 sobre sus componentes de servidor), despues el costo operativo de
lo vendido (un contenedor contra cinco mas base de datos), despues la superficie
de red (un puerto contra varios), y por último la experiencia del usuario final
(aplicaciones oficiales que ya existen).

**Ninguna de las dos hacia imposible la reventa.** Las dos se podian vender. La
decisión es operativa, no legal.

---

## 3. Digests de la imagen

```
docker.io/headscale/headscale:0.29.5
  indice : sha256:780ed2f9e85719a2211277433f2c8afb45105d0d25031949a6848a485f9e216d
  amd64  : sha256:0c6299f9333c072922a22c58dcec23af88be8bea4150be4475cdf0ad4f87a682
  arm64  : sha256:8ba61f76dc7ac48daf302a06cbb17788e2db06164c14266cc89782cdc5bf7287
```

Fuente: <https://hub.docker.com/r/headscale/headscale/tags/0.29.5>

El `compose.yaml` fija etiqueta y digest. Verificar antes de desplegar:

```bash
docker buildx imagetools inspect headscale/headscale:0.29.5
```

---

## 4. Fuentes consultadas

Todas leidas el 17 de octubre de 2026, todas del tag v0.29.5 salvo donde se
indica otro.

### 4.1 Documentacion de Headscale

| Fuente | Uso en este kit |
|---|---|
| [`LICENSE`](https://github.com/juanfont/headscale/blob/v0.29.5/LICENSE) | Verificación de licencia |
| [`config-example.yaml`](https://github.com/juanfont/headscale/blob/v0.29.5/config-example.yaml) | Todas las claves de `config.yaml`, decisión de SQLite, `trusted_proxies`, DERP, `node.expiry` |
| [`docs/setup/requirements.md`](https://github.com/juanfont/headscale/blob/v0.29.5/docs/setup/requirements.md) | Tabla de puertos y si se exponen |
| [`docs/ref/policy.md`](https://github.com/juanfont/headscale/blob/v0.29.5/docs/ref/policy.md) | `config/policy.hujson`, autogroups, `randomizeClientPort`, recarga por SIGHUP |
| [`docs/ref/registration.md`](https://github.com/juanfont/headscale/blob/v0.29.5/docs/ref/registration.md) | Comandos de incorporacion, claves, etiquetas, `tagOwners` |
| [`docs/about/clients.md`](https://github.com/juanfont/headscale/blob/v0.29.5/docs/about/clients.md) | Política de las ultimas 10 versiones del cliente, plataformas soportadas |
| [`docs/setup/install/container.md`](https://github.com/juanfont/headscale/blob/v0.29.5/docs/setup/install/container.md) | Patron de `compose.yaml`, healthcheck, montajes, `/health` |
| [`docs/usage/getting-started.md`](https://github.com/juanfont/headscale/blob/v0.29.5/docs/usage/getting-started.md) | Secuencia de puesta en marcha |
| [`.goreleaser.yml`](https://github.com/juanfont/headscale/blob/v0.29.5/.goreleaser.yml) | Construccion KO, base distroless, registros de publicación |

### 4.2 Código fuente

| Fuente | Uso |
|---|---|
| [`cmd/headscale/cli/nodes.go`](https://github.com/juanfont/headscale/blob/v0.29.5/cmd/headscale/cli/nodes.go) | Verificación directa de comandos de revocacion, alias y el estado deprecado de `nodes register` |

Se leyo el código y no solo la documentacion a propósito: los comandos de
revocacion son la función que el cliente va a preguntar el primer dia, y no basta
con lo que dice el manual. El código fuente confirma que `expire` existe con sus
alias, que `delete` pide confirmacion, y que `nodes register` esta deprecado.

### 4.3 NetBird

| Fuente | Uso |
|---|---|
| [`LICENSE`](https://github.com/netbirdio/netbird/blob/v0.81.2/LICENSE) | Hallazgo del carve-out a AGPLv3 |
| [`infrastructure_files/docker-compose.yml.tmpl`](https://github.com/netbirdio/netbird/blob/v0.81.2/infrastructure_files/docker-compose.yml.tmpl) | Conteo real de componentes y puertos |
| Releases de NetBird | Versión estable v0.81.2, publicada el 2026-10-16 |

### 4.4 Docker Hub

| Fuente | Uso |
|---|---|
| <https://hub.docker.com/r/headscale/headscale/tags/0.29.5> | Digests de la imagen |

---

## 5. Afirmaciones sin fuente, marcadas como tales

Honestidad sobre lo que **no** se pudo verificar desde la fuente oficial:

1. **Usuario efectivo del contenedor.** Se sabe que la imagen se construye con KO
   sobre `gcr.io/distroless/base-debian13`, pero no se verifico
   experimentalmente con que usuario corre ni si puede escribir en `data/`.
   upstream usa montajes bind en su compose oficial y este kit sigue el mismo
   patron, pero hay que confirmarlo en el primer despliegue.

2. **Direccion del proxy en Coolify.** `trusted_proxies` queda vacio por
   omision justamente porque la direccion depende de la instalación. Llenarlo es
   un paso de despliegue.

3. **Sintaxis del `policy.hujson`.** Escrita con la sintaxis que aparece en la
   documentacion y nunca cargada por headscale. Si tiene un error, el servicio no
   levanta. Es la primera prueba pendiente.

4. **Formato exacto del usuario en `tagOwners`.** upstream muestra
   `"tag:server": ["alice@"]` en un documento y advierte en otro que el usuario no
   debe terminar en `@`. Por eso el bloque va comentado.

5. **Pasos de cliente en Windows, macOS, Android, iOS y tvOS.** upstream documenta
   que requieren configuración adicional. Hay que seguir esa documentacion
   plataforma por plataforma si el cliente final usa esos sistemas.

---

## 6. Cumplimiento de licencias por parte de Hefesto

1. Este kit se distribuye con el aviso de BSD 3-Clause de Headscale. Ver
   `LICENCIAS.md`.
2. No se modifica el código de Headscale. Se usa la imagen oficial sin cambios.
   Si alguna vez se modificara, hay que revisar si eso afecta las obligaciones.
3. No se distribuye código de NetBird.
4. El cliente Tailscale se instala desde su canal oficial y se gobierna por sus
   propios terminos.
5. **Un único cliente por red, y una red por cliente.** Si en el futuro se
   ofreciera multi-tenant, habria que revisar el modelo de licenciamiento otra
   vez.

---

## 7. Como re-verificar todo

Para auditoria independiente, en este orden:

```bash
# 1. Licencia de la opcion elegida
curl -sL https://raw.githubusercontent.com/juanfont/headscale/v0.29.5/LICENSE

# 2. Claves de configuracion usadas por este kit
curl -sL https://raw.githubusercontent.com/juanfont/headscale/v0.29.5/config-example.yaml

# 3. Puertos que declara upstream
curl -sL https://raw.githubusercontent.com/juanfont/headscale/v0.29.5/docs/setup/requirements.md

# 4. Comandos de revocacion, en el codigo fuente
curl -sL https://raw.githubusercontent.com/juanfont/headscale/v0.29.5/cmd/headscale/cli/nodes.go

# 5. Digests de la imagen
docker buildx imagetools inspect headscale/headscale:0.29.5

# 6. La licencia que hizo descartar la otra opcion
curl -sL https://raw.githubusercontent.com/netbirdio/netbird/v0.81.2/LICENSE
```

Si alguien de Hefesto cambia una afirmacion de este kit sin volver a mirar la
fuente, hay que desconfiar.