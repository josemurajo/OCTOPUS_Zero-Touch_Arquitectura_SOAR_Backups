# ZeroTouch - Alerta Visual de Restauración (Portable)
# ----------------------------------------------------

# Ruta base del agente
$BaseDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$LogFile = Join-Path $BaseDir "alerta_restauracion.log"

$Date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Add-Content $LogFile "`n[$Date] Mostrando alerta visual al usuario..."

# Mostrar alerta
Add-Type -AssemblyName PresentationFramework

[System.Windows.MessageBox]::Show(
    "AVISO DEL DEPARTAMENTO DE SEGURIDAD`n`n
Se ha detectado una amenaza grave y el sistema ha sido restaurado automáticamente
a la última copia de seguridad sana.",
    "ZeroTouch - Restauración Automática",
    "OK",
    "Warning"
)

Add-Content $LogFile "[$Date] Alerta mostrada correctamente."
