#!/bin/bash

# Variables
VHOST_CONF="/etc/apache2/sites-available/srv2.gpsafechile.cl.conf"
TRACCAR_VHOST="
<VirtualHost *:80>
    ServerName srv2.gpsafechile.cl
    Redirect / https://srv2.gpsafechile.cl/
</VirtualHost>

<IfModule mod_ssl.c>
    <VirtualHost _default_:443>
        ServerName srv2.gpsafechile.cl
        ServerAdmin webmaster@localhost

        DocumentRoot /var/www/srv2.gpsafechile.cl

        ProxyPass /api/socket ws://localhost:8082/api/socket
        ProxyPassReverse /api/socket ws://localhost:8082/api/socket

        ProxyPass / http://localhost:8082/
        ProxyPassReverse / http://localhost:8082/

        SSLEngine on
        SSLCertificateFile /etc/ca-certificates/update.d/srv2.crt
        SSLCertificateKeyFile /etc/ca-certificates/update.d/srv2.key
    </VirtualHost>
</IfModule>
"

# Agregar la configuración de Traccar al archivo de configuración existente
echo "$TRACCAR_VHOST" >> $VHOST_CONF

# Habilitar los módulos necesarios
a2enmod proxy
a2enmod proxy_http
a2enmod proxy_wstunnel
a2enmod ssl

# Reiniciar Apache para aplicar cambios
systemctl restart apache2

# Descargar y ejecutar el script secureconection_traccar.sh
wget -qLO secureconection_traccar.sh https://github.com/jcares/install/raw/refs/heads/master/secureconection_traccar.sh
chmod +x secureconection_traccar.sh
sudo ./secureconection_traccar.sh

echo "Configuración de Traccar agregada, Apache reiniciado y script de conexión seguro ejecutado."
