#!/bin/bash
# =========================================
# Instalador desatendido de GPSafe Web 6.11.1
# =========================================
# Autor: PCCuricó SPA
# =========================================

set -e

# -----------------------------
# Configuración
# -----------------------------
ZIP_URL="https://github.com/jcares/web-gpsafe2026V6.11.1/archive/refs/heads/main.zip"
TMP_DIR="/tmp/gpsafe-web"
DEST_DIR="/opt/traccar/web"

echo "==> Inicio de instalación desatendida GPSafe Web 6.11.1"

# -----------------------------
# Verificar permisos sudo
# -----------------------------
if [ "$EUID" -ne 0 ]; then
  echo "ERROR: Este script necesita permisos sudo"
  echo "Ejecuta: sudo bash $0"
  exit 1
fi

# -----------------------------
# Crear carpeta temporal
# -----------------------------
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

# -----------------------------
# Descargar y descomprimir ZIP
# -----------------------------
echo "==> Descargando frontend desde GitHub..."
wget -qO "$TMP_DIR/gpsafe.zip" "$ZIP_URL"

echo "==> Descomprimiendo archivos..."
unzip -q "$TMP_DIR/gpsafe.zip" -d "$TMP_DIR"

SRC_DIR=$(find "$TMP_DIR" -maxdepth 1 -type d -name "*main" | head -n1)

# -----------------------------
# Backup de frontend anterior
# -----------------------------
if [ -d "$DEST_DIR" ]; then
    BACKUP_DIR="${DEST_DIR}_backup_$(date +%Y%m%d%H%M%S)"
    echo "==> Creando backup de la versión anterior en $BACKUP_DIR"
    mv "$DEST_DIR" "$BACKUP_DIR"
fi

# -----------------------------
# Crear carpeta destino
# -----------------------------
mkdir -p "$DEST_DIR"

# -----------------------------
# Copiar archivos con progreso
# -----------------------------
echo "==> Copiando archivos al destino ($DEST_DIR)..."
TOTAL=$(find "$SRC_DIR" -type f | wc -l)
COUNT=0

copy_file() {
    local SRC_FILE="$1"
    local REL_PATH="${SRC_FILE#$SRC_DIR/}"
    local DEST_FILE="$DEST_DIR/$REL_PATH"
    mkdir -p "$(dirname "$DEST_FILE")"
    cp -a "$SRC_FILE" "$DEST_FILE"
    ((COUNT++))
    PERCENT=$((COUNT*100/TOTAL))
    echo -ne "\rProgreso: $PERCENT% ($COUNT/$TOTAL)"
}

export -f copy_file
export SRC_DIR DEST_DIR COUNT TOTAL

find "$SRC_DIR" -type f | while read FILE; do
    copy_file "$FILE"
done

echo -e "\n==> Archivos copiados correctamente."

# -----------------------------
# Ajustar permisos según Traccar
# -----------------------------
TRACCAR_USER=$(ps -eo user,comm | grep traccar | grep -v grep | awk '{print $1}' | head -n1)
if [ -z "$TRACCAR_USER" ]; then
    TRACCAR_USER="traccar"
fi

echo "==> Ajustando permisos para usuario del servicio: $TRACCAR_USER"
chown -R "$TRACCAR_USER":"$TRACCAR_USER" "$DEST_DIR"
chmod -R 755 "$DEST_DIR"

# -----------------------------
# Finalización
# -----------------------------
echo "========================================="
echo " Instalación completada."
echo " Carpeta destino: $DEST_DIR"
echo " Usuario propietario ajustado a: $TRACCAR_USER"
echo " Si es necesario, reinicia el servidor Traccar:"
echo " sudo systemctl restart traccar"
echo "========================================="
