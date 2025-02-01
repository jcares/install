#!/bin/bash

# Variables
DOMAIN="gpsafechile.cl"
DB_NAME="gpsafe2025"
DB_USER="gpsafe"
DB_PASSWORD="Jc158113058@@"  # Cambia esto por una contraseña segura
TRACCAR_VERSION="3.17"  # Cambia esto a la versión más reciente si es necesario

# Actualizar el sistema
sudo apt-get update
sudo apt-get upgrade -y

# Instalar Java (requerido por Traccar)
sudo apt-get install -y openjdk-11-jre-headless

# Instalar PostgreSQL
sudo apt-get install -y postgresql postgresql-contrib

# Configurar la base de datos
sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;"
sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"

# Descargar Traccar
wget https://github.com/traccar/traccar/releases/download/v$TRACCAR_VERSION/traccar-linux-64-$TRACCAR_VERSION.zip -O /tmp/traccar.zip

# Instalar Traccar
sudo mkdir -p /opt/traccar
sudo unzip -q /tmp/traccar.zip -d /opt/traccar

# Configurar Traccar
sudo bash /opt/traccar/bin/configure.sh

# Configurar el archivo de configuración de Traccar
sudo sed -i "s|<entry key='database.driver'>.*</entry>|<entry key='database.driver'>org.postgresql.Driver</entry>|" /opt/traccar/conf/traccar.xml
sudo sed -i "s|<entry key='database.url'>.*</entry>|<entry key='database.url'>jdbc:postgresql://localhost:5432/$DB_NAME</entry>|" /opt/traccar/conf/traccar.xml
sudo sed -i "s|<entry key='database.user'>.*</entry>|<entry key='database.user'>$DB_USER</entry>|" /opt/traccar/conf/traccar.xml
sudo sed -i "s|<entry key='database.password'>.*</entry>|<entry key='database.password'>$DB_PASSWORD</entry>|" /opt/traccar/conf/traccar.xml

# Configurar el servicio de Traccar
sudo bash /opt/traccar/bin/installDaemon.sh

# Iniciar el servicio de Traccar
sudo systemctl start traccar
sudo systemctl enable traccar

# Instalar Nginx como proxy inverso
sudo apt-get install -y nginx

# Configurar Nginx para el dominio gpsafechile.cl
sudo bash -c 'cat > /etc/nginx/sites-available/traccar <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://localhost:8082;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF'

# Habilitar el sitio de Nginx
sudo ln -s /etc/nginx/sites-available/traccar /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx

# Configurar el firewall
sudo ufw allow 80/tcp
sudo ufw allow 22/tcp
sudo ufw enable

# Mensaje final
echo "Instalación completada."
echo "Accede a Traccar en http://$DOMAIN"
echo "Usuario por defecto: admin"
echo "Contraseña por defecto: admin"
