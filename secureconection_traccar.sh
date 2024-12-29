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
    echo "Ocurrió un error: $1"
    exit 1
}

# Verificar si Apache está instalado
check_apache_installed() {
    if ! command -v apache2 &> /dev/null; then
        echo "Apache no está instalado. Instalando Apache..."
        sudo apt update
        sudo apt install -y apache2 || handle_error "Instalación de Apache fallida"
    fi
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
    if ! sudo apache2ctl configtest; then
        handle_error "Error en la configuración de Apache"
    fi
    echo "Configuración de Apache válida."
}

# Revisar los archivos de registro de Apache
check_apache_logs() {
    echo "Revisando los registros de error de Apache..."
    sudo tail -n 50 /var/log/apache2/error.log
}

# Crear directorios necesarios y asignar permisos
create_directories_and_permissions() {
    echo "Creando directorios necesarios..."
    sudo mkdir -p /var/www/srv2.gpsafechile.cl
    sudo chmod 755 /var/www/srv2.gpsafechile.cl
    echo "Directorios creados y permisos asignados."
}

# Detener el servicio de Apache
stop_apache_service() {
    if systemctl is-active --quiet apache2; then
        echo "Deteniendo el servicio Apache..."
        sudo systemctl stop apache2 || handle_error "Detención de Apache fallida"
        echo "Servicio Apache detenido."
        sleep 2
    else
        echo "El servicio Apache no estaba activo."
        sleep 2
    fi
}

# Comenzar el proceso
update_hosts_file
update_hostname_file
check_apache_installed
stop_apache_service
check_apache_config
check_apache_logs
create_directories_and_permissions

# Agregar la configuración de Traccar al archivo de configuración existente
echo "Agregando la configuración de Traccar al archivo de configuración..."
echo "$TRACCAR_VHOST" | sudo tee "$VHOST_CONF" > /dev/null
echo "Configuración de Traccar agregada."
sleep 2

# Habilitar los módulos necesarios
echo "Habilitando módulos necesarios..."
sudo a2enmod proxy || handle_error "Error al habilitar proxy"
sudo a2enmod proxy_http || handle_error "Error al habilitar proxy_http"
sudo a2enmod proxy_wstunnel || handle_error "Error al habilitar proxy_wstunnel"
sudo a2enmod ssl || handle_error "Error al habilitar ssl"
echo "Módulos habilitados."
sleep 2

# Reiniciar Apache para aplicar cambios
echo "Reiniciando Apache para aplicar cambios..."
sudo systemctl start apache2 || handle_error "Error al iniciar Apache"
echo "Apache reiniciado."
sleep 2

# Ejecutar el script secureconection_traccar.sh
echo "Ejecutando el script de conexión seguro..."
if ! sudo bash -c "$(wget -qLO - https://github.com/jcares/install/raw/refs/heads/master/secureconection_traccar.sh)"; then
    handle_error "Ejecución del script de conexión seguro fallida"
fi
echo "Script de conexión seguro ejecutado."
sleep 2

# Reiniciar el servicio de Traccar
echo "Reiniciando el servicio Traccar..."
sudo systemctl restart traccar || handle_error "Error al reiniciar el servicio Traccar"
echo "Servicio Traccar reiniciado."
sleep 2

echo "Configuración de Traccar completada y servicios reiniciados."
