#!/bin/bash
# =========================================
# Instalador desatendido de GPSafe Web 6.11.1
# =========================================
# Autor: PCCuricó SPA
# Contacto: jcares@pccurico.cl
# =========================================

set -e

# -----------------------------
# Configuración desatendida
# -----------------------------
SRC_REPO="https://github.com/jcares/web-gpsafe2026V6.11.1.git"
SRC_DIR="/tmp/web-gpsafe2026V6.11.1"
DEST_DIR="/opt/traccar/web"

echo "==> Inicio de instalación desatendida GPSafe Web 6.11.1"

# -----------------------------
# Clonar frontend si no existe
# -----------------------------
if [ ! -d "$SRC_DIR" ]; then
    echo "==> Clonando frontend desde GitHub..."
    git clone --depth 1 "$SRC_REPO" "$SRC_DIR"
else
    echo "==> Carpeta temporal $SRC_DIR ya existe, se usará esa versión"
fi

# -----------------------------
# Backup de frontend anterior
# -----------------------------
if [ -d "$DEST_DIR" ]; then
    BACKUP_DIR="${DEST_DIR}_backup_$(date +%Y%m%d%H%M%S)"
    echo "==> Creando backup de la versión anterior en $BACKUP_DIR"
    sudo mv "$DEST_DIR" "$BACKUP_DIR"
fi

# -----------------------------
# Crear carpeta destino
# -----------------------------
sudo mkdir -p "$DEST_DIR"

# -----------------------------
# Reemplazar credenciales en app.js
# -----------------------------
APP_JS="$SRC_DIR/app.js"
if [ -f "$APP_JS" ]; then
    echo "==> Configurando usuario y contraseña de la API"
    sed -i "s|const USER = .*|const USER = \"$API_USER\";|" "$APP_JS"
    sed -i "s|const PASS = .*|const PASS = \"$API_PASS\";|" "$APP_JS"
fi

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
    sudo mkdir -p "$(dirname "$DEST_FILE")"
    sudo cp -a "$SRC_FILE" "$DEST_FILE"
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
# Ajustar permisos
# -----------------------------
echo "==> Ajustando permisos..."
sudo chown -R "$USER:$GROUP" "$DEST_DIR"
sudo chmod -R 755 "$DEST_DIR"

# -----------------------------
# Finalización
# -----------------------------
echo "========================================="
echo " Instalación completada."
echo " Carpeta destino: $DEST_DIR"
echo " Usuario API: $API_USER / Contraseña API: $API_PASS"
echo " Si es necesario, reinicia el servidor Traccar:"
echo " sudo systemctl restart traccar"
echo "========================================="
