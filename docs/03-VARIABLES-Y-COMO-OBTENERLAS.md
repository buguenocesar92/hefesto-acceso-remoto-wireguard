# 03 - Variables y como obtenerlas

Este kit es distinto a casi todos los demas del catalogo de Hefesto: **no hay
secretos que generar**. Vale la pena entender por que, antes de leer la lista.

---

## 1. Por que no hay contrasenas

Headscale es un servidor de coordinacion. No autentica a personas con usuario y
contrasena. Autentica a maquinas.

1. Cada maquina genera su propio **par de claves WireGuard** en su sistema.
2. La clave privada nunca sale de la maquina.
3. La clave pública se registra en el servidor de coordinacion.
4. A partir de ahi, las maquinas se reconocen por criptografia, no por una
   contrasena compartida.

Por eso no hay usuario de base de datos, ni contrasena, ni token de API que
rotar. Una variable de entorno con una contrasena en este kit seria inventada y
ademas peligrosa, porque alguien podria creer que protege algo.

---

## 2. Variables de `.env`

| Variable | Valor por omision | Estado | Donde se usa |
|---|---|---|---|
| `HEADSCALE_BIND_ADDR` | `127.0.0.1` | Obligatoria | `compose.yaml` |
| `HEADSCALE_LISTEN_PORT` | `8080` | Obligatoria | `compose.yaml` |
| `HEADSCALE_METRICS_PORT` | `9090` | Obligatoria | `compose.yaml` |

### `HEADSCALE_BIND_ADDR`

Interfaz del **host** donde se pública el puerto de coordinacion.

Se mantiene en `127.0.0.1` a propósito. El único que consume ese puerto es el
proxy inverso que corre en el mismo servidor. Si se pone en `0.0.0.0`, el puerto
queda expuesto a internet en texto plano, sin TLS, y ademas por debajo del
proxy.

Este valor no se cambia por conveniencia. Se cambia solo si se decide, con
riesgo asumido y por escrito, exponer el servidor de coordinacion directamente.

### `HEADSCALE_LISTEN_PORT` y `HEADSCALE_METRICS_PORT`

Puertos del host. Si chocan con algo que ya corre, cambiarlos. El valor de
`HEADSCALE_BIND_ADDR` se aplica a los dos.

El puerto 8080 **no es** el puerto por el que entran los clientes. Los clientes
entran por HTTPS en el 443, a traves del proxy.

---

## 3. Valores de `config/config.yaml`

Estos van en el archivo de configuración, no en `.env`, porque los lee el
contenedor desde su sistema de archivos montado.

### `server_url` - OBLIGATORIA

```yaml
server_url: https://acceso.ejemplo.cl
```

Es el valor mas importante del kit. Es la direccion contra la que los clientes
se autentican.

Requisitos:

- Debe empezar con `https://` en producción.
- Sin barra final.
- Debe ser exactamente el dominio que resuelve a esta VPS y que tiene el
  certificado valido.
- Debe incluir el subdominio, no solo el dominio raiz.

Si despues de installed los clientes no se pueden autenticar, este es el primer
valor que hay que revisar.

### `dns.base_domain` - OBLIGATORIA

```yaml
dns.base_domain: internal.ejemplo.cl.
```

Dominio con el que se construyen los nombres internos de MagicDNS. El nodo
`srv-web` queda como `srv-web.internal.ejemplo.cl`.

Reglas:

- Debe terminar en punto.
- **Debe ser distinto** del dominio de `server_url`.
- Debe estar contenido en un dominio que el cliente controle de verdad.

### `noise.private_key_path`

```yaml
private_key_path: /var/lib/headscale/noise_private.key
```

Ruta de la clave privada de Noise, que es la identidad criptografica del
servidor. **No se edita.** Si el archivo no existe, headscale lo genera solo al
arrancar por primera vez.

Este archivo no es una variable: es estado. Y es el archivo mas critico del kit.

### `prefixes.v4` y `prefixes.v6`

Rangos de direcciones privadas que se asignan a los nodos. upstream advierte en
`config-example.yaml` v0.29.5 que deben ser **subconjuntos de los rangos
estandar de Tailscale**. Este kit deja los valores por omision:

```yaml
v4: 100.64.0.0/10
v6: fd7a:115c:a1e0::/48
```

Cambiarlos dentro de esos rangos esta bien. Salirse de ellos rompe el cliente de
formas sutiles y muy molestas de diagnosticar.

### `trusted_proxies`

Lista de proxies cuyas cabeceras de origen se respetan. Vacia por omision.

Llenarla **solo** cuando hay un proxy delante. upstream advierte de forma
explicita que declararla sin proxy permite que un cliente falsifique sus
cabeceras de origen. Ver `docs/01-INSTALACION-DOCKER.md`.

### `node.expiry`

```yaml
node: 180d
```

Vigencia por omision de los nodos personales. upstream indica que Tailscale
comercial usa 180 dias. Con `0`, los nodos nunca caducan, lo que **no se
recomienda** para un servicio recurrente: una laptop robada seguiria entrando
para siempre.

Los nodos con etiqueta no caducan.

### `derp.server.enabled`

```yaml
enabled: false
```

DERP embebido apagado, que es el valor por omision de upstream. Mientras siga
apagado, **este kit no necesita ningun puerto UDP abierto en el servidor**.
Encenderlo obliga a abrir UDP 3478 y agrega un componente mas que operar.

---

## 4. Que se genera solo

Nada de esto se configura: se crea en el primer arranque.

| Archivo | Que es | Criticidad |
|---|---|---|
| `data/noise_private.key` | Identidad criptografica del servidor | ** maxima** |
| `data/db.sqlite` | Usuarios, nodos, claves y políticas | ** maxima** |
| `data/db.sqlite-wal` | Registro de escrituras del modo WAL | alta |

---

## 5. Que es secreto y como se protege

| Elemento | Donde | Protección |
|---|---|---|
| `data/noise_private.key` | disco del servidor | permisos `700` en `data/` |
| `data/db.sqlite` | disco del servidor | permisos `700` en `data/` |
| Respaldos | carpeta de respaldos | fuera del directorio web, sin acceso público |

Ninguno de estos se versiona. `.gitignore` excluye `data/` y `backups/`.

Los respaldos son tan sensibles como el servidor original: el que tenga el
`noise_private.key` y la base puede reconstituir la red entera del cliente.

---

## 6. Resumen de lo que hay que cambiar por cliente

Solo tres cosas:

1. `server_url` en `config/config.yaml`
2. `dns.base_domain` en `config/config.yaml`
3. El dominio en Coolify o el archivo del proxy inverso

Todo lo demas ya viene bien puesto. Un kit con mas de tres cosas que cambiar por
cliente es un kit que se desordena en el camino.