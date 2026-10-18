# 09 - Exportación, traspaso y fin de contrato

Como se le devuelve el control al cliente, o como se traspasa a otro
administrador, cuando Hefesto deja de operar la red.

Este documento existe porque el cliente tiene que poder irse. Un proveedor que se
resiste a soltar el acceso no es un proveedor, es un rehén.

---

## 1. Que hay que entregar

| Elemento | Donde esta | Sensitivity |
|---|---|---|
| Base de datos | `data/db.sqlite` | Toda la red del cliente |
| Clave de Noise | `data/noise_private.key` | **Identidad del servidor** |
| Configuración | `config/config.yaml` | Dominios y ajustes |
| Política de segmentacion | `config/policy.hujson` | Reglas de acceso |
| Dominio | Registro DNS | Punto de entrada |
| Certificados | Renovacion, si aplica | Estado TLS |

**El `db.sqlite` y el `noise_private.key` juntos son la red completa.** Quien
tenga ambos puede administrar la red del cliente. Tratarlos como el activo mas
sensible del contrato, no como un archivo de configuración.

---

## 2. Exportación con los scripts de este kit

```bash
./scripts/backup-headscale.sh --dir /var/backups/traspaso-$(date +%Y%m%d)
```

Eso genera una carpeta con el manifiesto, los datos y la configuración. Entregar
esa carpeta **cifrada**, con una clave entregada por un canal distinto al del
archivo.

### Por que la clave de Noise es lo mas importante

Es la identidad criptografica del servidor de coordinacion. Sin ella, la base
restaurada **no sirve**: los nodos no pueden autenticarse contra el servidor.

Quien recibe solo el `db.sqlite` y no la clave, tiene una base de datos y nada
mas.

Quien recibe ambos, puede levantar un servidor de coordinacion identico y
administrar todos los nodos.

---

## 3. Traspaso a otro administrador

Para que otro administrador pueda operar la red, necesita:

1. La carpeta de respaldo completa (base, clave, configuración, política).
2. El **dominio** y el acceso al DNS. Sin control del dominio no hay
   `server_url` que valga.
3. El acceso al servidor, si se traspasa la maquina.
4. Acceso a la cuenta que maneja el dominio en el proxy.

### Documentacion minima que hay que entregar

No es un extra, es parte del traspaso:

- Que software corre y que versión exacta, con digest.
- Que puerto hay abierto y por que: **solo TCP 443**.
- Donde estan los respaldos y como se restauran.
- Que nodos existen y a que usuario pertenecen.
- Como se crea un usuario, una clave y como se revoca.
- Que la base es SQLite y **no** se debe migrar a PostgreSQL, porque upstream lo
  desaconseja expresamente.

Entregar el `README.md` y la carpeta `docs/` de este kit cubre casi todo eso.

---

## 4. Baja del servicio

Cuando el cliente cancela, el orden correcto es:

### 4.1. Notificar y coordinar

La red va a dejar de existir. El cliente tiene que enterarse con tiempo para
elegir si se la lleva o la descarta.

### 4.2. Entregar o destruir, según se haya acordado

| Si se **entrega** | Si se **destruye** |
|---|---|
| Ejecutar el respaldo final | Borrar `data/` por completo |
| Cifrarlo y entregarlo | Borrar la carpeta de respaldos |
| Entregar dominio y acceso | Revocar o liberar el dominio |
| Entregar la documentacion | Anotar la baja en el registro |

Destruir la red es decisión del cliente, no de Hefesto. Si el cliente quiere
borrarla, se borra: los datos son suyos.

### 4.3. Quitar la superficie publicada

Despublicar el dominio del DNS. Si la entrada sigue viva y alguien la resuelve,
el servidor de coordinacion sigue respondiendo, y eso es un servicio abierto al
que nadie esta pagando.

---

## 5. Fin de vida del despliegue del proveedor

Cuando el servidor se retira:

1. **No borrar la imagen antes de confirmar los respaldos.** Si hay una duda, el
   respaldo es lo único que hay.
2. Borrar el directorio del kit del servidor.
3. Borrar los respaldos si el cliente los recibio.
4. Anotar el cliente y el periodo en el registro interno de Hefesto.

Si el cliente deja de pagar y no contesta, no se borra nada por las dudas. Se
avisa dos veces con plazo y recien ahi se libera el dominio, por decisión de
Hefesto y documentada.

---

## 6. Continuidad del servicio

Si el servidor de coordinacion se cae y hay respaldo, se levanta en otra VPS y la
red vuelve **sin tocar los servidores del cliente**. Esa es la mayor ventaja
operativa del producto: no hay migración de datos en los nodos.

El tiempo de recuperacion depende del registro que tenga Hefesto:

| Esta cubierto | Cuando se recupera |
|---|---|
| Respaldos diarios, restauración probada en serio | Horas |
| Respaldos diarios, restauración nunca probada | Incertidumbre: puede ser un dia entero o la red entera |
| Sin respaldo | Hay que reincorporar cada maquina |

El respaldo diario sin probar equivale a no tener respaldo. Ver
`docs/05-RESPALDOS-Y-RESTAURACION.md`.

---

## 7. Responsabilidad sobre la red del cliente

Aclaracion importante para el traspaso:

- Hefesto opera **la red privada**.
- Los **sistemas del cliente** siguen siendo del cliente: sus servidores, sus
  parches, sus respaldos, su seguridad.
- Si un servidor del cliente esta vulnerable, esa es una decisión del cliente,
  no una falla de la red privada.

Esta distincion va escrita en el contrato. Sin ella, el primer incidente de
seguridad termina siendo una discusion sobre de quien era la responsabilidad.

---

## 8. Datos personales

La red privada guarda datos personales: nombres de usuario, equipos y a quien
pertenecen. Si el servicio termina o cambia de proveedor:

- La red del cliente anterior **no debe quedar accesible** desde la red nueva.
- Cada red es independiente y no se mezclan clientes.
- El `db.sqlite` del cliente que se va se entrega a ese cliente y no se conserva
  como activo de Hefesto, salvo acuerdo distinto.

Una red por cliente, sin mezcla. Es la misma razon por la que no se ofrece
multi-tenant en este kit.