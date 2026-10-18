# 05 - Respaldos y restauración

Este kit tiene una sola cosa que no se puede recuperar si se pierde: el estado
del servidor de coordinacion. Y ese estado cabe en dos archivos.

---

## 1. Que hay que respaldar

| Elemento | Ruta | Que se pierde sin el |
|---|---|---|
| **Base de datos** | `data/db.sqlite` | Usuarios, nodos, claves y políticas de todos los clientes |
| **Clave de Noise** | `data/noise_private.key` | La identidad del servidor |
| Clave del DERP embebido | `data/derp_server_private.key` | La identidad del relay, solo si se activo |
| Configuración | `config/config.yaml` | Ajustes del despliegue |
| Política | `config/policy.hujson` | La segmentacion de la red |

### Por que la clave de Noise es el archivo critico

Es la identidad criptografica del servidor de coordinacion. Sin ella:

- **Todos** los nodos dejan de poder registrarse.
- Los nodos ya registrados no pueden autenticarse.
- No se puede volver atras: hay que emitir claves nuevas para cada maquina.

Por eso `backup-headscale.sh` **se niega a terminar si no encuentra ese archivo**.
Un respaldo sin el no sirve, y es mejor fallar en el momento del respaldo que
descubrirlo cuando ya se necesita.

### Que NO se respalda

Las claves privadas de los nodos. Viven en las maquinas del cliente y no se
pueden copiar: WireGuard esta disenado justamente para que no salgan. No hay
nada que respaldar ahi.

---

## 2. Metodo: por que el servicio se detiene

Los scripts detienen el contenedor antes de copiar. No es descuido, es el metodo
para obtener una copia coherente.

SQLite admite copiar el archivo mientras se escribe, y la mayor parte de las
veces funciona. Pero si hay una escritura a mitad de la copia, la base
resultante esta incompleta y el fallo aparece dias despues, en el peor momento.
Detener el servicio unos segundos elimina esa posibilidad.

Es un intercambio consciente: una ventana muy breve sin servicio a cambio de un
respaldo del que se pueda depender.

---

## 3. Respaldar

```bash
./scripts/backup-headscale.sh --dir /var/backups/hefesto/acceso-remoto/2026-10-17
```

Con `--force` para escribir en un destino existente. Sin el, el script se niega.

Estructura del respaldo:

```
2026-10-17/
  MANIFESTO.sha256      <- se escribe AL FINAL. Es la marca de completitud
  METADATOS.txt
  datos/
    db.sqlite
    noise_private.key
  config/
    config.yaml
    policy.hujson
```

### El manifiesto es la marca de completitud

`MANIFESTO.sha256` se escribe **al final**, despues de copiar todos los archivos.

**Si no existe, el respaldo esta incompleto y no sirve.** Un respaldo sin
manifiesto podria haberse cortado a mitad de camino, y no hay forma de saberlo.

Verificación:

```bash
cd /var/backups/hefesto/acceso-remoto/2026-10-17
sha256sum -c MANIFESTO.sha256
```

Cada linea debe decir `OK`.

---

## 4. Restaurar

```bash
./scripts/restore-headscale.sh --from /var/backups/hefesto/acceso-remoto/2026-10-17
```

Con `--force` si hay archivos de destino que ya existen.

### Lo que hace el script, en orden

1. Verifica que exista `MANIFESTO.sha256`. Si falta, **se niega**.
2. Verifica las sumas SHA-256. Si alguna no coincide, **se niega**.
3. Rechaza rutas absolutas y rutas con `..` en el manifiesto.
4. Aplica una **lista blanca**: solo restaura los archivos conocidos. Cualquier
   otra entrada se ignora con un aviso. Un manifiesto manipulado no puede
   escribir fuera del kit.
5. Comprueba colisiones de destino **antes de modificar nada**.
6. Detiene el servicio.
7. Restaura y verifica las sumas de nuevo sobre los archivos escritos.

### Lo que el script nunca hace

- **No borra la base de datos.** Nunca hay un `DROP` ni una eliminación.
- **No sobrescribe en silencio.** Sin `--force`, se detiene si algo ya existe.
  Con `--force`, aparta el archivo actual a `<archivo>.prev-<fecha>` en vez de
  borrarlo.
- **No deja el servicio corriendo.** Termina con el contenedor detenido, a
  propósito, para que revisar y levantar sea una decisión del operador y no un
  efecto colateral.

### Levantar despues de restaurar

```bash
docker compose up -d
docker compose exec headscale headscale health
```

---

## 5. Restaurar en otro servidor

Escenario frecuente: la VPS fallo y hay que reconstruir en una nueva.

1. Instalar una VPS nueva con el mismo dominio y el mismo certificado.
2. Copiar el kit completo.
3. `cp config/config.yaml` con el `server_url` y el `base_domain` correctos.
4. Restaurar:

   ```bash
   ./scripts/restore-headscale.sh --from /var/backups/hefesto/acceso-remoto/2026-10-17 --force
   ```

5. Levantar el servicio.
6. **No hace falta reincorporar ningun servidor del cliente.** La base y la
   clave de Noise restauradas son la misma red: los nodos se vuelven a conectar
   solos, siempre que la maquina del cliente no haya cambiado.

Ese es justamente el motivo por el que se respalda la clave de Noise y no solo
la base de datos.

### Si se cambio el dominio

Se puede, pero hay que actualizar `server_url` **antes** de levantar. Si el
dominio cambia y los clientes siguen apuntando al anterior, no se autentican.
Los nodos ya registrados siguen en la base y vuelven a funcionar cuando el
dominio nuevo este operativo.

---

## 6. Política de respaldo

Para un servicio recurrente, una copia no basta.

| Que | Cada cuanto | Donde |
|---|---|---|
| Respaldo local | Diario | `data/` del servidor, retencion de 7 dias |
| Respaldo remoto | Semanal | Otra ubicacion, retencion de 3 meses |

El respaldo remoto no es opcional. Un respaldo guardado en el mismo disco que
servidor no es un respaldo: es una copia. Si se pierde el disco, se pierde todo.

### Cifrado de los respaldos

Un respaldo contiene la red entera de un cliente: quien tenga `noise_private.key`
y `db.sqlite` puede reconstituirla. Tratarlo con la misma sensibilidad que el
servidor. Si sale del servidor, cifrarlo.

---

## 7. Rotacion

```bash
#!/bin/sh
# Borrar respaldos de mas de 7 dias. No borra nada que no sea un respaldo.
find /var/backups/hefesto/acceso-remoto -maxdepth 1 -type d -mtime +7 \
     -exec rm -rf {} +
```

Cuidado con este tipo de scripts: `rm -rf` con `find` es de las operaciones que
mas dano hacen cuando el camino esta mal escrito. **Probar primero sin el
`-exec`**, mirando que devuelve `find`.

---

## 8. Verificación del respaldo

Un respaldo sin probar es una esperanza.

- **Cada mes:** correr `sha256sum -c MANIFESTO.sha256` sobre el respaldo mas
  reciente.
- **Cada trimestre:** restaurar en un servidor aislado y comprobar que el
  servicio levanta y que la lista de nodos esta completa.

La segunda es la que importa. La primera demuestra que los archivos no se
corrompieron; la segunda demuestra que el respaldo sirve para algo.