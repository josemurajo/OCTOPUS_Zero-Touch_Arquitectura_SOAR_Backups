# ZeroTouch - Restauración Avanzada (Windows, Portable)
# -----------------------------------------------------

# Ruta base del agente
$BaseDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Archivos portables
$ConfigFile = Join-Path $BaseDir "..\config.json"
$LogFile    = Join-Path $BaseDir "zerotouch_restore.log"

# Cargar configuración portable
$Config = Get-Content $ConfigFile | ConvertFrom-Json
$IP_CEREBRO = $Config.ip_cerebro
$ResticPassword = $Config.password_restic

$MinioURL = "http://$IP_CEREBRO:9000"
$Bucket = "backups"
$Date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$Hostname = $env:COMPUTERNAME

Add-Content $LogFile "`n[$Date] === ZeroTouch Restauración Avanzada ==="

# Variables de entorno para Restic
$env:AWS_ACCESS_KEY_ID = "admin"
$env:AWS_SECRET_ACCESS_KEY = $ResticPassword
$env:RESTIC_PASSWORD = $ResticPassword

# 1. Obtener snapshots
Add-Content $LogFile "[$Date] Obteniendo snapshots..."
$snapshots = & "$BaseDir\restic.exe" -r "s3:$MinioURL/$Bucket" snapshots --json | ConvertFrom-Json

if ($snapshots.Count -eq 0) {
    Add-Content $LogFile "[$Date] ERROR: No hay snapshots disponibles."
    exit 1
}

# 2. Seleccionar último snapshot
$Snapshot = $snapshots[-1].short_id
Add-Content $LogFile "[$Date] Snapshot seleccionado: $Snapshot"

# 3. Verificar integridad parcial
Add-Content $LogFile "[$Date] Verificando integridad..."
& "$BaseDir\restic.exe" -r "s3:$MinioURL/$Bucket" check --read-data-subset=5% | Out-Null

# 4. Restaurar
Add-Content $LogFile "[$Date] Restaurando archivos modificados..."
& "$BaseDir\restic.exe" -r "s3:$MinioURL/$Bucket" restore $Snapshot --target C:\ --verify | Out-Null

# 5. Notificar a n8n
Add-Content $LogFile "[$Date] Notificando a n8n..."
Invoke-RestMethod -Method POST -Uri "http://$IP_CEREBRO:5678/webhook/restauracion" `
    -ContentType "application/json" `
    -Body (@{
        host = $Hostname
        snapshot = $Snapshot
        fecha = $Date
    } | ConvertTo-Json)

Add-Content $LogFile "[$Date] Restauración completada correctamente."
