#!/bin/bash

# Variables
USER="root"                  
IP_UBUNTU="192.168.0.254"    
IP_CENTOS="172.16.1.254"     
RUTA_COPIA="/"                # Copiar todo desde la raíz
RUTA_DESTINO="/backup"        # Ruta de destino en Ubuntu

# 1. Actualizar CentOS
echo "Actualizando CentOS..."
ssh "$USER@$IP_CENTOS" "yum update -y"

# 2. Instalar rsync si no está instalado
echo "Instalando rsync..."
ssh "$USER@$IP_CENTOS" "yum install -y rsync"

# 3. Crear directorio de destino en Ubuntu
echo "Creando directorio de destino en Ubuntu..."
ssh "$USER@$IP_UBUNTU" "mkdir -p $RUTA_DESTINO"

# 4. Copiar todos los archivos y directorios a Ubuntu
echo "Copiando todos los archivos a Ubuntu..."
rsync -avz --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found"} -e "ssh" "$USER@$IP_CENTOS:$RUTA_COPIA" "$USER@$IP_UBUNTU:$RUTA_DESTINO"

# Finalizar
echo "Migración completada."
