# EJEMPLOS

Todos los archivos de esta carpeta son **DEMOSTRACION**.

Contienen nombres de empresas, dominios, direcciones y usuarios inventados.
Estan para mostrar el procedimiento a un cliente o para que Hefesto se familiarice
con los comandos. **No son plantillas listas para entregar**: hay que adaptarlas
al cliente antes de usarlas en un despliegue real.

| Archivo | Que muestra |
|---|---|
| `01-servidor-cliente.DEMOSTRACION.md` | Incorporar un servidor del cliente con etiqueta |
| `02-escritorio-empleado.DEMOSTRACION.md` | Incorporar la maquina de escritorio de un empleado |
| `03-revocacion-acceso.DEMOSTRACION.md` | Que hacer cuando alguien se va, o cuando se pierde un equipo |

---

## Advertencia sobre comandos destructivos

`03-revocacion-acceso.DEMOSTRACION.md` contiene comandos que eliminan acceso de
verdad: `nodes expire`, `nodes delete`, `preauthkeys expire` y
`users destroy`. No probarlos en la red de un cliente sin avisar. Sobre todo
`users destroy`, que elimina al usuario y todo lo que le quedaba sin dueño.

En una red recien montada, primero en un entorno de prueba.

---

## Comandos usados aquí

Todos los comandos de headscale usados en estos ejemplos se verificaron contra
el tag v0.29.5. La lista completa esta en `docs/04-PRIMERA-CUENTA-Y-USUARIOS.md`
y en `docs/10-LICENCIAS-Y-FUENTES.md`.