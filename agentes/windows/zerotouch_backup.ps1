# ZeroTouch - Backup Diario (Windows, Portable)
# --------------------------------------------

# Ruta base del agente
$BaseDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Archivos portables
$ConfigFile = Join-Path $BaseDir "..\config.json"
$LogFile    = Join-Path $BaseDir "zerotouch_backup.log"

# Cargar configuración portable
$Config = Get-Content $ConfigFile | ConvertFrom-Json
$IP_CEREBRO = $Config.ip_cerebro
$ResticPassword = $Config.password_restic

$MinioURL = "http://$IP_CEREBRO:9000"
$Bucket = "backups"
$Date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

Add-Content $LogFile "`n[$Date] === ZeroTouch Backup Diario ==="

# Variables de entorno para Restic
$env:AWS_ACCESS_KEY_ID = "admin"
$env:AWS_SECRET_ACCESS_KEY = $ResticPassword
$env:RESTIC_PASSWORD = $ResticPassword

# Ejecutar backup
& "$BaseDir\restic.exe" -r "s3:$MinioURL/$Bucket" init `
    2>> $LogFile `
    || & "$BaseDir\restic.exe" -r "s3:$MinioURL/$Bucket" backup C:\Users `
    >> $LogFile 2>&1

Add-Content $LogFile "[$Date] Backup completado."
