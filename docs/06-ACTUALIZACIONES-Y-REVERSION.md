# 06 - Actualizaciones y reversion

---

## 1. Que se actualiza y con que riesgo

En este kit hay dos versiones independientes, y confundirlas es el error
clasico:

| Pieza | Versión | Quien la actualiza | Riesgo |
|---|---|---|---|
| Servidor de coordinacion | Headscale **v0.29.5** | Hefesto | Medio |
| Cliente en los nodos | Tailscale | Nadie, si esta fijado | **Alto** |

La de abajo es la que mas problemas da.

---

## 2. Actualizar el servidor de coordinacion

### 2.1 Antes de nada

```bash
./scripts/backup-headscale.sh --dir /var/backups/hefesto/pre-actualizacion-$(date +%Y%m%d)
```

Si hay que volver atras, se restaura ese respaldo. Sin esto, no hay vuelta.

### 2.2 Leer las notas de la versión nueva

Antes de tirar el comando, leer la seccion de cambios de la release. Buscar
tres cosas en particular:

1. Cambios en las claves de `config.yaml`. Si aparece una clave nueva con valor
   distinto al de omision, hay que revisarla.
2. Cambios en el esquema de la base de datos. SQLite migra solo, pero conviene
   saberlo antes.
3. Menciones de compatibilidad con el cliente Tailscale.

Fuente: <https://github.com/juanfont/headscale/releases>

### 2.3 Cambiar la imagen

Editar `compose.yaml`:

```yaml
image: docker.io/headscale/headscale:<VERSION_NUEVA>@sha256:<DIGEST_NUEVO>
```

Actualizar **ambos**: etiqueta y digest. Fijar solo la etiqueta deja abierta la
puerta a que un cambio del registro instale algo distinto de lo que se probo.

Conseguir el digest desde Docker Hub:

```bash
docker buildx imagetools inspect headscale/headscale:<VERSION_NUEVA>
```

### 2.4 Levantar y comprobar

```bash
docker compose pull
docker compose up -d
docker compose exec headscale headscale health
docker compose exec headscale headscale nodes list
```

Si la lista de nodos esta completa, el despliegue funciono.

### 2.5 Comprobacion completa de la red

Actualizar el servidor es la parte facil. Lo que hay que verificar es que la red
sigue sirviendo: entrar por SSH a un servidor del cliente desde un escritorio de
la red privada, usando la direccion privada.

Si eso falla despues de actualizar, el problema casi seguro esta en el cliente.
Ver la seccion siguiente.

---

## 3. Actualizar el cliente Tailscale en los nodos

Esta es la parte delicada del kit, y la razon por la que el `compose.yaml`
desactiva `auto_update` en el servidor: **las versiones del cliente las
controla Hefesto, no el usuario**.

### Por que no se actualiza solo

upstream declara en `docs/about/clients.md` v0.29.5 que se apunta a soportar las
**ultimas 10 versiones** del cliente Tailscale. Esa es la política, pero la
ventana real entre una versión del cliente y el soporte de headscale es un dato
que se conoce leyendo los reportes, no leyendo la promesa.

Un cliente que se actualiza solo un viernes a las seis de la tarde puede dejar de
entrar a los servidores de un cliente, y ese problema se descubre el fin de
semana.

### Procedimiento

En cada maquina del cliente:

```bash
sudo tailscale set --auto-update=false
tailscale version
```

Anotar la versión instalada. Repetir en todas.

### Actualizar en un servidor

1. Respaldo del servidor de coordinacion.
2. Elegir una maquina piloto, no todas.
3. Anotar la versión actual.
4. Actualizar:

   ```bash
   sudo apt update && sudo apt install tailscale
   ```

5. Comprobar que entra y que llega a la red.
6. Si funciona, propagar por etapas, no a todo el cliente de una vez.

### Volver atras

Es la parte buena: **es reversible**. El cliente Tailscale mantiene versiones
anteriores disponibles en su repositorio.

```bash
tailscale version
# fijar la version anterior en la maquina y reiniciar
sudo systemctl restart tailscaled
```

No hay migración de datos en el cliente y no hay que tocar el servidor de
coordinacion. Es una de las razones por las que el riesgo de compatibilidad con
Tailscale se puede manejar: el lado facil de arreglar es el cliente.

---

## 4. Versión de Tailscale usada por el cliente

upstream admite que hay pasos adicionales de configuración en Windows, macOS,
Android, iOS y tvOS. No son opcionales: hay que seguirlos. Ver
`docs/usage/connect/` del tag v0.29.5.

La versión de Tailscale que instala el sistema se anota en la ficha del cliente,
para poder reproducir el entorno si hace falta.

---

## 5. Actualizar el kit

Los cambios de Hefesto al kit no se aplican sobre un despliegue en uso. Se
aplican sobre una copia, se levanta en un entorno de pruebas y recien ahi se
promueven a los clientes.

Orden recomendado al aplicar un cambio de configuración:

1. Respaldar.
2. Editar `config/config.yaml`.
3. Si es la política, recargar con `docker kill -s HUP headscale`.
4. Si es cualquier otra cosa, `docker compose up -d`.
5. Comprobar con `headscale health` y `headscale nodes list`.

---

## 6. Cadencia sugerida

| Que | Cada cuanto |
|---|---|
| Respaldo | Diario |
| Revisar avisos de seguridad de Headscale | Semanal |
| Actualizar Headscale | Trimestral, o antes si hay aviso |
| Probar una versión nueva de Tailscale | Semestral |
| Actualizar los clientes del cliente | Semestral, por etapas |
| Restaurar un respaldo en aislamiento | Trimestral |

La regla que importa mas que las demas: **nunca cambiar la versión del cliente
Tailscale y la del servidor en el mismo momento**. Si algo falla, hay que poder
saber de que lado vino.