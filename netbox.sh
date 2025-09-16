#!/bin/bash

# Variables
NETBOX_DIR="/opt/netbox/netbox"
VENV_DIR="/opt/netbox/venv"
STATIC_ROOT="/opt/netbox/static"
STATIC_URL="/static/"
SERVER_USER="www-data"  # Cambia esto si tu servidor web usa otro usuario

# Activar el entorno virtual
echo "Activando el entorno virtual..."
source "$VENV_DIR/bin/activate"

# Verificar si Django está instalado
if ! python -m django --version &>/dev/null; then
    echo "Django no está instalado. Instalando Django..."
    pip install django
else
    echo "Django ya está instalado."
fi

# Instalar dependencias de NetBox
echo "Instalando dependencias de NetBox..."
pip install -r "$NETBOX_DIR/requirements.txt"

# Ejecutar la recopilación de archivos estáticos
echo "Ejecutando collectstatic..."
python "$NETBOX_DIR/manage.py" collectstatic --noinput

# Verificar la existencia del archivo setmode.js
if [ -f "$STATIC_ROOT/js/setmode.js" ]; then
    echo "El archivo setmode.js existe en $STATIC_ROOT/js/setmode.js."
else
    echo "Error: El archivo setmode.js no se encuentra en $STATIC_ROOT/js/setmode.js."
    exit 1
fi

# Configurar permisos para el directorio de archivos estáticos
echo "Configurando permisos para el directorio de archivos estáticos..."
sudo chown -R $SERVER_USER:$SERVER_USER "$STATIC_ROOT/"
sudo chmod -R 755 "$STATIC_ROOT/"

# Verificar la configuración del servidor web
echo "Por favor, asegúrate de que tu servidor web esté configurado para servir archivos estáticos desde $STATIC_ROOT."
echo "Ejemplo de configuración para Nginx:"
echo "location $STATIC_URL {"
echo "    alias $STATIC_ROOT;"
echo "}"

# Reiniciar el servidor web
echo "Reiniciando el servidor web..."
sudo systemctl restart nginx  # Cambia esto a apache2 si usas Apache

echo "Configuración completada. Por favor, verifica los registros del servidor si encuentras problemas."
