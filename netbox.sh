#!/bin/bash

# Script para instalar NetBox en Ubuntu 24

# Función para solicitar datos de configuración
function solicitar_datos() {
    read -p "Ingrese la dirección de la base de datos (ej. localhost): " DB_HOST
    read -p "Ingrese el nombre de la base de datos (ej. netbox): " DB_NAME
    read -p "Ingrese el usuario de la base de datos: " DB_USER
    read -sp "Ingrese la contraseña de la base de datos: " DB_PASSWORD
    echo
    read -p "Ingrese el nombre de dominio para NetBox (ej. netbox.example.com): " DOMAIN_NAME
}

# Función para instalar dependencias
function instalar_dependencias() {
    sudo apt update
    sudo apt install -y python3 python3-pip python3-venv git postgresql postgresql-contrib libpq-dev redis-server nginx
}

# Función para configurar PostgreSQL
function configurar_postgresql() {
    sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;"
    sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';"
    sudo -u postgres psql -c "ALTER ROLE $DB_USER SET client_encoding TO 'utf8';"
    sudo -u postgres psql -c "ALTER ROLE $DB_USER SET default_transaction_isolation TO 'read committed';"
    sudo -u postgres psql -c "ALTER ROLE $DB_USER SET timezone TO 'UTC';"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"
}

# Función para instalar NetBox
function instalar_netbox() {
    sudo mkdir /opt/netbox
    sudo git clone -b master https://github.com/netbox-community/netbox.git /opt/netbox
    cd /opt/netbox
    sudo pip3 install -r requirements.txt
}

# Función para configurar NetBox
function configurar_netbox() {
    sudo cp /opt/netbox/netbox/netbox/configuration.example.py /opt/netbox/netbox/netbox/configuration.py
    sudo sed -i "s/'NAME': 'netbox'/'NAME': '$DB_NAME'/g" /opt/netbox/netbox/netbox/configuration.py
    sudo sed -i "s/'USER': 'netbox'/'USER': '$DB_USER'/g" /opt/netbox/netbox/netbox/configuration.py
    sudo sed -i "s/# 'PASSWORD': ''/'PASSWORD': '$DB_PASSWORD'/g" /opt/netbox/netbox/netbox/configuration.py
    sudo sed -i "s/'HOST': 'localhost'/'HOST': '$DB_HOST'/g" /opt/netbox/netbox/netbox/configuration.py
    sudo sed -i "s/# 'ALLOWED_HOSTS': \[\]/'ALLOWED_HOSTS': ['$DOMAIN_NAME']/g" /opt/netbox/netbox/netbox/configuration.py
}

# Función para inicializar la base de datos
function inicializar_bd() {
    cd /opt/netbox/netbox
    sudo python3 manage.py migrate
    sudo python3 manage.py createsuperuser
    sudo python3 manage.py collectstatic --no-input
}

# Función para configurar Nginx
function configurar_nginx() {
    sudo bash -c "cat > /etc/nginx/sites-available/netbox <<EOF
server {
    listen 80;
    server_name $DOMAIN_NAME;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF"

    sudo ln -s /etc/nginx/sites-available/netbox /etc/nginx/sites-enabled/
    sudo nginx -t
    sudo systemctl restart nginx
}

# Función para iniciar el servidor Gunicorn
function iniciar_gunicorn() {
    sudo bash -c "cat > /etc/systemd/system/netbox.service <<EOF
[Unit]
Description=NetBox WSGI service
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=/opt/netbox/netbox
ExecStart=/usr/bin/gunicorn --workers 3 --bind unix:/opt/netbox/netbox.sock netbox.wsgi:application

[Install]
WantedBy=multi-user.target
EOF"

    sudo systemctl start netbox
    sudo systemctl enable netbox
}

# Ejecución del script
solicitar_datos
instalar_dependencias
configurar_postgresql
instalar_netbox
configurar_netbox
inicializar_bd
configurar_nginx
iniciar_gunicorn

echo "NetBox ha sido instalado y configurado correctamente."
