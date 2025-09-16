#!/bin/bash

# Variables
NETBOX_DIR="/opt/netbox/netbox"
VENV_DIR="/opt/netbox/venv"
STATIC_ROOT="/opt/netbox/static"
SERVER_USER="www-data"  # Cambia esto si tu servidor web usa otro usuario

# Función para verificar el estado de un comando
check_command() {
    if [ $? -ne 0 ]; then
        echo "Error: $1"
        exit 1
    fi
}

# Crear el directorio de NetBox si no existe
if [ ! -d "/opt/netbox" ]; then
    echo "Creando directorio /opt/netbox..."
    sudo mkdir -p /opt/netbox
fi

# Clonar el repositorio de NetBox si no existe
if [ ! -d "$NETBOX_DIR" ]; then
    echo "Clonando el repositorio de NetBox..."
    git clone https://github.com/netbox-community/netbox.git "$NETBOX_DIR"
    check_command "No se pudo clonar el repositorio de NetBox."
fi

# Crear y activar el entorno virtual
if [ ! -d "$VENV_DIR" ]; then
    echo "Creando entorno virtual..."
    python3 -m venv "$VENV_DIR"
    check_command "No se pudo crear el entorno virtual."
fi

echo "Activando el entorno virtual..."
source "$VENV_DIR/bin/activate"

# Verificar si Django está instalado
if ! python -m django --version &>/dev/null; then
    echo "Django no está instalado. Instalando Django..."
    pip install django
    check_command "No se pudo instalar Django."
else
    echo "Django ya está instalado."
fi

# Instalar dependencias de NetBox
if [ -f "$NETBOX_DIR/requirements.txt" ]; then
    echo "Instalando dependencias de NetBox..."
    pip install -r "$NETBOX_DIR/requirements.txt"
    check_command "No se pudieron instalar las dependencias de NetBox."
else
    echo "Error: El archivo requirements.txt no se encuentra en $NETBOX_DIR."
    exit 1
fi

# Ejecutar la recopilación de archivos estáticos
echo "Ejecutando collectstatic..."
python "$NETBOX_DIR/manage.py" collectstatic --noinput
check_command "Error al ejecutar collectstatic."

# Verificar la existencia del archivo setmode.js
if [ -f "$STATIC_ROOT/js/setmode.js" ]; then
    echo "El archivo setmode.js existe en $STATIC_ROOT/js/setmode.js."
else
    echo "Error: El archivo setmode.js no se encuentra en $STATIC_ROOT/js/setmode.js."
    echo "Buscando en el directorio de origen..."
    if [ -f "$NETBOX_DIR/netbox/static/js/setmode.js" ]; then
        echo "Copiando setmode.js al directorio de archivos estáticos..."
        cp "$NETBOX_DIR/netbox/static/js/setmode.js" "$STATIC_ROOT/js/"
        check_command "No se pudo copiar setmode.js."
    else
        echo "Error: El archivo setmode.js no se encuentra en el directorio de origen."
        exit 1
    fi
fi

# Configurar permisos para el directorio de archivos estáticos
echo "Configurando permisos para el directorio de archivos estáticos..."
sudo chown -R $SERVER_USER:$SERVER_USER "$STATIC_ROOT/"
sudo chmod -R 755 "$STATIC_ROOT/"
check_command "Error al configurar permisos."

# Verificar la configuración del servidor web
echo "Por favor, asegúrate de que tu servidor web esté configurado para servir archivos estáticos desde $STATIC_ROOT."
echo "Ejemplo de configuración para Nginx:"
echo "location /static/ {"
echo "    alias $STATIC_ROOT;"
echo "}"

# Reiniciar el servidor web
echo "Reiniciando el servidor web..."
sudo systemctl restart nginx  # Cambia esto a apache2 si usas Apache
check_command "Error al reiniciar el servidor web."

echo "Configuración completada. Por favor, verifica los registros del servidor si encuentras problemas."
