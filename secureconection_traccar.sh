#!/bin/bash

# Variables
VHOST_CONF="/etc/apache2/sites-available/srv2.gpsafechile.cl.conf"
HOSTS_FILE="/etc/hosts"
HOSTNAME_FILE="/etc/hostname"
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

# Validar y modificar /etc/hosts
update_hosts_file() {
    if ! grep -q "srv2.gpsafechile.cl" "$HOSTS_FILE"; then
        echo "Agregando srv2.gpsafechile.cl al archivo /etc/hosts..."
        echo "127.0.0.1 srv2.gpsafechile.cl" | sudo tee -a "$HOSTS_FILE"
        echo "Entrada agregada."
    else
        echo "La entrada srv2.gpsafechile.cl ya existe en /etc/hosts."
    fi
}

# Validar y modificar /etc/hostname
update_hostname_file() {
    current_hostname=$(cat "$HOSTNAME_FILE")
    if [ "$current_hostname" != "srv2.gpsafechile.cl" ]; then
        echo "Cambiando el hostname a srv2.gpsafechile.cl..."
        echo "srv2.gpsafechile.cl" | sudo tee "$HOSTNAME_FILE"
        echo "Hostname actualizado."
    else
        echo "El hostname ya es srv2.gpsafechile.cl."
    fi
}

# Verificar la configuración de Apache
check_apache_config() {
    echo "Verificando la configuración de Apache..."
    if ! sudo apachectl configtest; then
        handle_error "Error en la configuración de Apache"
    fi
    echo "Configuración de Apache válida."
}

# Revisar los archivos de registro de Apache
check_apache_logs() {
    echo "Revisando los registros de error de Apache..."
    sudo tail -n 50 /var/log/apache2/error.log
}

# Verificar puertos en uso
check_ports_in_use() {
    echo "Verificando puertos en uso..."
    sudo netstat -tuln | grep ':80\|:443'
}

# Verificar el estado del servicio y su fuente
check_service_status() {
    echo "Verificando el estado del servicio Apache..."
    systemctl status apache2
    echo "Fuente de carga del servicio:"
    systemctl show -p FragmentPath apache2.service
}

# Crear directorios necesarios y asignar permisos
create_directories_and_permissions() {
    echo "Creando directorios necesarios..."
    sudo mkdir -p /var/www/srv2.gpsafechile.cl
    sudo chmod 755 /var/www/srv2.gpsafechile.cl
    echo "Directorios creados y permisos asignados."
}

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

# Actualizar archivos de hosts y hostname
update_hosts_file
update_hostname_file

# Verificar la configuración de Apache
check_apache_config

# Revisar los registros de Apache
check_apache_logs

# Verificar puertos en uso
check_ports_in_use

# Verificar el estado del servicio y su fuente
check_service_status

# Crear directorios necesarios y asignar permisos
create_directories_and_permissions

# Agregar la configuración de Traccar al archivo de configuración existente
echo "Agregando la configuración de Traccar al archivo de configuración..."
echo "$TRACCAR_VHOST" | sudo tee "$VHOST_CONF" > /dev/null
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
if ! sudo systemctl start apache2; then
    echo "Error al iniciar Apache. Revisando el estado..."
    systemctl status apache2
    echo "Intentando reiniciar Apache nuevamente después de un breve descanso..."
    sleep 5
    if ! sudo systemctl start apache2; then
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

echo "Configuración de Traccar completada y servicios reiniciados."
