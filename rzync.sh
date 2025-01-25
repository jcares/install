#!/bin/bash

# Variables
USER="root"                  
IP_UBUNTU="192.168.0.254"    # IP del servidor Ubuntu
IP_CENTOS="172.16.1.254"     # IP del servidor CentOS
RUTA_COPIA="/"                # Copiar todo desde la raíz de Ubuntu
RUTA_LOCAL="/tmp/backup"      # Ruta temporal en la máquina local
RUTA_DESTINO="/backup"        # Ruta de destino en CentOS

# 1. Actualizar CentOS
echo "Actualizando CentOS..."
ssh "$USER@$IP_CENTOS" "yum update -y"

# 2. Instalar rsync si no está instalado
echo "Instalando rsync..."
ssh "$USER@$IP_CENTOS" "yum install -y rsync"

# 3. Crear directorio temporal local
echo "Creando directorio temporal local..."
mkdir -p "$RUTA_LOCAL"

# 4. Copiar todos los archivos y directorios a la máquina local
echo "Copiando todos los archivos de Ubuntu a la máquina local..."
rsync -avz --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found"} -e "ssh" "$USER@$IP_UBUNTU:$RUTA_COPIA" "$RUTA_LOCAL"

# 5. Crear directorio de destino en CentOS
echo "Creando directorio de destino en CentOS..."
ssh "$USER@$IP_CENTOS" "mkdir -p $RUTA_DESTINO"

# 6. Copiar desde la máquina local al servidor CentOS
echo "Copiando todos los archivos al servidor CentOS..."
rsync -avz "$RUTA_LOCAL/" "$USER@$IP_CENTOS:$RUTA_DESTINO"

# 7. Limpiar directorio temporal local
echo "Limpiando directorio temporal local..."
rm -rf "$RUTA_LOCAL/*"

# Finalizar
echo "Migración completada."
