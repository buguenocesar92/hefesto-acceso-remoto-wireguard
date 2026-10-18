# EJEMPLOS - revocacion de acceso

> **ARCHIVO DE DEMOSTRACION.** Nombres y comandos de ejemplo. Adaptar.

Este es el documento mas importante de `ejemplos/`. Es la pregunta que el
cliente va a hacer sin falta el primer dia: **"un empleado se va, ¿qué hago?"**

---

## 1. Las dos situaciones que hay que distinguir

| Situacion | Que hay que revocar | Efecto |
|---|---|---|
| Un empleado se va del cliente | Su usuario y sus nodos personales | Los servidores con etiqueta siguen operando |
| Se pierde o se roba un portatil | Ese nodo concreto, de inmediato | El resto de la red sigue igual |

El error clasico es pensar que "se fue una persona, se cae la red". No: los
nodos con etiqueta no tienen dueño humano. La red del cliente sobrevive.

---

## 2. Ver el estado antes de tocar nada

```bash
docker compose exec headscale headscale users list
docker compose exec headscale headscale nodes list
docker compose exec headscale headscale nodes list --user <ID_USUARIO>
```

Tomar una salida de estas dos listas **antes** de revocar. Es el registro de
que equipos estaban conectados, y sirve tanto para la auditoria como para
comprobar despues que la revocacion surtio efecto.

---

## 3. Revocar el acceso de una persona que se va

### 3.1 Ver sus nodos

```bash
docker compose exec headscale headscale nodes list --user <ID_USUARIO>
```

Cada linea trae un identificador de nodo y un nombre de host.

### 3.2 Expulsar el equipo, conservando el registro

```bash
docker compose exec headscale headscale nodes expire --identifier <ID_NODO>
```

Verificado leyendo el código fuente de `cmd/headscale/cli/nodes.go` del tag
v0.29.5: `expire` es el comando, con alias `logout`, `exp` y `e`, y acepta
`--identifier`. Marca el nodo para que deba autenticarse de nuevo.

Esta es la opcion recomendada para una salida normal. El nodo queda en la base
con su historial y deja de poder entrar.

### 3.3 Quitar el equipo de la red por completo

```bash
docker compose exec headscale headscale nodes delete --identifier <ID_NODO>
```

El mismo archivo fuente confirma que `delete`, alias `del`, pide confirmacion
interactiva y elimina el nodo de la red. **No hace falta responder a una
pregunta para automatizar:** se responde por entrada estandar.

Usar `delete` cuando el equipo va a destruirse y el registro no aporta, o cuando
el cliente pide un borrado limpio. Usar `expire` cuando importa conservar el
rastro.

### 3.4 Invalidar claves de incorporacion que quedaran sueltas

```bash
docker compose exec headscale headscale preauthkeys list
docker compose exec headscale headscale preauthkeys expire --identifier <ID_CLAVE>
```

Una clave de incorporacion sin usar es un riesgo: si quedo en un chat, en un
correo o en un portapapeles, alguien podria incorporarse. Vencen solas en una
hora, pero si se emitieron con `--reusable true` hay que revocarlas a mano.

### 3.5 Eliminar al usuario, al final

```bash
docker compose exec headscale headscale users destroy --identifier <ID_USUARIO>
```

Orden recomendado: primero los nodos, despues el usuario. Al borrar el usuario,
lo que quede sin dueño deja de ser accesible.

---

## 4. Revocar un portatil perdido, sin baja

Es mas simple y mas urgente:

```bash
docker compose exec headscale headscale nodes expire --identifier <ID_NODO>
```

Surtio efecto en segundos. La maquina sigue intentando conectarse, pero no
logra autenticarse ni establecer el enlace.

Si el equipo esta en manos de un tercero y hay datos en disco, primero se
considera el borrado remoto del portatil. Revocar la red privada evita el acceso
a los servidores, pero **no borra nada de la maquina del empleado**.

---

## 5. Si se pierde la clave de un nodo

Este es el punto que hay que decir con claridad al cliente, porque no hay
trampas secretas ni comandos escondidos:

**No existe forma de recuperar el acceso a un nodo sin su clave privada de
WireGuard.** La clave esta en la maquina, protegida por el sistema. Si se pierde,
no hay soporte remoto que la regenere.

El procedimiento real es:

1. Crear una clave de incorporacion nueva para ese equipo.
2. El equipo se une de nuevo con la clave nueva.
3. En el servidor de coordinacion, eliminar el nodo viejo.

```bash
# 1. clave nueva
docker compose exec headscale headscale preauthkeys create --user <ID_USUARIO>

# 2. en la maquina afectada
tailscale up --login-server https://acceso.hrefesa.example --authkey <CLAVE_NUEVA>

# 3. limpiar el nodo viejo
docker compose exec headscale headscale nodes delete --identifier <ID_NODO_VIEJO>
```

Es una inconveniente, pero es una salida. **Y por eso el segundo factor de
verificación importa**: si el portatil tiene una clave de pantalla y cifrado de
disco activo, perder el equipo no equivale a perder el acceso.

---

## 6. Si se pierde la clave del servidor de coordinacion

Escenario mas grave: perder `data/noise_private.key`.

Es la identidad criptografica del servidor. Sin ella, **todos** los nodos dejan
de poderse comunicar con el servidor de coordinacion. No es un incidente de un
cliente, es un incidente del servicio de Hefesto.

Por eso ese archivo esta en el kit de respaldo y por eso `backup-headscale.sh` se
niega a terminar si no lo encuentra. Ver `docs/05-RESPALDOS-Y-RESTAURACION.md`.

---

## 7. Que verificar despues de revocar

1. Desde la maquina revocada, `tailscale status` deberia mostrar el nodo sin
   conexión, y no deberia alcanzar los servidores.
2. Desde otra maquina de la red, el resto sigue operando con normalidad.
3. `headscale nodes list` ya no muestra el nodo, o lo muestra vencido.

Revocar y no verificar es como no revocar: hay que cerrar el ciclo.

---

## 8. Lo que este kit NO puede hacer

- **No puede cerrar la laptop de un empleado.** Ver la seccion 4.
- **No deja un registro nativo de "quien entro, cuando y a que".** El registro
  de conexiones hay que construirlo aparte. Ver `docs/08-SERVICIOS-COMERCIALES.md`,
  seccion "Segundo factor y auditoria".
- **No obliga a un segundo factor de verificación** por si solo. Ver el mismo
  documento.

Esta lista debe formar parte de lo que Hefesto le dice al cliente al vender el
servicio. Un cliente que cree que tiene auditoria y MFA porque tiene una red
privada esta tomando una decisión de riesgo equivocada.