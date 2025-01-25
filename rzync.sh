#!/bin/bash

# Variables
USER="root"                  # Usuario para ambos servidores
IP_UBUNTU="192.168.0.254"    # IP del servidor Ubuntu
IP_CENTOS="172.16.1.254"     # IP del servidor CentOS
RUTA_COPIA="/ruta/a/tu/carpeta" # Cambia esto por la ruta que deseas copiar
RUTA_DESTINO="/ruta/de/destino" # Cambia esto por la ruta de destino en Ubuntu

# 1. Actualizar CentOS
echo "Actualizando CentOS..."
ssh "$USER@$IP_CENTOS" "yum update -y"

# 2. Instalar rsync si no está instalado
echo "Instalando rsync..."
ssh "$USER@$IP_CENTOS" "yum install -y rsync"

# 3. Copiar archivos a Ubuntu
echo "Copiando archivos a Ubuntu..."
rsync -avz -e "ssh" "$USER@$IP_CENTOS:$RUTA_COPIA" "$USER@$IP_UBUNTU:$RUTA_DESTINO"

# Finalizar
echo "Migración completada."
