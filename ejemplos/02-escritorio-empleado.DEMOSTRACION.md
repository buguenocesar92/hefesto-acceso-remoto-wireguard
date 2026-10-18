# EJEMPLOS - incorporacion de una maquina de escritorio de un empleado

> **ARCHIVO DE DEMOSTRACION.** Nombres y dominios inventados. Adaptar antes de
> usar con un cliente real.

---

## 1. Que se demuestra

Que un empleado del cliente entra a los servidores de la empresa desde su
portatil, sin que el portatil tenga que estar en la oficina y sin abrir puertos
en los servidores.

---

## 2. Que cambia respecto del servidor

La diferencia fundamental es de **propiedad**:

- El **servidor** se une con una etiqueta (`tag:server`). No pertenece a nadie.
  Si el empleado se va, el servidor sigue ahi.
- El **escritorio** se une como un nodo personal, con dueño humano. Si el
  empleado se va, se revoca a el, no al servidor.

Es la razon por la que conviene separar los dos flujos. Unemployee que se va
deja fuera su portatil, no la infraestructura del cliente.

---

## 3. Crear el usuario en el servidor de coordinacion

Cada persona tiene su propio usuario. **No crear un usuario compartido tipo
"operaciones"**: en el momento en que alguien se vaya, el registro deja de
servir para saber quien entro y cuando.

```bash
docker compose exec headscale headscale users create "persona@hrefesa.example"
```

Lista de usuarios:

```bash
docker compose exec headscale headscale users list
```

---

## 4. Emitir la clave de la persona

```bash
docker compose exec headscale headscale preauthkeys create --user <ID_USUARIO>
```

Verificado en `docs/ref/registration.md` del tag v0.29.5: el comando es
`headscale preauthkeys create --user <USUARIO>` y la clave tiene **una hora de
vigencia** y es de un solo uso.

---

## 5. En la maquina del empleado

### Windows

Instalar Tailscale desde la tienda oficial y abrir la aplicación. El flujo
interactivo muestra el dominio y hay que escribir la clave.

Desde la linea de comandos, si se requiere:

```powershell
tailscale up --login-server https://acceso.hrefesa.example --authkey <CLAVE>
```

### macOS

Instalar desde App Store y luego:

```bash
tailscale up --login-server https://acceso.hrefesa.example --authkey <CLAVE>
```

### Linux

```bash
tailscale up --login-server https://acceso.hrefesa.example --authkey <CLAVE>
```

> En Windows, macOS, iOS, Android y tvOS, upstream documenta pasos adicionales
> de configuración. Ver `docs/usage/connect/` del tag v0.29.5 antes de dar el
> kit por cerrado para esos sistemas.

---

## 6. Comprobar

```bash
tailscale status
tailscale ip -4
```

Desde el escritorio deberian verse los servidores del cliente como
alcanzables, por ejemplo:

```
100.64.10.4   app-web   usuario@linux   linux   -
```

Y deberia poder entrar:

```bash
ssh usuario@100.64.10.4
```

---

## 7. La diferencia entre esto y una VPN comercial

Conviene ser explicito con el cliente en este punto, porque es la promesa de
valor y también su limite:

- Los puertos del servidor siguen cerrados a internet. Se entra por la red
  privada.
- El trafico entre los equipos va cifrado de punto a punto con WireGuard. El
  servidor de coordinacion **no transporta** ese trafico: solo reparte claves.
- El cliente final usa la aplicación de Tailscale, no la aplicación de Hefesto.

Lo que **no** es: esto no es un producto de cumplimiento certificado, y no
reemplaza a un proveedor auditado si el sector del cliente lo exige. Ver
`docs/08-SERVICIOS-COMERCIALES.md`.

---

## 8. Que hacer cuando el empleado se va

Ver `03-revocacion-acceso.DEMOSTRACION.md`. Ese es el procedimiento real de
salida, y es la pregunta que el cliente va a hacer seguro.

---

## 9. Si el portatil se pierde o se roba

Aun sin baja, el nodo del portatil es un nodo personal y tiene fecha de
caducidad: este kit configura `node.expiry` en 180 dias, el mismo valor que usa
Tailscale comercial. Para una respuesta mas rapida hay que usar el procedimiento
de revocacion, que es inmediato.