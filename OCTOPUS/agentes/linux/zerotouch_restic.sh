#!/bin/bash
set -euo pipefail

# ZeroTouch - Backup Diario (Linux, Portable)

BASE_DIR="$(dirname "$(realpath "$0")")"
CONF_FILE="$BASE_DIR/../config.json"
LOG="$BASE_DIR/zerotouch_backup.log"

DATE=$(date "+%Y-%m-%d %H:%M:%S")

IP_CEREBRO=$(jq -r '.ip_cerebro' "$CONF_FILE")
RESTIC_PASSWORD=$(jq -r '.password_restic' "$CONF_FILE")

export AWS_ACCESS_KEY_ID="admin"
export AWS_SECRET_ACCESS_KEY="$RESTIC_PASSWORD"
export RESTIC_PASSWORD="$RESTIC_PASSWORD"

MINIO_URL="http://$IP_CEREBRO:9000"
BUCKET="backups"

echo "[$DATE] === ZeroTouch Backup Diario ===" >> "$LOG"

# Comprobar si el repositorio existe realmente
if ! restic -r s3:$MINIO_URL/$BUCKET cat config >/dev/null 2>&1; then
    echo "[$DATE] Repositorio no encontrado. Inicializando..." >> "$LOG"
    restic -r s3:$MINIO_URL/$BUCKET init >> "$LOG" 2>&1
fi

echo "[$DATE] Ejecutando backup..." >> "$LOG"
restic -r s3:$MINIO_URL/$BUCKET backup /home >> "$LOG" 2>&1

echo "[$DATE] Backup completado." >> "$LOG"
