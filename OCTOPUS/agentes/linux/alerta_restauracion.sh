#!/bin/bash
# ZeroTouch - Alerta Visual de Restauración (Linux, Portable)

BASE_DIR="$(dirname "$(realpath "$0")")"
LOG="$BASE_DIR/alerta_restauracion.log"

DATE=$(date +"%Y-%m-%d %H:%M:%S")
echo "[$DATE] Mostrando alerta..." >> "$LOG"

wall "⚠️ AVISO DE SEGURIDAD  
Se ha restaurado automáticamente una copia de seguridad sana debido a una amenaza grave."

echo "[$DATE] Alerta mostrada." >> "$LOG"
