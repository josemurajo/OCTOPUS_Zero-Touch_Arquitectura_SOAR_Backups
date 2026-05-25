#!/bin/bash
set -euo pipefail

# ZeroTouch - Restauración Avanzada (Linux, Portable)

BASE_DIR="$(dirname "$(realpath "$0")")"
CONF_FILE="$BASE_DIR/../config.json"
LOG="$BASE_DIR/zerotouch_restore.log"

DATE=$(date +"%Y-%m-%d %H:%M:%S")
HOSTNAME=$(hostname)

IP_CEREBRO=$(jq -r '.ip_cerebro' "$CONF_FILE")
RESTIC_PASSWORD=$(jq -r '.password_restic' "$CONF_FILE")

export AWS_ACCESS_KEY_ID="admin"
export AWS_SECRET_ACCESS_KEY="$RESTIC_PASSWORD"
export RESTIC_PASSWORD="$RESTIC_PASSWORD"

MINIO_URL="http://$IP_CEREBRO:9000"
BUCKET="backups"

echo "[$DATE] === ZeroTouch Restauración Avanzada ===" >> "$LOG"

# 1. Obtener snapshots
echo "[$DATE] Obteniendo snapshots..." >> "$LOG"
SNAPSHOT=$(restic -r s3:$MINIO_URL/$BUCKET snapshots --json | jq -r '.[-1].short_id')

if [ -z "$SNAPSHOT" ]; then
    echo "[$DATE] ERROR: No hay snapshots disponibles." >> "$LOG"
    exit 1
fi

echo "[$DATE] Snapshot seleccionado: $SNAPSHOT" >> "$LOG"

# 2. Verificar integridad parcial
echo "[$DATE] Verificando integridad..." >> "$LOG"
restic -r s3:$MINIO_URL/$BUCKET check --read-data-subset=5% >> "$LOG" 2>&1

# 3. Restaurar
echo "[$DATE] Restaurando archivos modificados..." >> "$LOG"
restic -r s3:$MINIO_URL/$BUCKET restore "$SNAPSHOT" --target / --verify >> "$LOG" 2>&1

# 4. Notificar a n8n
echo "[$DATE] Notificando a n8n..." >> "$LOG"
curl -s -X POST "http://$IP_CEREBRO:5678/webhook/restauracion" \
    -H "Content-Type: application/json" \
    -d "{\"host\":\"$HOSTNAME\",\"snapshot\":\"$SNAPSHOT\",\"fecha\":\"$DATE\"}" >> "$LOG" 2>&1

echo "[$DATE] Restauración completada correctamente." >> "$LOG"
