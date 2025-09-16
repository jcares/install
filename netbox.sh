#!/bin/bash

# Script para instalar NetBox

# Función para leer parámetros
read_params() {
    echo "Configurando la base de datos..."
    read -p "Nombre de la base de datos: " DB_NAME
    read -p "Usuario de la base de datos: " DB_USER
    read -sp "Contraseña de la base de datos: " DB_PASS
    echo
}

# Instalación de dependencias
install_dependencies() {
    echo "Instalando dependencias..."
    sudo apt update
    sudo apt install -y python3 python3-pip python3-venv git libpq-dev postgresql postgresql-contrib
}

# Configuración de la base de datos
setup_database() {
    sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;"
    sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';"
    sudo -u postgres psql -c "ALTER ROLE $DB_USER SET client_encoding TO 'utf8';"
    sudo -u postgres psql -c "ALTER ROLE $DB_USER SET default_transaction_isolation TO 'read committed';"
    sudo -u postgres psql -c "ALTER ROLE $DB_USER SET timezone TO 'UTC';"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"
}

# Instalación de NetBox
install_netbox() {
    echo "Clonando NetBox..."
    git clone -b master https://github.com/netbox-community/netbox.git /opt/netbox
    cd /opt/netbox
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
}

# Iniciar NetBox
start_netbox() {
    echo "Iniciando NetBox..."
    cd /opt/netbox/netbox
    python3 manage.py migrate
    python3 manage.py createsuperuser
    python3 manage.py runserver 0.0.0.0:8000
}

# Ejecución del script
read_params
install_dependencies
setup_database
install_netbox
configure_netbox
start_netbox

echo "NetBox se ha instalado y está en ejecución en http://localhost:8000"
