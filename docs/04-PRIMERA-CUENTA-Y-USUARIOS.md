# 04 - Primera cuenta, usuarios, nodos y revocacion

Como se maneja el ciclo de vida de las personas y las maquinas dentro de la red
privada. Esta es la operación diaria del servicio.

Todos los comandos salen de la documentacion oficial del tag v0.29.5. Los de
revocacion se verificaron ademas leyendo el código fuente de
`cmd/headscale/cli/nodes.go`.

Todos se ejecutan dentro del contenedor:

```bash
docker compose exec headscale headscale <comando>
```

---

## 1. Modelo de identidades

Antes de los comandos, el concepto que hay que tener claro, porque casi todos los
errores de operación vienen de aquí:

| Tipo | Que es | Quien es el dueno | Caduca |
|---|---|---|---|
| **Usuario** | Persona | Persona humana | No |
| **Nodo personal** | Equipo con sesión iniciada | Ese usuario | Si, a los 180 dias |
| **Nodo con etiqueta** | Equipo que hace de servidor | Nadie en particular | No |
| **`tagged-devices`** | Usuario especial al que pertenecen los nodos con etiqueta | Sistema | No |

La consecuencia práctica: **un empleado que se va no afecta a los servidores**.
Los servidores no le pertenecen. Ver `ejemplos/03-revocacion-acceso.DEMOSTRACION.md`.

---

## 2. Primer usuario

```bash
docker compose exec headscale headscale users create "nombre@ejemplo.cl"
```

Guardar el identificador que devuelve. Listar usuarios:

```bash
docker compose exec headscale headscale users list
```

**Un usuario por persona.** No un usuario compartido tipo "operaciones". El
motivo es de auditoria: en el momento en que alguien se va, un usuario compartido
deja de servir para saber quien entro y cuando.

---

## 3. Modificar un usuario

```bash
docker compose exec headscale headscale users rename --identifier <ID> "nuevo@ejemplo.cl"
docker compose exec headscale headscale users destroy --identifier <ID>
```

`destroy` elimina al usuario. Lo que quede sin dueno deja de ser accesible.
Orden recomendado: primero los nodos, despues el usuario.

---

## 4. Emitir claves de incorporacion

### 4.1 Clave de un solo uso para una persona

Verificado en `docs/ref/registration.md` v0.29.5:

```bash
docker compose exec headscale headscale preauthkeys create --user <ID_USUARIO>
```

Propiedades confirmadas por upstream:

- **Expira en una hora.**
- **Es de un solo uso** salvo que se indique lo contrario.

### 4.2 Clave con etiqueta para un servidor

```bash
docker compose exec headscale headscale preauthkeys create --tags tag:server
```

Un nodo con etiqueta **no tiene dueno humano**, así que sobrevive a que alguien
se vaya del cliente. Es la forma correcta de incorporar servidores.

### 4.3 Clave reutilizable

```bash
docker compose exec headscale headscale preauthkeys create --tags tag:server --reusable true
```

Existe, y hay que evitarla. Una clave reutilizable sirve para incorporar maquinas
ilimitadas durante su vigencia: si se filtra, el filtrador puede sumar maquinas.
El flujo normal es **una clave, una maquina, un registro claro en el log del
servidor**.

### 4.4 Ver y cancelar claves

```bash
docker compose exec headscale headscale preauthkeys list
docker compose exec headscale headscale preauthkeys expire --identifier <ID_CLAVE>
```

---

## 5. Unir un equipo

```bash
tailscale up --login-server https://acceso.ejemplo.cl --authkey <CLAVE>
```

Verificado en `docs/ref/registration.md` v0.29.5. Funciona con las aplicaciones
oficiales de Tailscale, en Linux, Windows, macOS, Android, iOS y tvOS.

Comprobar:

```bash
tailscale status
tailscale ip -4
```

### Etiquetas en la linea de incorporacion

```bash
tailscale up --login-server https://acceso.ejemplo.cl --login-tags tag:server
```

La etiqueta **tiene** que existir y alguien tiene que tener permiso para
asignarla, mediante `tagOwners` en la política. Si no, la incorporacion falla.

---

## 6. Ver nodos

```bash
docker compose exec headscale headscale nodes list
docker compose exec headscale headscale nodes list --user <ID_USUARIO>
```

Aliases verificados: `nodes list`, `ls`, `nodes show`.

---

## 7. Revocacion

El detalle completo esta en `ejemplos/03-revocacion-acceso.DEMOSTRACION.md`.
Resumen de comandos, todos verificados en `cmd/headscale/cli/nodes.go` v0.29.5:

| Necesidad | Comando | Que hace |
|---|---|---|
| Expulsar, conservar registro | `nodes expire --identifier <ID>` | El nodo debe autenticarse de nuevo |
| Quitar de la red | `nodes delete --identifier <ID>` | Elimina el nodo; pide confirmacion |
| Invalidar clave sin usar | `preauthkeys expire --identifier <ID>` | Revoca la clave |
| Dar de baja a una persona | `users destroy --identifier <ID>` | Elimina el usuario |

### Cuál usar

- **Salida normal de un empleado:** `nodes expire` sobre cada uno de sus nodos.
  Se conserva el registro y el efecto es inmediato.
- **Equipo destruido, registro irrelevante:** `nodes delete`.
- **Portatil perdido o robado:** `nodes expire` de inmediato. No esperar a que
  el empleado avise.
- **Baja del usuario:** primero los nodos, despues `users destroy`.

### Respuestas automaticas

`nodes delete` pide confirmacion interactiva. Para automatizar, hay que responder
la pregunta por entrada estandar. **Leer antes de automatizar**: si se responde
por costumbre sin mirar, el script puede borrar el nodo equivocado.

---

## 8. Si se pierde la clave de un nodo

No hay comando de recuperacion, y conviene decirlo con todas las letras al
cliente.

La clave privada de WireGuard esta en la maquina, protegida por el sistema
operativo. Si se pierde, **nadie puede recuperar el acceso a ese nodo**. No hay
copia en el servidor: el servidor solo conoce la clave pública.

El procedimiento real es:

1. Emitir una clave de incorporacion nueva.
2. El equipo se une de nuevo con ella.
3. Eliminar el nodo viejo del servidor de coordinacion.

Detalle en `ejemplos/03-revocacion-acceso.DEMOSTRACION.md`, seccion 5.

Por que importa: es un argumento de venta honesto a favor del cifrado de disco y
del segundo factor. Una red privada sin esas dos cosas es fragile.

---

## 9. Cambios de nombre, etiquetas y rutas

Verificados en `cmd/headscale/cli/nodes.go` v0.29.5:

```bash
# renombrar
docker compose exec headscale headscale nodes rename <NOMBRE_NUEVO> --identifier <ID>

# cambiar etiquetas
docker compose exec headscale headscale nodes tag --identifier <ID> --tags <ETIQUETAS>

# ver rutas anunciadas
docker compose exec headscale headscale nodes list-routes
docker compose exec headscale headscale nodes list-routes --identifier <ID>

# aprobar rutas de un enrutador de subredes
docker compose exec headscale headscale nodes approve-routes --identifier <ID> --routes <RUTAS>
```

Sobre las rutas: **este kit no necesita enrutadores de subredes ni nodos de
salida**. No hay que aprobarlos. Se documentan porque un administrador con
demasiada confianza en su red terminaria activandolos, y un enrutador de
subredes aprobado sin querer cambia el alcance de toda la red privada.

### Comando obsoleto

`headscale nodes register` esta marcado como **deprecado** en el código fuente
de v0.29.5. upstream indica usar en su lugar:

```bash
headscale auth register --user <USUARIO> --auth-id <ID>
```

Es el flujo manual para registrar una maquina sin usar clave de incorporacion.
Casi nunca hace falta: se prefiere siempre la clave, porque queda registrada.

---

## 10. Mantenimiento de la red

### Recargar la política de segmentacion

```bash
docker kill -s HUP headscale
```

upstream indica en `docs/ref/policy.md` v0.29.5 que headscale debe recargarse para
tomar los cambios de la política, y que registra el resultado del procesamiento
en el log. En Docker, lo equivalente a `systemctl reload` es la senal `HUP`.

### Ver la salud

```bash
docker compose exec headscale headscale health
curl -s http://127.0.0.1:9090/health
```

### Actualizar el mapa DERP

`derp.auto_update_enabled` esta en `true` con frecuencia de tres horas, según
`config-example.yaml` v0.29.5. Headscale descarga la lista de relays y la reparte
a los clientes.

### Nodos efimeros

`ephemeral.inactivity_timeout` esta en 30 minutos. Un nodo marcado como efimero
se desconecta solo tras ese tiempo de inactividad. Sirve para equipos de apoyo
que se enchufan por ratos, no para servidores.