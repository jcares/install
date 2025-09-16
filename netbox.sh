#!/bin/bash

# Script para instalar NetBox con correcciones automáticas

# Función para leer parámetros
read_params() {
    echo "Configurando la base de datos..."
    read -p "Nombre de la base de datos: " DB_NAME
    read -p "Usuario de la base de datos: " DB_USER
    read -sp "Contraseña de la base de datos: " DB_PASS
    echo
}

# Función para verificar si un servicio está corriendo
check_service() {
    SERVICE_NAME=$1
    if systemctl is-active --quiet $SERVICE_NAME; then
        echo "$SERVICE_NAME ya está corriendo."
    else
        echo "$SERVICE_NAME no está corriendo. Iniciándolo..."
        sudo systemctl start $SERVICE_NAME
    fi
}

# Instalación de dependencias
install_dependencies() {
    echo "Instalando dependencias..."
    sudo apt update
    sudo apt install -y python3 python3-pip python3-venv git libpq-dev postgresql postgresql-contrib

    # Verificar si PostgreSQL está corriendo
    check_service postgresql
}

# Configuración de la base de datos
setup_database() {
    echo "Configurando la base de datos..."
    if sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
        echo "La base de datos $DB_NAME ya existe. Procediendo a usarla."
    else
        sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;"
        echo "Base de datos $DB_NAME creada."
    fi

    if sudo -u postgres psql -c "\du" | grep -qw "$DB_USER"; then
        echo "El usuario $DB_USER ya existe. Procediendo a usarlo."
    else
        sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';"
        echo "Usuario $DB_USER creado."
    fi

    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"
}

# Instalación de NetBox
install_netbox() {
    echo "Clonando NetBox..."
    if [ -d "/opt/netbox" ]; then
        echo "NetBox ya está instalado en /opt/netbox. Actualizando..."
        cd /opt/netbox
        git pull origin master
    else
        git clone -b master https://github.com/netbox-community/netbox.git /opt/netbox
        cd /opt/netbox
    fi

    echo "Creando entorno virtual..."
    python3 -m venv venv
    source venv/bin/activate
    pip install -r requirements.txt
}

# Configuración de NetBox
configure_netbox() {
    echo "Configurando NetBox..."
    cp netbox/netbox/configuration.example.py netbox/netbox/configuration.py
    sed -i "s/'NAME': 'netbox'/\'NAME\': '$DB_NAME'/" netbox/netbox/configuration.py
    sed -i "s/'USER': 'netbox'/\'USER\': '$DB_USER'/" netbox/netbox/configuration.py
    sed -i "s/'PASSWORD': ''/\'PASSWORD\': '$DB_PASS'/" netbox/netbox/configuration.py

    # Configuración para permitir acceso externo
    sed -i "s/ALLOWED_HOSTS = \[\]/ALLOWED_HOSTS = ['*']/" netbox/netbox/configuration.py
}

# Iniciar NetBox
start_netbox() {
    echo "Iniciando NetBox..."
    cd /opt/netbox/netbox
    python3 manage.py migrate
    python3 manage.py createsuperuser --noinput --username admin --email admin@example.com
    echo "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.filter(username='admin').update(is_superuser=True, is_staff=True)" | python3 manage.py shell
    python3 manage.py runserver 0.0.0.0:8000 &
}

# Ejecución del script
read_params
install_dependencies
setup_database
install_netbox
configure_netbox
start_netbox

echo "NetBox se ha instalado y está en ejecución en http://localhost:8000"
