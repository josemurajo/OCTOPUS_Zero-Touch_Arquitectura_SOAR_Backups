# 🐙 Proyecto Zero-Touch: Arquitectura SOAR y Backups Inmutables

Bienvenido al sistema de despliegue automatizado Zero-Touch. Este proyecto convierte un servidor Linux virgen en un "Cerebro" central de seguridad (con MinIO, n8n y WireGuard) y despliega agentes de seguridad (Wazuh y Restic) en toda la red corporativa de forma automática.

## ⚠️ REQUISITOS PREVIOS (Muy Importante)
1. **El Cerebro (Servidor Principal):** Debes usar una máquina (física o virtual) con **Ubuntu Server 22.04 LTS o 24.04 LTS**. No uses otras distribuciones de Linux para el servidor principal, ya que el script utiliza paquetería nativa de Ubuntu (`apt`).
2. **Las Víctimas (Equipos Cliente):** Pueden ser Windows o Linux.
3. **Conexión:** El servidor Ubuntu debe tener acceso a internet y estar en la misma red local que los equipos que vas a proteger (o tener reglas de enrutamiento hacia sus VLANs).

---

## PASO 1: Descargar el Proyecto
Abre la terminal de tu servidor Ubuntu y descárgate la carpeta completa del proyecto. 

*(Si tienes el proyecto en un archivo .zip o en un pendrive, simplemente cópialo al servidor y sáltate este paso).*

Descárgalo directamente desde GitHub con estos comandos:
```bash
git clone https://github.com/josemurajo/OCTOPUS_Zero-Touch_Arquitectura_SOAR_Backups.git
cd OCTOPUS_Zero-Touch_Arquitectura_SOAR_Backups
```

---

## PASO 2: Arrancar el Sistema (Ejecución)
Una vez estés dentro de la carpeta del proyecto, entra al directorio de instalación, dale permisos al script y ejecútalo como Administrador:

```bash
cd install
chmod +x instalar.sh
sudo bash instalar.sh
```

---

## PASO 3: Qué hacer durante el proceso (Guía de Pantallas)

El script es 100% interactivo y te irá guiando paso a paso. Esto es lo que te va a preguntar:

1. **Instalación de dependencias:** Si te dice que faltan programas (como `nmap` o `dialog`), dile que **Sí (S)** para que los instale solos.
2. **Radar de VLANs:** Te dirá tu red local y te preguntará si quieres añadir otras VLANs. 
   * *Si todo está en la misma red, dile que No.*
   * *Si hay VLANs en la empresa, dile que Sí y escríbelas separadas por espacios (ej. 192.168.20.0/24).*
3. **Selección de Objetivos:** Te aparecerá una pantalla azul con todos los PCs encendidos. Usa la **Barra Espaciadora** para marcar los que quieres proteger y pulsa **Enter**.
4. **Contraseñas:** El sistema te pedirá la contraseña actual de esos ordenadores para poder entrar "el Día 1" a inyectar las defensas.
5. **Pre-Flight Checks (Cortafuegos):** El script comprobará si puede llegar a los PCs. Si el cortafuegos de la empresa corta el paso, te avisará con una pantalla roja. **Debes ir al router/firewall y abrir el puerto 22 (Linux) o 5985 (Windows) hacia esos PCs** y darle a "Volver a comprobar".

---

## PASO 4: El Final (Acción Requerida)
Una vez que el script termine de inyectar los agentes y las llaves de seguridad, verás un mensaje gigante confirmando el éxito. 

**En ese momento debes hacer dos cosas:**
1. **Cerrar los puertos:** Ve al Firewall de la empresa y **CIERRA** los puertos 22 y 5985 que abriste temporalmente. Ya no hacen falta, el sistema ahora funciona de forma invisible y segura.
2. **Verificar los servicios:** Abre el navegador web en cualquier PC de la red y entra a la IP de tu servidor Cerebro para comprobar que todo funciona:
   * **Consola de Backups (MinIO):** `http://<IP_DEL_SERVIDOR>:9001` (Usuario: *admin* | Pass: *SuperBackup2026!*)
   * **Consola de Automatización (n8n):** `http://<IP_DEL_SERVIDOR>:5678`
   * **Consola del Túnel (WireGuard):** `http://<IP_DEL_SERVIDOR>:51821` (Pass: *AdminZeroTrust!*)

---

## Credenciales y Seguridad Interna
Para facilitar el despliegue del laboratorio, algunas contraseñas vienen preconfiguradas en el código fuente. Si deseas usarlas o cambiarlas para un entorno real de producción, se encuentran aquí:

* **Bóveda de Backups (MinIO / Restic):** `SuperBackup2026!`
  * Modificable en la Fase 8.5 de `instalar.sh` y en `docker-compose.yml` (`MINIO_ROOT_PASSWORD`).
* **Panel de WireGuard:** `AdminZeroTrust!`
  * Modificable en `docker-compose.yml` (`PASSWORD`).
* **Llave Maestra de Ansible Vault:** * Se genera de forma aleatoria, automática y blindada en cada instalación. Si alguna vez necesitas verla, el script la guarda de forma local en el servidor en: `/opt/zerotouch/ansible/.vault_pass.txt`.





cd ~
git clone https://github.com/josemurajo/OCTOPUS_Zero-Touch_Arquitectura_SOAR_Backups.git
cd ~/OCTOPUS_Zero-Touch_Arquitectura_SOAR_Backups/install
sudo bash instalar.sh
ZeroTouch123!