#!/bin/bash

# Configuración
BACKUP_DIR="/backup"  # Cambia esto a tu directorio de backup
PROXMOX_IP="192.168.0.3"
PROXMOX_USER="root"
PROXMOX_PASS="Jc15811305"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="backup_$TIMESTAMP.tar.gz"

# Función para mostrar el avance
function show_progress {
    echo "=============================="
    echo "$1"
    echo "=============================="
}

# Actualizar el sistema e instalar dependencias
show_progress "Actualizando el sistema e instalando dependencias..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y timeshift sshpass

# Crear un directorio de backup si no existe
if [ ! -d "$BACKUP_DIR" ]; then
    mkdir -p "$BACKUP_DIR"
fi

# Crear un punto de restauración
show_progress "Creando un punto de restauración..."
sudo timeshift --create --comments "Punto de restauración creado el $TIMESTAMP"

# Comprimir el directorio de backup
show_progress "Comprimiendo el directorio de backup..."
tar -czf "$BACKUP_DIR/$BACKUP_NAME" /ruta/al/directorio/a/respaldar  # Cambia esto a tu directorio a respaldar

# Transferir el backup a Proxmox
show_progress "Transfiriendo el backup a Proxmox..."
sshpass -p "$PROXMOX_PASS" rsync -avz "$BACKUP_DIR/$BACKUP_NAME" "$PROXMOX_USER@$PROXMOX_IP:/ruta/de/destino/"  # Cambia esto a tu ruta de destino en Proxmox

# Verificar si la transferencia fue exitosa
if [ $? -eq 0 ]; then
    show_progress "Backup transferido exitosamente a Proxmox."
else
    show_progress "Error al transferir el backup a Proxmox."
fi

# Hacer el script ejecutable (si se ejecuta desde otro script o entorno)
chmod +x "$0"
