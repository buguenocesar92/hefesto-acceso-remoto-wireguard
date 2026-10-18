#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Hefesto Studio - restauracion del servidor de coordinacion Headscale.
#
# Que hace y, sobre todo, que NO hace:
#   - Verifica el manifiesto SHA-256 antes de tocar nada.
#   - Si falta MANIFESTO.sha256, se niega: un respaldo incompleto no se restaura.
#   - Nunca borra la base de datos. Si hay archivos de destino, los aparta con
#     otro nombre en vez de eliminarlos.
#   - Al terminar deja el servicio DETENIDO, para que la persona a cargo revise.
#
# Uso:
#   ./scripts/restore-headscale.sh --from <carpeta-de-respaldo>
#   ./scripts/restore-headscale.sh --from <carpeta-de-respaldo> --force
# ---------------------------------------------------------------------------
set -euo pipefail

CONTENEDOR="headscale"
KIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ORIGEN=""
FORCE=0

log()  { printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"; }
error(){ printf '[%s] ERROR: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >&2; exit 1; }

uso() {
  cat >&2 <<'FIN'
Uso: restore-headscale.sh --from <carpeta-de-respaldo> [--force]

  --from <carpeta>  Carpeta del respaldo a restaurar. Obligatorio.
  --force           Permite restaurar encima de archivos que ya existen.
                    Los archivos actuales se apartan con sufijo .prev-<fecha>,
                    nunca se borran.

Sin --force, si algun archivo de destino ya existe, el script se detiene antes
de modificar nada.
FIN
}

while [ $# -gt 0 ]; do
  case "$1" in
    --from)    [ $# -ge 2 ] || error "falta el valor de --from"; ORIGEN="$2"; shift 2 ;;
    --from=*)  ORIGEN="${1#*=}"; shift ;;
    --force)   FORCE=1; shift ;;
    -h|--help) uso; exit 0 ;;
    *) error "argumento desconocido: $1" ;;
  esac
done

[ -n "$ORIGEN" ] || { uso; exit 1; }

# --- Validaciones previas ---------------------------------------------------
command -v sha256sum >/dev/null 2>&1 || error "falta la herramienta sha256sum"

[ -d "$ORIGEN" ] || error "no existe la carpeta de respaldo: $ORIGEN"
ORIGEN="$(cd "$ORIGEN" && pwd)"

MANIFESTO="$ORIGEN/MANIFESTO.sha256"
[ -f "$MANIFESTO" ] || error "no existe MANIFESTO.sha256 en $ORIGEN: el respaldo esta incompleto y no se restaura"
[ -s "$MANIFESTO" ] || error "MANIFESTO.sha256 esta vacio: el respaldo esta incompleto y no se restaura"

# --- Lista blanca: solo se restauran estos archivos --------------------------
# Cualquier otra ruta del manifiesto se ignora y se avisa. Esto evita que un
# manifiesto manipulado escriba fuera del kit.
aplicar() {
  case "$1" in
    datos/db.sqlite)                  echo "data/db.sqlite" ;;
    datos/noise_private.key)          echo "data/noise_private.key" ;;
    datos/derp_server_private.key)    echo "data/derp_server_private.key" ;;
    config/config.yaml)               echo "config/config.yaml" ;;
    config/policy.hujson)             echo "config/policy.hujson" ;;
    *) return 1 ;;
  esac
}

log "leyendo el manifiesto"
PLAN="$(mktemp)"
trap 'rm -f "$PLAN"' EXIT

while read -r _suma ruta; do
  [ -n "${ruta:-}" ] || continue
  # Validacion de recorrido de rutas, aunque la lista blanca ya acota el
  # destino: se comprueba igual que el manifiesto sea coherente consigo mismo.
  case "$ruta" in
    /*)              error "el manifiesto contiene una ruta absoluta, se rechaza: $ruta" ;;
    *..*)            error "el manifiesto contiene una ruta con .., se rechaza: $ruta" ;;
  esac
  destino="$(aplicar "$ruta")" || { log "AVISO: se ignora la entrada fuera de la lista blanca: $ruta"; continue; }
  [ -f "$ORIGEN/$ruta" ] || error "el manifiesto menciona $ruta pero el archivo no esta en el respaldo"
  printf '%s\t%s\n' "$ruta" "$destino" >> "$PLAN"
done < "$MANIFESTO"

[ -s "$PLAN" ] || error "el manifiesto no contiene ninguna entrada restaurable"

# --- Comprobacion de integridad ---------------------------------------------
log "verificando las sumas SHA-256 antes de tocar nada"
if ! ( cd "$ORIGEN" && sha256sum -c --quiet MANIFESTO.sha256 ); then
  error "las sumas no coinciden: el respaldo esta corrupto y NO se restaura"
fi
log "integridad verificada"

# --- Comprobacion de destino ANTES de modificar nada ------------------------
COLISIONES=0
while IFS=$'\t' read -r origen_rel destino_rel; do
  if [ -e "$KIT_ROOT/$destino_rel" ] && [ "$FORCE" -ne 1 ]; then
    printf '  ya existe: %s\n' "$destino_rel" >&2
    COLISIONES=1
  fi
done < "$PLAN"

if [ "$COLISIONES" -eq 1 ]; then
  error "hay archivos de destino que ya existen y no se paso --force. No se modifico nada."
fi

# --- Detener el servicio ----------------------------------------------------
if command -v docker >/dev/null 2>&1 && docker inspect -f '{{.State.Running}}' "$CONTENEDOR" >/dev/null 2>&1; then
  if [ "$(docker inspect -f '{{.State.Running}}' "$CONTENEDOR")" = "true" ]; then
    log "deteniendo el contenedor $CONTENEDOR"
    docker stop "$CONTENEDOR" >/dev/null
  fi
else
  log "el contenedor $CONTENEDOR no esta corriendo; se continua"
fi

SELLO="$(date -u +%Y%m%dT%H%M%SZ)"

# --- Restauracion ------------------------------------------------------------
log "restaurando"
while IFS=$'\t' read -r origen_rel destino_rel; do
  destino="$KIT_ROOT/$destino_rel"
  mkdir -p "$(dirname "$destino")"

  if [ -e "$destino" ]; then
    # No se borra nada: el archivo actual se aparta con sello de tiempo.
    log "apartando el archivo actual: $destino_rel -> $destino_rel.prev-$SELLO"
    mv "$destino" "$destino.prev-$SELLO"
  fi

  cp -p "$ORIGEN/$origen_rel" "$destino"
  log "restaurado: $destino_rel"
done < "$PLAN"

# --- Verificacion posterior --------------------------------------------------
log "verificando las sumas sobre los archivos recien restaurados"
while IFS=$'\t' read -r origen_rel destino_rel; do
  esperado="$(awk -v f="$origen_rel" '$2 == f {print $1}' "$MANIFESTO" | head -n1)"
  [ -n "$esperado" ] || error "no se pudo recalcular el hash esperado de $origen_rel"
  obtained="$(sha256sum "$KIT_ROOT/$destino_rel" | awk '{print $1}')"
  [ "$esperado" = "$obtained" ] || error "el archivo restaurado $destino_rel no coincide con el manifiesto"
done < "$PLAN"

log "restauracion verificada correctamente"

cat <<FIN

Siguiente paso, manual y a conciencia:
  1. Revisar que config/config.yaml tenga el server_url y el base_domain correctos.
  2. Levantar el servicio cuando se este seguro:
       docker compose up -d
  3. Confirmar la salud:
       docker compose exec headscale headscale health

El servicio quedo DETENIDO a proposito para que la revision sea una decision
del operador y no un efecto colateral del script.

Notas importantes:
  - Si se restauro db.sqlite, la red privada vuelve tal como estaba: usuarios,
    nodos, claves y politicas. No hay que reincorporar ningun servidor.
  - Si se restauro noise_private.key, los nodos NO se reconectan solos.
    Hay que emitir claves nuevas para cada maquina del cliente.
    Ver ejemplos/03-revocacion-acceso.DEMOSTRACION.md
  - Los archivos apartados con sufijo .prev-<fecha> se pueden borrar a mano
    cuando la persona a cargo confirme que ya no los necesita.
FIN