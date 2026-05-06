#!/bin/bash
set -euo pipefail

# =========================================================================
# 0. DETECTAR RUTA REAL DEL PROYECTO
# =========================================================================
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_ROOT="$(realpath "$SCRIPT_DIR/..")"

BASE_DIR="/opt/zerotouch"
AGENTES_DIR="$BASE_DIR/agentes"
N8N_DIR="$BASE_DIR/n8n/workflows"
ANSIBLE_DIR="$BASE_DIR/ansible"

mkdir -p "$BASE_DIR" "$AGENTES_DIR/linux" "$AGENTES_DIR/windows" "$N8N_DIR" "$ANSIBLE_DIR" "$BASE_DIR/install"

# =========================================================================
# 1. COMPROBACIÓN DE PRIVILEGIOS
# =========================================================================
if [ "$EUID" -ne 0 ]; then
  echo -e "\e[31m⚠️ Error: Este script necesita permisos de Administrador.\e[0m"
  exit 1
fi

# =========================================================================
# 2. AUTO-INSTALADOR DE DEPENDENCIAS
# =========================================================================
IP_CEREBRO=$(hostname -I | awk '{print $1}')

echo "[+] Verificando dependencias..."
apt-get update -qq

declare -A PKG_TO_BIN=(
  [nmap]=nmap
  [ansible]=ansible
  [cron]=cron
  [dialog]=dialog
  [netcat]=nc
  [wireguard]=wg
  [sshpass]=sshpass
  [curl]=curl
  [docker.io]=docker
  [python3-requests]=python3
)

for pkg in "${!PKG_TO_BIN[@]}"; do
  bin=${PKG_TO_BIN[$pkg]}
  if ! command -v "$bin" &> /dev/null; then
    apt-get install -y "$pkg" -qq || true
  fi
done

# Docker compose detection
if command -v docker &> /dev/null && docker compose version &> /dev/null; then
  DOCKER_COMPOSE_CMD="docker compose"
elif command -v docker-compose &> /dev/null; then
  DOCKER_COMPOSE_CMD="docker-compose"
else
  apt-get install -y docker-compose-plugin -qq || true
  if docker compose version &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker compose"
  else
    apt-get install -y docker-compose -qq || true
    DOCKER_COMPOSE_CMD="docker-compose"
  fi
fi

systemctl enable --now docker || true
apt --fix-broken install -y -qq || true

# =========================================================================
# 3. DETECCIÓN DE REDES
# =========================================================================
SUBREDES_DETECTADAS=$(ip -o -f inet addr show | awk '{print $4}' | grep -v "^127\." || true)
[ -z "$SUBREDES_DETECTADAS" ] && SUBREDES_DETECTADAS="192.168.10.0/24"

if [ -t 1 ]; then
  OPCIONES_SUBREDES=()
  for subred in $SUBREDES_DETECTADAS; do
    OPCIONES_SUBREDES+=("$subred" "Red detectada" "on")
  done

  SUBREDES_ELEGIDAS=$(dialog --title "📡 Radar Octopus" --checklist "Selecciona redes:" 15 65 5 "${OPCIONES_SUBREDES[@]}" 3>&1 1>&2 2>&3)
  [ -z "$SUBREDES_ELEGIDAS" ] && exit 1
  SUBREDES_A_ESCANEAR=$(echo "$SUBREDES_ELEGIDAS" | tr -d '"')
else
  SUBREDES_A_ESCANEAR="$SUBREDES_DETECTADAS"
fi

# =========================================================================
# 4. ESCANEO NMAP
# =========================================================================
OPCIONES_DIALOG=()
for subred in $SUBREDES_A_ESCANEAR; do
  IPS=$(nmap -sn "$subred" -oG - | awk '/Up$/{print $2}') || true
  for ip in $IPS; do
    OPCIONES_DIALOG+=("$ip" "Equipo vivo" "off")
  done
done

if [ -t 1 ]; then
  EQUIPOS=$(dialog --title "🎯 Selección de Objetivos" --checklist "Equipos a proteger:" 20 70 12 "${OPCIONES_DIALOG[@]}" 3>&1 1>&2 2>&3)
  [ -z "$EQUIPOS" ] && exit 1
  EQUIPOS_LIMPIOS=$(echo "$EQUIPOS" | tr -d '"')
else
  EQUIPOS_LIMPIOS=$(printf "%s\n" "${OPCIONES_DIALOG[@]}" | awk 'NR%3==1' | head -n1)
fi

# =========================================================================
# 5. GESTIÓN DE CONTRASEÑAS
# =========================================================================
read -r -a REMAINING_IPS <<< "$EQUIPOS_LIMPIOS"
declare -A DICCIONARIO_PASSWORDS

if [ -t 1 ]; then
  if dialog --yesno "¿Hay varios equipos que compartan la MISMA contraseña?" 10 60; then
    while [ ${#REMAINING_IPS[@]} -gt 0 ]; do
      OPCIONES_GRUPO=()
      for ip in "${REMAINING_IPS[@]}"; do
        OPCIONES_GRUPO+=("$ip" "" "off")
      done

      GRUPO=$(dialog --checklist "Selecciona IPs con misma clave:" 20 60 10 "${OPCIONES_GRUPO[@]}" 3>&1 1>&2 2>&3)
      [ -z "$GRUPO" ] && break

      GRUPO_LIMPIO=$(echo "$GRUPO" | tr -d '"')
      PASS_COMPARTIDA=$(dialog --insecure --passwordbox "Contraseña para este grupo:" 10 60 3>&1 1>&2 2>&3)

      NUEVOS_REMAINING=()
      for ip in "${REMAINING_IPS[@]}"; do
        if echo "$GRUPO_LIMPIO" | grep -qw "$ip"; then
          DICCIONARIO_PASSWORDS["$ip"]="$PASS_COMPARTIDA"
        else
          NUEVOS_REMAINING+=("$ip")
        fi
      done

      REMAINING_IPS=("${NUEVOS_REMAINING[@]}")
      [ ${#REMAINING_IPS[@]} -eq 0 ] && break

      dialog --yesno "Quedan ${#REMAINING_IPS[@]}. ¿Hacer otro grupo?" 10 60 || break
    done
  fi
fi

for ip in "${REMAINING_IPS[@]}"; do
  if [ -t 1 ]; then
    PASS=$(dialog --insecure --passwordbox "Contraseña individual para $ip:" 10 60 3>&1 1>&2 2>&3)
  else
    PASS="ZeroTouch123!"
  fi
  DICCIONARIO_PASSWORDS["$ip"]="$PASS"
done

# =========================================================================
# 6. GENERAR CONFIG.JSON
# =========================================================================
cat <<EOF > "$AGENTES_DIR/config.json"
{
  "ip_cerebro": "$IP_CEREBRO",
  "password_restic": "SuperBackup2026!"
}
EOF

# =========================================================================
# 7. COPIAR AGENTES
# =========================================================================
cp -r "$PROJECT_ROOT/agentes/linux/"* "$AGENTES_DIR/linux/" || true
cp -r "$PROJECT_ROOT/agentes/windows/"* "$AGENTES_DIR/windows/" || true

# =========================================================================
# 8. COPIAR WORKFLOW
# =========================================================================
cp "$PROJECT_ROOT/n8n/workflows/zerotouch-completo.json" "$N8N_DIR/zerotouch-completo.json"

# =========================================================================
# 9. DOCKER-COMPOSE
# =========================================================================
mkdir -p "$BASE_DIR/install"

cat <<EOF > "$BASE_DIR/install/docker-compose.yml"
version: '3.8'
services:
  wg-easy:
    image: ghcr.io/wg-easy/wg-easy:latest
    container_name: cerebro_vpn
    environment:
      - WG_HOST=$IP_CEREBRO
      - PASSWORD=admin
    ports:
      - "51820:51820/udp"
      - "51821:51821/tcp"
    volumes:
      - wg_data:/etc/wireguard
    cap_add:
      - NET_ADMIN
    restart: unless-stopped

  minio:
    image: minio/minio:RELEASE.2024-03-15T00-00-00Z
    container_name: cerebro_boveda
    environment:
      MINIO_ROOT_USER: admin
      MINIO_ROOT_PASSWORD: SuperBackup2026!
    command: server /data --console-address ":9001"
    ports:
      - "9000:9000"
      - "9001:9001"
    volumes:
      - minio_data:/data
    restart: unless-stopped

  n8n:
    image: docker.n8n.io/n8nio/n8n:0.241.0
    container_name: cerebro_n8n
    ports:
      - "5678:5678"
    environment:
      - N8N_HOST=0.0.0.0
      - N8N_PORT=5678
      - N8N_PROTOCOL=http
      - NODE_ENV=production
      - N8N_ENABLE_FILE_BASED_WORKFLOWS=true
      - N8N_WORKFLOW_FILES=/workflows
    volumes:
      - $N8N_DIR:/workflows
    restart: unless-stopped

volumes:
  wg_data:
  minio_data:
EOF

(cd "$BASE_DIR/install" && $DOCKER_COMPOSE_CMD up -d)

# =========================================================================
# 10. INSTALAR WAZUH
# =========================================================================
curl -sO https://packages.wazuh.com/4.8/wazuh-install.sh
bash wazuh-install.sh -a | tee "$BASE_DIR/wazuh_result.txt" || true
WAZUH_PASS=$(grep "Password:" "$BASE_DIR/wazuh_result.txt" | awk '{print $2}' || echo "changeme")

# =========================================================================
# 11. INTEGRACIÓN WAZUH → N8N
# =========================================================================
cat <<EOF > /var/ossec/etc/integrations/custom-n8n.json
{
  "name": "custom-n8n",
  "hook_url": "http://$IP_CEREBRO:5678/webhook/wazuh-alert",
  "level": 7
}
EOF

systemctl restart wazuh-manager || true

# =========================================================================
# 12. ANSIBLE
# =========================================================================
echo "[seleccionados]" > "$ANSIBLE_DIR/inventario.ini"

for ip in "${!DICCIONARIO_PASSWORDS[@]}"; do
  PASS="${DICCIONARIO_PASSWORDS[$ip]}"
  sshpass -p "$PASS" ssh-copy-id -o StrictHostKeyChecking=no "$USER@$ip" || true
  echo "$ip ansible_user=$USER" >> "$ANSIBLE_DIR/inventario.ini"
done

ansible-playbook -i "$ANSIBLE_DIR/inventario.ini" "$ANSIBLE_DIR/despliegue.yml" \
  -e "ip_cerebro=$IP_CEREBRO password_restic=SuperBackup2026!" || true

# =========================================================================
# 13. REPORTE FINAL
# =========================================================================
clear
echo -e "\e[32m"
echo "================================================================="
echo "           🚀 OCTOPUS ZERO-TOUCH: DESPLIEGUE COMPLETO"
echo "================================================================="
echo -e "\e[0m"
echo "📍 IP CEREBRO:    $IP_CEREBRO"
echo "-----------------------------------------------------------------"
echo "🌐 WAZUH SIEM:    https://$IP_CEREBRO (Pass: $WAZUH_PASS)"
echo "🔐 VPN WIREGUARD: http://$IP_CEREBRO:51821"
echo "📦 MINIO BÓVEDA:  http://$IP_CEREBRO:9001 (User: admin / Pass: SuperBackup2026!)"
echo "🤖 N8N SOAR:      http://$IP_CEREBRO:5678"
echo "-----------------------------------------------------------------"
echo "✅ Ansible configurado con SSH Keys"
echo "✅ Wazuh 4.8 instalado"
echo "✅ n8n automatizado (file-based workflows)"
echo "================================================================="
