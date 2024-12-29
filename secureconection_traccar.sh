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

# Función para manejar errores
handle_error() {
    echo "Ocurrió un error en la operación: $1"
    echo "Verificando el estado del servicio..."
    systemctl status "$1" || echo "No se pudo obtener el estado del servicio $1."
    exit 1
}

# Verificar si el servicio de Traccar está en ejecución y detenerlo
if systemctl is-active --quiet traccar; then
    echo "Deteniendo el servicio Traccar..."
    if ! sudo systemctl stop traccar; then
        handle_error "traccar"
    fi
fi

# Verificar si el servicio de Apache está en ejecución y detenerlo
if systemctl is-active --quiet apache2; then
    echo "Deteniendo el servicio Apache..."
    if ! sudo systemctl stop apache2; then
        handle_error "apache2"
    fi
fi

# Agregar la configuración de Traccar al archivo de configuración existente
echo "$TRACCAR_VHOST" > $VHOST_CONF

# Habilitar los módulos necesarios
if ! sudo a2enmod proxy; then handle_error "a2enmod proxy"; fi
if ! sudo a2enmod proxy_http; then handle_error "a2enmod proxy_http"; fi
if ! sudo a2enmod proxy_wstunnel; then handle_error "a2enmod proxy_wstunnel"; fi
if ! sudo a2enmod ssl; then handle_error "a2enmod ssl"; fi

# Reiniciar Apache para aplicar cambios
if ! sudo systemctl restart apache2; then
    handle_error "apache2"
fi

# Asegurar que el script sea ejecutable
chmod +x secureconection_traccar.sh

# Ejecutar el script
if ! sudo ./secureconection_traccar.sh; then
    handle_error "secureconection_traccar.sh"
fi

# Reiniciar el servicio de Traccar
echo "Reiniciando el servicio Traccar..."
if ! sudo systemctl start traccar; then
    handle_error "traccar"
fi

echo "Configuración de Traccar agregada, Apache reiniciado y script de conexión seguro ejecutado."
