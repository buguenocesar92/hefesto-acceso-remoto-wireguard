# 08 - Servicios comerciales

Como se vende este kit, que se promete y que no se puede prometer.

Este documento esta pensado para pegarse al alcance de trabajo antes de cotizar.

---

## 1. Que es el producto

Un servicio recurrente por el que el cliente accede a sus propios servidores sin
exponerlos a internet y sin depender de una VPN comercial.

El cliente mantiene sus servidores. Hefesto mantiene la red privada que los une.

---

## 2. El problema que resuelve

Hoy, los servidores de los clientes son accesibles por SSH público. Eso significa:

- La superficie expuesta a internet es la de todos los servidores, todos los
  dias.
- Cada intento de fuerza bruta contra el puerto 22 llega al servidor.
- La credencial del servidor es el único control que hay entre un atacante y los
  datos.
- Un empleado que se va deja acceso hasta que alguien se acuerde de revocarlo.

La red privada cambia la respuesta a la primera pregunta: el puerto 22 deja de
estar abierto. El servidor no se ve desde internet. El acceso entra por un
servidor de coordinacion, y la autenticación es criptografica, no por contrasena
compartida.

**Y una venta concreta:** a los clientes que ya tienen servidores, este es un
servicio adicional sobre una instalación que ya existe. No hay que migrar nada.
Es el kit de mas facil de vender del catalogo por esa razon.

---

## 3. Que se promete

1. **Los servidores no quedan expuestos a internet.** El puerto de administración
   se cierra y se entra por la red privada.
2. **El trafico va cifrado de punto a punto con WireGuard.** El servidor de
   coordinacion reparte claves; **no transporta el trafico** de los usuarios.
3. **El servidor de coordinacion expone un solo puerto: TCP 443.**
4. **La revocacion es inmediata y verificable.** Un comando, y se comprueba que
   dejo de entrar.
5. **Los clientes usan las aplicaciones oficiales de Tailscale**, que ya existen
   y ya funcionan en los sistemas habituales.

---

## 4. Que NO se promete

Esta parte es la que protege al cliente y a Hefesto. **Va al alcance de trabajo.**

### 4.1 No es un sustituto de una VPN comercial

Si el sector del cliente exige un proveedor **auditado** y certificado, esto **no
lo reemplaza**. Headscale no tiene certificaciones SOC 2 ni ISO 27001. Es un
proyecto open source, y su administración la lleva Hefesto.

Cuando un cliente tiene una exigencia de cumplimiento, la respuesta no es
"instalamos Headscale y quedamos iguales". La respuesta es: esto cubre el acceso
técnico, pero su exigencia de auditoria hay que resolverla por otra via.

Un cliente que compra esto creyendo que cumple una norma y despues descubre que
no, es un problema serio. Mejor decirlo antes.

### 4.2 No borra el acceso de un equipo

Revocar el acceso impide entrar a la red privada. **No borra nada del equipo.**

Si el portatil del empleado tiene datos del cliente, la revocacion de la red no los
borra. El borrado remoto del portatil es otra cosa, y hay que decidir por separado
cual es la política del cliente.

### 4.3 No se puede recuperar una clave perdida

Si una maquina pierde su clave privada de WireGuard, **no hay comando de
recuperacion**. Hay que emitir una clave nueva y volver a unir la maquina. No es
una trampa: es una salida real, pero lleva tiempo y visita.

### 4.4 No es multi-tenant

**Una red por cliente.** No se mezclan clientes en una misma red, y no hay
aislamiento entre redes de clientes distintos dentro de un mismo despliegue.

Si Hefesto opera para varios clientes, cada uno tiene su propio servidor o su
propio despliegue. Es una decisión de seguridad, no una limitacion que se vaya a
corregir mas adelante: mezclar redes de clientes distintos en un mismo dominio de
coordinacion concentra el riesgo.

### 4.5 No es auditoria de accesos

Ver la seccion 6, que es la mas importante de este documento.

### 4.6 No obliga a un segundo factor de verificación

Ver la seccion 6 también.

---

## 5. Modelo de cobro

**Servicio recurrente mensual**, porque hay trabajo permanente:

- Mantener el servidor de coordinacion andando.
- Respaldar todos los dias y **probar la restauración**.
- Atender incidencias de acceso.
- Incorporar y revocar nodos cuando el cliente lo pida.
- Actualizar el software sin romper nada.
- Revisar los avisos de seguridad de Headscale.

Lo que **no** se cobra, porque es del cliente:

- Su hardware, su sistema operativo, sus backups.
- El mantenimiento de sus servidores, que sigue siendo suyo.
- Los problemas de su red local.

Cobrar solo "instalar" y despues abandonar el servicio obliga a cobrar de nuevo
en cada incidente. Cobrar el recurrente desde el principio es mas honesto y mas
barato para el cliente.

---

## 6. Segundo factor de verificación y auditoria

Esta seccion existe porque es la brecha real del producto y hay que hablarla con
el cliente antes de que la descubra.

### 6.1 El problema

Una red privada da dos cosas: conectividad y cifrado. **No da identidad verificada
ni registro de accesos.**

Eso significa que:

- Un portatil abierto y desatendido da acceso a los servidores. Sin contrasena, sin
  segundo factor, sin aviso.
- Si alguien entra a un servidor, saber quien entro y cuando **no sale de la red
  privada**: hay que reconstruirlo desde los logs del servidor.

Que haya un registro de conexiones **no es lo mismo** que auditar. El cliente tiene
que entender esa diferencia antes de comprar.

### 6.2 Segundo factor de verificación

**Headscale no implementa MFA.** La autenticación de un nodo es por clave pública
de WireGuard. Quien tiene el archivo de claves, tiene acceso. Eso no lo cambia
ninguna configuración.

Como suplirlo, en orden de costo:

**Opcion 1 - Requerirlo en el cliente Tailscale.** Los clientes oficiales de
Tailscale permiten exigir autenticación multifactor en la cuenta que controla el
dispositivo. Cubre a las personas, no a los servidores.

Cuidado con el detalle: eso protege la cuenta de Tailscale del usuario, no la red
privada de Hefesto. Son cosas distintas y no hay que venderlas como la misma.

**Opcion 2 - Cifrado de disco en los portatiles.** Un portatil robado con el disco
cifrado no entrega la clave de WireGuard. Barato de explicar y de medir.

**Opcion 3 - Tailscale SSH.** Headscale soporta reglas `ssh` en la política.
Permite entrar por SSH usando la identidad de la red en vez de contrasenas del
sistema, y se puede restringir por usuario del sistema destino.

Ventaja real: sin contrasenas SSH que se filtren y sin reenvio de puerto. Coste:
cambia el modelo de acceso y hay que probarlo bien antes de ofrecerlo.

Este kit **no la habilita**. Hay que probarla y decidir antes.

**Opcion 4 - Segundo factor en el borde.** Si el cliente tiene su propia solucion
de identidad, se integra ahi.

### 6.3 Auditoria: que se puede construir

Headscale **no entrega un registro nativo de "quien entro, cuando y a que"**.
No hay historial de conexiones en el panel, porque no hay panel.

Lo que si se puede construir:

| Fuente | Que aporta |
|---|---|
| Logs de `sshd` del servidor destino | Quien entro, desde que direccion, a que hora. **La fuente real** |
| `journalctl` del headscale | Eventos de registro, nodos y cambios de configuración |
| Historico de `tailscale status` guardado | Que equipos estaban conectados en un momento dado |

La combinacion cubre el caso habitual: quien entro a un servidor, desde que IP
privada y a que hora. La IP privada se traduce a un equipo consultando la lista
de nodos de headscale.

Eso es **auditoria construida a mano**, no una función del producto. Hay que
decirlo así.

Lo que queda fuera, y hay que decirlo: **no se puede probar que alguien NO entro.**
Un registro muestra entradas, no ausencias.

### 6.4 Compromiso minimo, sin costo

Lo que Hefesto deberia entregar siempre, porque es barato y marca la diferencia:

1. **Guardar la salida de `headscale nodes list` al momento de cada
   incorporacion y de cada revocacion.** Con fecha. Es un registro de quien
   estaba en la red y cuando.
2. **Política de nombres sin ambiguedad.** Cada maquina con un nombre que
   identifique a su dueno o su función. Un nodo llamado `portatil` no sirve para
   auditar nada.
3. **Un usuario por persona.** Nunca un usuario compartido.

Los tres juntos no reemplazan a una auditoria real, pero hacen que la
reconstruccion sea posible, que es la mayor parte del problema.

---

## 7. Para quien tiene sentido

**Si:**

- Tiene servidores accesibles por SSH público y le preocupa.
- Tiene varios servidores y empleados que entran a ellos.
- Quiere salir de una VPN comercial por costo o por dependencia.
- Valora no abrir puertos.

**Si no:**

- Tiene una exigencia de cumplimiento que exige proveedor auditado.
- Es una sola persona con un solo servidor.
- Espera que esto le resuelva la auditoria de accesos.
- Espera un producto con panel de autogestion para sus usuarios finales. **No lo
  tiene**: la administración es por linea de comandos y la hace Hefesto.

---

## 8. Preguntas que el cliente va a hacer

**"¿Tienen panel web?"**
No. Se administra por linea de comandos. Es una decisión deliberada: son menos
piezas que mantener y todo es automatizable. Lo que el cliente pierde es
autogestion. Ver `LICENCIAS.md`.

**"¿Puedo auditar quien entro?"**
Parcialmente. Los servidores registran sus accesos SSH, y eso se puede
reconstruir. Pero no hay un historial de conexiones de la red privada, porque el
producto no lo trae. Hay que construirlo. Ver seccion 6.3.

**"¿Tienen doble factor?"**
No viene integrado. Se puede exigir en el cliente Tailscale del usuario y
activar cifrado de disco en los equipos. Ver seccion 6.2.

**"Si mi empleado se va, ¿pierdo todos los servidores?"**
No. Los servidores no son de nadie. Los nodos con etiqueta no tienen dueno y no
se pierden. Ver `ejemplos/03-revocacion-acceso.DEMOSTRACION.md`.

**"¿Es lo mismo que una VPN de verdad?"**
No es lo mismo. Una VPN comercial ofrece panel, auditoria, MFA y cumplimiento.
Esto ofrece lo que importa para el caso de uso de Hefesto: acceso sin exponer
los servidores, a costo mucho menor. Si el cliente necesita lo otro, esto no
cubre el requisito.

**"¿Puedo conectar esto a mi propia red, con mis otras oficinas?"**
Si, mediante enrutadores de subredes, pero **este kit no lo usa ni lo aprueba**.
Aumenta el alcance de la red y hay que probarlo aparte.

---

## 9. Lo que hay que dejar por escrito

Al cerrar el contrato, explicito:

- Que no es sustituto de un proveedor VPN auditado.
- Que no incluye auditoria de accesos ni MFA integrados.
- Que una red por cliente, sin multi-tenant.
- Que la revocacion impide entrar pero no borra los equipos.
- Que los respaldos son tan sensibles como los servidores, porque contienen la
  red completa del cliente.

Si el cliente acepta, el alcance es honesto y defendible.