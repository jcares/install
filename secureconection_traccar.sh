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

# Función para verificar e instalar un servicio
check_and_install_service() {
    local service_name=$1
    local install_command=$2

    if ! systemctl is-active --quiet "$service_name"; then
        echo "$service_name no está activo. Instalando..."
        eval "$install_command" || handle_error "Instalación de $service_name fallida"
    else
        echo "$service_name ya está activo."
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

# Habilitar el módulo mod_status
enable_mod_status() {
    echo "Habilitando el módulo mod_status..."
    sudo a2enmod status || handle_error "Error al habilitar mod_status"
    echo "Módulo mod_status habilitado."
    echo "Configurando el archivo de estado..."
    sudo nano /etc/apache2/mods-enabled/status.conf
}

# Comenzar el proceso
update_hosts_file
update_hostname_file

# Verificar e instalar servicios
check_and_install_service "apache2" "sudo apt update && sudo apt install -y apache2"
check_and_install_service "mysql" "sudo apt update && sudo apt install -y mysql-server"
check_and_install_service "php8.3" "sudo apt update && sudo apt install -y php8.3 libapache2-mod-php8.3"
check_and_install_service "php8.2" "sudo apt update && sudo apt install -y php8.2 libapache2-mod-php8.2"
check_and_install_service "traccar" "sudo apt update && sudo apt install -y traccar"
check_and_install_service "ssl" "sudo apt update && sudo apt install -y openssl"

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

# Comprobar la configuración de Apache y reiniciar
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

# Habilitar mod_status
enable_mod_status

echo "Configuración de Traccar completada y servicios reiniciados."
