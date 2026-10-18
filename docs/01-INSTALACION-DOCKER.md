# 01 - Instalación con Docker

Instalación del servidor de coordinacion Headscale en una VPS Linux de Hefesto.

---

## 1. Que se instala realmente

Un solo contenedor de Headscale, mas una base SQLite dentro de un volumen.
Nada mas. No hay base de datos que levantar, ni panel web, ni relay, ni STUN.

| Componente | Donde vive |
|---|---|
| Binario de headscale | Imagen Docker `headscale/headscale:0.29.5` |
| Configuración | `./config/config.yaml`, montado de solo lectura |
| Política de segmentacion | `./config/policy.hujson`, montado de solo lectura |
| Base de datos | `./data/db.sqlite`, volumen persistente |
| Clave de identidad del servidor | `./data/noise_private.key` |

---

## 2. Requisitos del servidor

- Linux con Docker Engine 24 o superior.
- Docker Compose v2 (`docker compose`, no el viejo `docker-compose`).
- Un dominio que resuelva a la VPS. Headscale **exige HTTPS** en `server_url`.
- `bash` y `coreutils` para los scripts de respaldo.
- Un puerto TCP 443 libre, porque ahi va el proxy inverso.

No se necesita una VPS grande. Headscale coordina claves: no transporta el
trafico de los clientes. El trafico va directo entre nodos.

---

## 3. Preparar el directorio

```bash
mkdir -p /opt/hefesto/acceso-remoto
cd /opt/hefesto/acceso-remoto
```

Copiar aca el contenido del kit: `compose.yaml`, `.env.example`, `config/`,
`scripts/`.

```bash
cp .env.example .env
mkdir -p data
chmod 700 data
```

`data/` guarda la base y la clave privada del servidor. Debe quedar legible solo
por root.

---

## 4. Configurar `.env`

```bash
nano .env
```

Los valores de este kit ya estan puestos. Lo único que hay que revisar es que
`HEADSCALE_BIND_ADDR` siga en `127.0.0.1`.

**Ese valor no se cambia nunca.** Pasarlo a `0.0.0.0` publicaria el puerto 8080
del servidor de coordinacion en crudo, sin TLS, salteando el proxy. Es el error
que rompe la promesa de seguridad del producto entero.

---

## 5. Configurar `config/config.yaml`

Editar solo tres cosas:

1. `server_url`: el dominio público con HTTPS. Sin barra final.
2. `dns.base_domain`: un dominio para los nombres internos. **Distinto** del
   anterior, y con punto final, por ejemplo `internal.hrefesa.example.`
3. Revisar `node.expiry` si el cliente quiere otra ventana.

Todo lo demas esta deliberadamente configurado y comentado.

### Por que SQLite y no PostgreSQL

No es una preferencia. En `config-example.yaml` del tag v0.29.5, upstream escribe
que usar Postgres "is highly discouraged as it is only supported for legacy
reasons" y que todo el desarrollo y las optimizaciones se hacen pensando en
SQLite.

Por lo tanto: **este kit no usa PostgreSQL y no es compatible con Supabase.**
No forzar la integración. Si un cliente exige PostgreSQL, se conversa antes.

---

## 6. Proxy inverso

Es **obligatorio**. Headscale no emite certificados por si mismo en esta
configuración; necesita que alguien le ponga HTTPS delante.

Ejemplo con Caddy, que es lo mas simple porque pide el certificado solo:

```caddyfile
acceso.ejemplo.cl {
    reverse_proxy 127.0.0.1:8080
}
```

Ejemplo con Nginx, si ya hay Nginx en el servidor:

```nginx
server {
    listen 443 ssl http2;
    server_name acceso.ejemplo.cl;

    ssl_certificate     /etc/letsencrypt/live/acceso.ejemplo.cl/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/acceso.ejemplo.cl/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
}
```

### Si el proxy corre en otro contenedor

Cuando el proxy no esta en el host sino en la red de Docker, la peticion llega
desde la red de Docker, no desde `127.0.0.1`. En ese caso hay que llenar
`trusted_proxies` en `config.yaml` con la IP real del proxy.

upstream advierte de forma explicita en `config-example.yaml` v0.29.5 que poner
`trusted_proxies` **sin** un proxy delante permite que un cliente falsifique sus
cabeceras de origen. Por eso este kit lo deja vacio por omision. Llenarlo solo
cuando exista el proxy, y solo con su direccion.

---

## 7. Levantar

```bash
docker compose up -d
docker compose ps
```

Estado esperado: el contenedor en `healthy`.

Comprobar la salud desde dentro:

```bash
docker compose exec headscale headscale health
```

Y desde el host, por el puerto de metricas:

```bash
curl -s http://127.0.0.1:9090/health
```

---

## 8. Puertos del firewall

Este es el punto que hay que dejar exactamente bien, porque es la promesa
comercial del producto.

| Puerto | Protocolo | Abrir | Motivo |
|---|---|---|---|
| 443 | TCP | **Si** | Acceso de los clientes. Es el único imprescindible. |
| 80 | TCP | Solo si se pide el certificado por HTTP | letsencrypt y Caddy pueden necesitarlo |
| 8080 | TCP | **No** | Solo lo usa el proxy local. upstream lo pública en 127.0.0.1 |
| 9090 | TCP | **No** | Metricas y depuracion. upstream lo marca "Expose publicly: no" |
| 50443 | TCP | **No** | gRPC remoto. Este kit administra por socket Unix |
| 3478 | UDP | **No** | Solo si se activa el DERP embebido, que esta apagado |

`upstream` documenta esta tabla en `docs/setup/requirements.md` del tag v0.29.5.

Ejemplo con UFW:

```bash
ufw default deny incoming
ufw allow OpenSSH
ufw allow 443/tcp
ufw enable
```

Con iptables, la regla minima es aceptar 443 y descartar todo lo demas que no sea
SSH ni loopback.

---

## 9. Sobre CGNAT

Esto no afecta al servidor de coordinacion, que vive en una VPS con IP pública.
Afecta a los **nodos**.

Un nodo atras de CGNAT, que es el caso tipico de un portatil en conexión Movil,
no puede abrir conexiones entrantes. WireGuard lo resuelve por su cuenta: la
conexión directa falla y el trafico se enruta por un relay DERP.

Las piezas son:

- **Directo**, cuando los dos nodos se ven. Es el caso normal entre una VPS con
  IP pública y una red domestica.
- **DERP de reley**, cuando no. El relay transporta texto cifrado: no ve el
  contenido.

Este kit usa por omision el mapa DERP público de Tailscale. Para que la red del
cliente no dependa de un tercero, hay que alojar un DERP propio, lo que implica
abrir UDP 3478 y sumar un componente. Decisión del cliente. Ver
`docs/07-PRUEBAS-DE-ACEPTACION.md`.

La política activa `randomizeClientPort`, que hace que cada nodo use un puerto
UDP aleatorio en vez del fijo 41641. Eso reduce los conflictos de NAT y de CGNAT.
Clave verificada en `docs/ref/policy.md` v0.29.5.

---

## 10. Primer usuario

Antes de que el cliente sirva de algo, hay que crear al menos un usuario:

```bash
docker compose exec headscale headscale users create "nombre@ejemplo.cl"
```

El detalle completo esta en `docs/04-PRIMERA-CUENTA-Y-USUARIOS.md`.

---

## 11. Problemas frecuentes

**"No puedo entrar al servidor"**
Revisar, en este orden: que `server_url` sea exactamente el dominio que se esta
visitando, que el proxy tenga el certificado valido, y que el puerto 443 este
abierto.

**Los clientes se ven entre si pero no salen**
Revisar que los rangos de `prefixes` no esten pegados con la red local del
cliente. `100.64.0.0/10` se superpone con rangos que algunos equipos del cliente usan
para su red local.

**"http: no such file or directory" con el socket**
El socket Unix vive en `/var/run/headscale/headscale.sock`, que en el compose es
un tmpfs. Si el servicio corre y el socket no existe, el contenedor se levanto
mal.

---

Verificación completa de la instalación en `docs/07-PRUEBAS-DE-ACEPTACION.md`.