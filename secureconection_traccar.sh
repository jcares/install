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

# Detener el servicio de Traccar
if systemctl is-active --quiet traccar; then
    echo "Deteniendo el servicio Traccar..."
    if ! sudo systemctl stop traccar; then
        handle_error "traccar"
    fi
    echo "Servicio Traccar detenido."
    sleep 2
else
    echo "El servicio Traccar no estaba activo."
    sleep 2
fi

# Detener el servicio de Apache
if systemctl is-active --quiet apache2; then
    echo "Deteniendo el servicio Apache..."
    if ! sudo systemctl stop apache2; then
        handle_error "apache2"
    fi
    echo "Servicio Apache detenido."
    sleep 2
else
    echo "El servicio Apache no estaba activo."
    sleep 2
fi

# Agregar la configuración de Traccar al archivo de configuración existente
echo "Agregando la configuración de Traccar al archivo de configuración..."
echo "$TRACCAR_VHOST" > $VHOST_CONF
echo "Configuración de Traccar agregada."
sleep 2

# Habilitar los módulos necesarios
echo "Habilitando módulos necesarios..."
if ! sudo a2enmod proxy; then handle_error "a2enmod proxy"; fi
if ! sudo a2enmod proxy_http; then handle_error "a2enmod proxy_http"; fi
if ! sudo a2enmod proxy_wstunnel; then handle_error "a2enmod proxy_wstunnel"; fi
if ! sudo a2enmod ssl; then handle_error "a2enmod ssl"; fi
echo "Módulos habilitados."
sleep 2

# Reiniciar Apache para aplicar cambios
echo "Reiniciando Apache para aplicar cambios..."
if ! sudo systemctl restart apache2; then
    echo "Error al reiniciar Apache. Revisando el estado..."
    systemctl status apache2
    echo "Intentando reiniciar Apache nuevamente después de un breve descanso..."
    sleep 5
    if ! sudo systemctl restart apache2; then
        echo "El reinicio de Apache falló nuevamente. Verifica la configuración y el estado del servicio."
        exit 1
    fi
fi
echo "Apache reiniciado."
sleep 2

# Ejecutar el script secureconection_traccar.sh
echo "Ejecutando el script de conexión seguro..."
if ! sudo ./secureconection_traccar.sh; then
    handle_error "secureconection_traccar.sh"
fi
echo "Script de conexión seguro ejecutado."
sleep 2

# Reiniciar el servicio de Traccar
echo "Reiniciando el servicio Traccar..."
if ! sudo systemctl start traccar; then
    handle_error "traccar"
fi
echo "Servicio Traccar reiniciado."
sleep 2

# Reiniciar el servicio de Apache
echo "Reiniciando el servicio Apache..."
if ! sudo systemctl start apache2; then
    handle_error "apache2"
fi
echo "Servicio Apache reiniciado."
sleep 2

echo "Configuración de Traccar completada, servicios reiniciados y script de conexión seguro ejecutado."
