# EJEMPLOS - incorporacion de un servidor del cliente

> **ARCHIVO DE DEMOSTRACION.** Los nombres, dominios, rangos y rutas son
> inventados para mostrar el procedimiento. No son un cliente real y no deben
> entregarse al cliente tal cual. Adaptar antes de usar.

---

## 1. Que se demuestra

Que el cliente entra a **su propio servidor**, sin que ese servidor tenga el
puerto 22 abierto a internet, y sin depender de una VPN comercial.

---

## 2. Que se necesita de antemano

- El servidor de coordinacion ya instalado, con `headscale users create`.
- El dominio del cliente resuelto a la VPS y con HTTPS valido.
- Una etiqueta creada para los servidores, por ejemplo `tag:server`.

### Crear el usuario inicial (una sola vez)

```bash
docker compose exec headscale headscale users create "Hrefesa SpA"
```

Anotar el identificador que devuelve. La salida es un número junto al nombre.

### Declarar quien puede poner la etiqueta

Verificado en `docs/ref/registration.md` del tag v0.29.5, la forma es:

```json
"tagOwners": {
  "tag:server": ["nombre-de-usuario"]
}
```

Editar `config/policy.hujson`, descomentar el bloque `tagOwners` y poner el
nombre exacto que devuelve `headscale users list`.

> OJO: upstream advierte en su documentacion de OIDC que el usuario no debe
> escribirse terminado en `@`. Verificar el formato antes de aplicar.

Aplicar el cambio:

```bash
docker kill -s HUP headscale
```

Headscale registra el resultado de procesar la política despues de cada recarga.

---

## 3. Emitir la clave de incorporacion

Para un servidor conviene usar una **clave con etiqueta**, no una clave de un
usuario. La diferencia es de propiedad: un nodo con etiqueta no pertenece a
ningun empleado concreto, así que no se pierde ni se va con nadie.

Verificado en `docs/ref/registration.md` del tag v0.29.5:

```bash
docker compose exec headscale headscale preauthkeys create --tags tag:server
```

Devuelve una clave de una sola pasada, con vigencia de una hora.

Opciones relevantes:

- `--reusable true` para emitir una clave que sirva para varias maquinas.
  Hefesto deberia preferir claves de un solo uso: cada clave, una maquina, un
  registro claro en los logs del servidor.

---

## 4. En el servidor del cliente

### 4.1 Instalar el cliente oficial de Tailscale

Linux, ejemplo con instalador oficial:

```bash
curl -fsSL https://tailscale.com/install.sh | sh
```

> Este es el instalador oficial de Tailscale. El servicio que Hefesto vende no
> incluye el cliente: el cliente se licencia con Tailscale Inc.

### 4.2 Unirse a la red

```bash
tailscale up --login-server https://acceso.hrefesa.example --authkey <CLAVE>
```

Verificado en `docs/ref/registration.md` del tag v0.29.5: el comando de union es
exactamente `tailscale up --login-server <URL> --authkey <CLAVE>`.

Comprobar:

```bash
tailscale status
tailscale ip -4
```

Anotar la direccion privada asignada, por ejemplo `100.64.10.4`.

### 4.3 Ajustes recomendados en un servidor

- Desactivar la actualización automática del cliente, para que el versionado lo
  controle Hefesto:

  ```bash
  sudo systemctl disable --now tailscaled
  sudo tailscale set --auto-update=false
  ```

  Comprobado: el kit desactiva también la actualización del lado del servidor de
  coordinacion, en `config/config.yaml`.

- **No activar enrutador de subredes ni nodo de salida.** No hace falta para
  entrar a un servidor, y activar cualquiera de los dos amplía el alcance de lo
  que ve la red del cliente.

---

## 5. Verificar el aislamiento

Desde el servidor, el puerto 22 debe seguir cerrado al exterior:

```bash
# desde una maquina externa al servidor del cliente
nc -zv <IP-PUBLICA-DEL-SERVIDOR> 22
# esperado: connection refused o timeout
```

Y desde un equipo autorizado de la red privada:

```bash
ssh usuario@100.64.10.4
# esperado: acceso concedido
```

Si el acceso por IP pública sigue funcionando, hay que cerrar el 22 en el
firewall del cliente **antes** de dar por terminado el trabajo. Es el error mas
comun de esta migración: abrir la red privada sin cerrar la pública.

---

## 6. Limpiar la incorporacion

Cuando el servidor ya esta unido, **la clave no se vuelve a usar**. Las claves de
incorporacion no son secretos de largo plazo. No hay que guardarlas en ningun
lado, y no deben aparecer en chats ni en correo.

---

## Que queda fuera de este ejemplo

- La incorporacion de una maquina de escritorio: ver
  `02-escritorio-empleado.DEMOSTRACION.md`.
- Que hacer cuando alguien se va del cliente:
  ver `03-revocacion-acceso.DEMOSTRACION.md`.