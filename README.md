# Hefesto Studio - Kit de acceso remoto seguro (WireGuard)

Red privada para que los clientes accedan a sus servidores sin exponerlos a
internet y sin depender de una VPN comercial.

**Estado:** preparado. No probado en ejecución. Ver
`docs/07-PRUEBAS-DE-ACEPTACION.md`.

---

## Que resuelve

Los servidores de los clientes quedan accesibles por SSH público. Este kit los
cierra: el puerto de administración deja de estar abierto y el acceso entra por
una red privada con cifrado de punto a punto.

No hay que migrar nada del cliente. Se instala al lado de lo que ya tiene.

---

## Pila técnica

| Componente | Eleccion |
|---|---|
| Servidor de coordinacion | **Headscale v0.29.5** (BSD 3-Clause) |
| Base de datos | **SQLite** |
| Cifrado del trafico | **WireGuard**, nativo en los clientes Tailscale |
| Cliente en los nodos | Aplicaciones oficiales de **Tailscale** |
| Contenedores | **1** |
| Puertos públicos | **1**: TCP 443 |

Imagen fijada por etiqueta y por digest:

```
docker.io/headscale/headscale:0.29.5@sha256:780ed2f9e85719a2211277433f2c8afb45105d0d25031949a6848a485f9e216d
```

---

## Por que Headscale y no NetBird

Ambas son open source y **ambas permiten la reventa**, así que la decisión no es
legal. Es operativa.

| | Headscale v0.29.5 | NetBird v0.81.2 |
|---|---|---|
| Licencia | BSD 3-Clause, sin excepciones | BSD-3 **salvo `management/`, `signal/`, `relay/`, `combined/`, que son AGPLv3** |
| Contenedores obligatorios | **1** | **5**, mas la base de datos |
| Base de datos | SQLite | PostgreSQL o MySQL, externa |
| Consola web | No | Si |
| Puertos públicos | 443 | 80, 443, signal, relay y coturn en red del host |

Criterio aplicado, en orden: licencias, costo operativo de lo vendido,
superficie de red y experiencia del cliente final. El detalle completo, con la
objecion de compatibilidad con Tailscale evaluada una por una, esta en
`LICENCIAS.md`.

**La objecion que mas se peso:** Headscale depende de seguirle el paso a un
cliente que evoluciona rapido. El riesgo es real. upstream declara soportar las
ultimas 10 versiones del cliente, y el riesgo se controla fijando la versión del
cliente en los servidores del cliente. Ademas es reversible: si una versión del
cliente rompe algo, se vuelve a la anterior sin tocar el servidor de
coordinacion.

---

## Contenido

```
compose.yaml              Un contenedor. Imagen fijada por digest. Solo loopback.
.env.example              Sin secretos: este producto no tiene contrasenas.
VERSION.md                Version, digests, puertos y cliente compatible.
LICENCIAS.md              Comparacion Headscale contra NetBird, con fuentes.
config/
  config.yaml             Configuracion completa y comentada.
  policy.hujson           Segmentacion: denegado por omision.
scripts/
  backup-headscale.sh     Respaldo con manifiesto SHA-256.
  restore-headscale.sh    Restauracion que verifica antes de tocar nada.
ejemplos/                 DEMOSTRACION: servidor, escritorio y revocacion.
docs/                     Los 10 documentos.
data/                     Se crea al desplegar. Nunca se versiona.
```

---

## Documentos

| Documento | Que resuelve |
|---|---|
| `01-INSTALACION-DOCKER.md` | Instalación, proxy inverso, puertos, CGNAT |
| `02-INSTALACION-COOLIFY.md` | Despliegue con Coolify |
| `03-VARIABLES-Y-COMO-OBTENERLAS.md` | Que cambiar por cliente. Por que no hay secretos |
| `04-PRIMERA-CUENTA-Y-USUARIOS.md` | Usuarios, nodos, claves y revocacion |
| `05-RESPALDOS-Y-RESTAURACION.md` | Que se respalda y como se verifica |
| `06-ACTUALIZACIONES-Y-REVERSION.md` | Actualizar sin romper la red del cliente |
| `07-PRUEBAS-DE-ACEPTACION.md` | **Lo verificado contra lo pendiente** |
| `08-SERVICIOS-COMERCIALES.md` | Que se promete y que no |
| `09-EXPORTACION-O-TRASPASO.md` | Devolver el control al cliente |
| `10-LICENCIAS-Y-FUENTES.md` | Trazabilidad de cada afirmacion |

---

## Alcance

### Cubre

- Red privada entre servidores y equipos del cliente.
- Cifrado de punto a punto con WireGuard.
- Segmentacion por política: lo que no esta permitido, no pasa.
- Revocacion inmediata de accesos.
- Respaldo y restauración del estado del servidor.

### No cubre

- **No es sustituto de una VPN comercial auditada.** Si el sector del cliente
  exige proveedor con certificacion, esto no cubre ese requisito.
- **No hay MFA integrado.** La autenticación de un nodo es por clave pública.
  Ver `docs/08-SERVICIOS-COMERCIALES.md`.
- **No hay auditoria nativa de conexiones.** Hay que construirla con los logs
  SSH del servidor. Tener registro de conexiones no es lo mismo que auditar.
- **No borra el contenido de un equipo.** Revocar impide entrar, no borrar.
- **No recupera claves perdidas.** Hay que emitir una clave nueva y volver a
  unir la maquina. Es el procedimiento real.
- **No es multi-tenant.** Una red por cliente.
- **No tiene consola web.** Se administra por linea de comandos.

---

## Puesta en marcha rapida

```bash
cp .env.example .env
mkdir -p data && chmod 700 data

# editar config/config.yaml: server_url y dns.base_domain
nano config/config.yaml

docker compose up -d
docker compose exec headscale headscale health
docker compose exec headscale headscale users create "nombre@cliente.cl"
```

Despues, incorporar el primer servidor siguiendo
`ejemplos/01-servidor-cliente.DEMOSTRACION.md`.

El detalle completo esta en `docs/01-INSTALACION-DOCKER.md`.

---

## Puertos

| Puerto | Abrir | Nota |
|---|---|---|
| **TCP 443** | **Si** | Lo único imprescindible |
| TCP 80 | Solo para el certificado | Si se pide por HTTP |
| TCP 8080 | **No** | Loopback, lo usa el proxy local |
| TCP 9090 | **No** | Metricas. upstream lo marca no público |
| TCP 50443 | **No** | gRPC remoto. Este kit usa socket Unix |
| UDP 3478 | **No** | Solo con DERP embebido, que esta apagado |

**Un solo puerto público.** Ese es el argumento del producto y hay que
mantenerlo cierto.

---

## Datos persistentes

| Ruta | Que es |
|---|---|
| `data/db.sqlite` | Usuarios, nodos, claves y políticas |
| `data/noise_private.key` | Identidad criptografica del servidor |
| `config/config.yaml` | Configuración |
| `config/policy.hujson` | Segmentacion |

`data/` nunca se versiona. `backup-headscale.sh` **se niega a terminar** si no
encuentra la clave de Noise, porque un respaldo sin ella no sirve.

---

## Estado: preparado, no probado

| Verificado | No verificado |
|---|---|
| Licencias, leidas del tag exacto | Contenedor levantandose |
| Configuración, contra `config-example.yaml` v0.29.5 | Salud y CLI reales |
| Puertos, contra `docs/setup/requirements.md` | Incorporacion real de un nodo |
| Comandos de revocacion, **leidos del código fuente** | Segmentacion effective |
| Digests de imagen, desde Docker Hub | Usuario efectivo del contenedor |

El detalle completo, con los quince puntos de la lista de aceptacion, esta en
`docs/07-PRUEBAS-DE-ACEPTACION.md`.

**No prometer al cliente que ya funciona.** Prometer que Hefesto lo instala, lo
prueba y lo deja andando. Esa promesa si se puede cumplir.

---

## Licencia de este kit

Distribuido bajo los terminos de Headscale, BSD 3-Clause. El cliente Tailscale
lo gobiernan los terminos de Tailscale Inc. y no se incluye ni reempaqueta en
este kit.

Ver `LICENCIAS.md` y `docs/10-LICENCIAS-Y-FUENTES.md`.