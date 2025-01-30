#!/bin/bash

# Variables
DOMAIN="clientes.gpsafechile.cl"
GPSafe_PORT="8082"
GPS_PORTS="5001-5256"
MYSQL_ROOT_PASSWORD="Jc158113058@@"  # Cambia esto por una contraseña segura
MYSQL_GPSAFECHILE_PASSWORD="Jc158113058@@"  # Cambia esto por una contraseña segura
ADMIN_EMAIL="admin@$DOMAIN"

# Función para mostrar mensajes de error y salir
function error_exit {
  echo "$1"
  exit 1
}

# Verificar si el usuario es root
if [ "$EUID" -ne 0 ]; then
  error_exit "Por favor, ejecuta este script como root."
fi

# Actualizar el sistema
echo "Actualizando el sistema..."
apt-get update -y && apt-get upgrade -y || error_exit "Error al actualizar el sistema."

# Instalar dependencias
echo "Instalando dependencias..."
apt-get install -y apache2 mysql-server phpmyadmin certbot python3-certbot-apache wget unzip || error_exit "Error al instalar dependencias."

# Configurar MySQL
echo "Configurando MySQL..."
mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASSWORD';" || error_exit "Error al configurar la contraseña de root de MySQL."
mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "CREATE DATABASE gpsafechile;" || error_exit "Error al crear la base de datos."
mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "CREATE USER 'gpsafe'@'localhost' IDENTIFIED BY '$MYSQL_TRACCAR_PASSWORD';" || error_exit "Error al crear el usuario de Traccar."
mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "GRANT ALL PRIVILEGES ON gpsafechile.* TO 'gpsafe'@'localhost';" || error_exit "Error al otorgar privilegios."
mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "FLUSH PRIVILEGES;" || error_exit "Error al actualizar privilegios."

# Descargar e instalar GPSafe Server
echo "Instalando GPSafe Server..."
wget -O /tmp/traccar.zip https://www.traccar.org/download/traccar-linux-64-latest.zip || error_exit "Error al descargar GPSafe."
unzip /tmp/traccar.zip -d /opt/traccar || error_exit "Error al descomprimir GPSafe."
chmod +x /opt/traccar/bin/*.sh

# Configurar GPSafe
echo "Configurando GPSafe..."
cat <<EOL > /opt/traccar/conf/traccar.xml
<?xml version='1.0' encoding='UTF-8'?>
<!DOCTYPE properties SYSTEM 'http://java.sun.com/dtd/properties.dtd'>
<properties>
    <entry key="config.default">./conf/traccar.xml</entry>
    <entry key="web.port">$TRACCAR_PORT</entry>
    <entry key="database.driver">com.mysql.cj.jdbc.Driver</entry>
    <entry key="database.url">jdbc:mysql://localhost/gpsafechile?useSSL=false&amp;allowPublicKeyRetrieval=true&amp;serverTimezone=UTC</entry>
    <entry key="database.user">gpsafe</entry>
    <entry key="database.password">$MYSQL_TRACCAR_PASSWORD</entry>
</properties>
EOL

# Configurar puertos GPS
echo "Configurando puertos GPS..."
ufw allow $GPSafe_PORT/tcp
ufw allow $GPS_PORTS/tcp
ufw allow $GPS_PORTS/udp

# Configurar Apache como proxy inverso para GPSafe
echo "Configurando Apache..."
cat <<EOL > /etc/apache2/sites-available/gpsafe.conf
<VirtualHost *:80>
    ServerName $DOMAIN
    Redirect permanent / https://$DOMAIN/
</VirtualHost>

<VirtualHost *:443>
    ServerName $DOMAIN
    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/$DOMAIN/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/$DOMAIN/privkey.pem

    ProxyPreserveHost On
    ProxyPass / http://localhost:$GPSafe_PORT/
    ProxyPassReverse / http://localhost:$GPSafe_PORT/
</VirtualHost>
EOL

a2ensite gpsafe.conf
a2enmod proxy proxy_http ssl
systemctl restart apache2 || error_exit "Error al reiniciar Apache."

# Obtener certificado SSL con Let's Encrypt
echo "Configurando SSL..."
certbot --apache --non-interactive --agree-tos --email "$ADMIN_EMAIL" --domains "$DOMAIN" || error_exit "Error al obtener el certificado SSL."

# Iniciar GPSafe Server
echo "Iniciando GPSafe Server..."
/opt/traccar/bin/startDaemon.sh || error_exit "Error al iniciar GPSafe Server."

# Mensaje final
echo "Instalación completada. Puedes acceder a GPSafe en https://$DOMAIN"

exit 0
