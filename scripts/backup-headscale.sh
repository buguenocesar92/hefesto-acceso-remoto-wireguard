#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Hefesto Studio - respaldo del servidor de coordinacion Headscale.
#
# Que respalda:
#   datos/db.sqlite            usuarios, nodos, claves publicas y politicas
#   datos/noise_private.key    identidad criptografica del servidor
#   datos/derp_server_private.key  solo si se activo el DERP embebido
#   config/config.yaml         configuracion activa
#   config/policy.hujson       politica de segmentacion
#
# Metodo: el servicio se detiene, se copian los archivos y se vuelve a levantar.
# Detener el servicio es lo que garantiza una copia coherente de SQLite: copiar el
# archivo con el servicio corriendo puede capturar una base a medio escribir.
#
# El respaldo se da por bueno solo si existe MANIFESTO.sha256. Ese archivo se
# escribe AL FINAL. Si no esta, el respaldo esta incompleto y no sirve.
#
# Uso:
#   ./scripts/backup-headscale.sh --dir <destino>
#   ./scripts/backup-headscale.sh --dir <destino> --force
# ---------------------------------------------------------------------------
set -euo pipefail

CONTENEDOR="headscale"
KIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA_DIR="${KIT_ROOT}/data"
CONFIG_DIR="${KIT_ROOT}/config"
DESTINO=""
FORCE=0

log()  { printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"; }
error(){ printf '[%s] ERROR: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >&2; exit 1; }

uso() {
  cat >&2 <<'FIN'
Uso: backup-headscale.sh --dir <destino> [--force]

  --dir <destino>  Carpeta donde se escribe el respaldo. Obligatorio.
  --force          Permite escribir en un destino que ya existe.

Sin --force, si el destino ya existe, el script se niega a continuar.
FIN
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dir)    [ $# -ge 2 ] || error "falta el valor de --dir"; DESTINO="$2"; shift 2 ;;
    --dir=*)  DESTINO="${1#*=}"; shift ;;
    --force)  FORCE=1; shift ;;
    -h|--help) uso; exit 0 ;;
    *) error "argumento desconocido: $1" ;;
  esac
done

[ -n "$DESTINO" ] || { uso; exit 1; }

# --- Validacion del destino -------------------------------------------------
case "$DESTINO" in
  /|"") error "el destino no puede ser la raiz del sistema" ;;
esac

# Reutiliza el destino si ya existe, si no lo crea.
if [ -e "$DESTINO" ]; then
  [ -d "$DESTINO" ] || error "el destino existe y no es una carpeta: $DESTINO"
  if [ "$FORCE" -ne 1 ]; then
    error "el destino ya existe: $DESTINO (use --force si realmente quiere escribir ahi)"
  fi
  log "AVISO: --force en uso, se escribe sobre $DESTINO"
else
  mkdir -p "$DESTINO"
fi

RESPUESTAS="$DESTINO"
mkdir -p "$RESPUESTAS/datos" "$RESPUESTAS/config"

# --- Comprobaciones previas -------------------------------------------------
command -v sha256sum >/dev/null 2>&1 || error "falta la herramienta sha256sum"
command -v docker     >/dev/null 2>&1 || error "falta docker"

[ -f "$DATA_DIR/db.sqlite" ] || error "no existe $DATA_DIR/db.sqlite: no parece una instalacion de headscale"

# --- Detener el servicio ----------------------------------------------------
SERVICIO_ESTABA_ARRIBA=0
if docker inspect -f '{{.State.Running}}' "$CONTENEDOR" >/dev/null 2>&1; then
  if [ "$(docker inspect -f '{{.State.Running}}' "$CONTENEDOR")" = "true" ]; then
    SERVICIO_ESTABA_ARRIBA=1
    log "deteniendo el contenedor $CONTENEDOR para copiar sin inconsistencias"
    docker stop "$CONTENEDOR" >/dev/null
  fi
fi

# Si algo falla a partir de aca, el servicio debe quedar como estaba.
restaurar_servicio() {
  if [ "$SERVICIO_ESTABA_ARRIBA" -eq 1 ]; then
    log "volviendo a levantar $CONTENEDOR"
    docker start "$CONTENEDOR" >/dev/null || log "ATENCION: no se pudo levantar $CONTENEDOR, levantelo a mano"
  fi
}
trap 'restaurar_servicio' EXIT

# --- Copia de los datos -----------------------------------------------------
log "copiando la base de datos"
cp -p "$DATA_DIR/db.sqlite" "$RESPUESTAS/datos/db.sqlite"
# Archivos auxiliares del modo WAL. Se copian por completitud, pero la copia
# coherente es db.sqlite ya consolidada al haber detenido el servicio.
for extra in db.sqlite-wal db.sqlite-shm; do
  [ -f "$DATA_DIR/$extra" ] && cp -p "$DATA_DIR/$extra" "$RESPUESTAS/datos/$extra" || true
done

log "copiando la clave privada de Noise"
if [ -f "$DATA_DIR/noise_private.key" ]; then
  cp -p "$DATA_DIR/noise_private.key" "$RESPUESTAS/datos/noise_private.key"
else
  error "falta $DATA_DIR/noise_private.key: el respaldo seria inutil sin la identidad del servidor"
fi

if [ -f "$DATA_DIR/derp_server_private.key" ]; then
  log "copiando la clave del DERP embebido"
  cp -p "$DATA_DIR/derp_server_private.key" "$RESPUESTAS/datos/derp_server_private.key"
fi

log "copiando la configuracion"
for archivo in config.yaml policy.hujson; do
  if [ -f "$CONFIG_DIR/$archivo" ]; then
    cp -p "$CONFIG_DIR/$archivo" "$RESPUESTAS/config/$archivo"
  else
    log "AVISO: no existe $CONFIG_DIR/$archivo"
  fi
done

# --- Metadatos (se escriben temprano, no sirven como marca de completitud) ----
cat > "$RESPUESTAS/METADATOS.txt" <<META
Respaldo de Headscale - Hefesto Studio
Generado (UTC)      : $(date -u +%Y-%m-%dT%H:%M:%SZ)
Host                : $(hostname)
Version del kit     : $(cat "${KIT_ROOT}/VERSION.md" 2>/dev/null | grep -i -m1 'headscale' || echo "ver VERSION.md")
Contenedor          : ${CONTENEDOR}
Origen de los datos : ${DATA_DIR}
Nota: un respaldo sin MANIFESTO.sha256 esta incompleto y no debe usarse.
META

# --- Reinicio antes de sellar el respaldo -----------------------------------
restaurar_servicio
trap - EXIT

# --- Manifiesto: se escribe AL FINAL y es la marca de completitud -----------
log "calculando sumas SHA-256"
(
  cd "$RESPUESTAS"
  # find imprime rutas relativas a la carpeta actual, en orden estable.
  find datos config -type f ! -name 'MANIFESTO.sha256' -print0 \
    | LC_ALL=C sort -z \
    | xargs -0 sha256sum
) > "$RESPUESTAS/MANIFESTO.sha256"

[ -s "$RESPUESTAS/MANIFESTO.sha256" ] || error "el manifiesto quedo vacio: el respaldo esta incompleto"

log "respaldo terminado y sellado en: $RESPUESTAS"
log "verificalo con:  cd '$RESPUESTAS' && sha256sum -c MANIFESTO.sha256"