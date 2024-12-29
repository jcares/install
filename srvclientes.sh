#!/bin/bash

# Variables
VHOST_CONF="/etc/apache2/sites-available/clientes.gpsafechile.cl.conf"
HOSTS_FILE="/etc/hosts"
HOSTNAME_FILE="/etc/hostname"
SERVER_NAME=$(whiptail --inputbox "Ingrese el nombre del servidor (ej. clientes.gpsafechile.cl):" 8 60 "clientes.gpsafechile.cl" --title "Configuración de Servidor" 3>&1 1>&2 2>&3)

TRACCAR_VHOST="
<VirtualHost *:80>
    ServerName $SERVER_NAME
    Redirect / https://$SERVER_NAME/
</VirtualHost>

<IfModule mod_ssl.c>
    <VirtualHost _default_:443>
        ServerName $SERVER_NAME
        ServerAdmin webmaster@localhost

        DocumentRoot /var/www/$SERVER_NAME

        ProxyPass /api/socket ws://localhost:8082/api/socket
        ProxyPassReverse /api/socket ws://localhost:8082/api/socket

        ProxyPass / http://localhost:8082/
        ProxyPassReverse / http://localhost:8082/

        SSLEngine on
        SSLCertificateFile /etc/ca-certificates/update.d/clientes.crt
        SSLCertificateKeyFile /etc/ca-certificates/update.d/clientes.key
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
    if ! grep -q "$SERVER_NAME" "$HOSTS_FILE"; then
        echo "Agregando $SERVER_NAME al archivo /etc/hosts..."
        echo "127.0.0.1 $SERVER_NAME" | sudo tee -a "$HOSTS_FILE"
        echo "Entrada agregada."
    else
        echo "La entrada $SERVER_NAME ya existe en /etc/hosts."
    fi
}

# Validar y modificar /etc/hostname
update_hostname_file() {
    current_hostname=$(cat "$HOSTNAME_FILE")
    if [ "$current_hostname" != "$SERVER_NAME" ]; then
        echo "Cambiando el hostname a $SERVER_NAME..."
        echo "$SERVER_NAME" | sudo tee "$HOSTNAME_FILE"
        echo "Hostname actualizado."
    else
        echo "El hostname ya es $SERVER_NAME."
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

# Crear directorios necesarios y asignar permisos
create_directories_and_permissions() {
    echo "Creando directorios necesarios..."
    sudo mkdir -p /var/www/$SERVER_NAME
    sudo chmod 755 /var/www/$SERVER_NAME
    echo "Directorios creados y permisos asignados."
}

# Habilitar el módulo mod_status
enable_mod_status() {
    echo "Habilitando el módulo mod_status..."
    sudo a2enmod status || handle_error "Error al habilitar mod_status"
    echo "Módulo mod_status habilitado."
}

# Comenzar el proceso
update_hosts_file
update_hostname_file

# Verificar e instalar servicios

check_and_install_service "apache2" "sudo apt update && sudo apt install -y apache2"
check_and_install_service "mysql" "sudo apt update && sudo apt install -y mysql-server"
sudo apt install curl gpg gnupg2 software-properties-common ca-certificates apt-transport-https lsb-release -y
&& add-apt-repository ppa:ondrej/php && apt update -uy
check_and_install_service "php8.3" "sudo apt update && sudo apt install -y php8.3 libapache2-mod-php8.3"
check_and_install_service "php8.2" "sudo apt update && sudo apt install -y php8.2 libapache2-mod-php8.2"
check_and_install_service "openssl" "sudo apt update && sudo apt install -y openssl"
check_and_install_service "gpsafe" "sudo apt update && sudo wget https://www.traccar.org/download/traccar-linux-64-latest.zip"
check_and_install_service "unzip" "sudo apt update && sudo apt install -y unzip"
check_and_install_service "sudo unzip traccar-linux-*.zip && ./traccar.run"


# Comprobar la configuración de Apache y reiniciar
check_apache_config
create_directories_and_permissions

# Agregar la configuración de Traccar al archivo de configuración existente
echo "Agregando la configuración de Traccar al archivo de configuración..."
echo "$TRACCAR_VHOST" | sudo tee "$VHOST_CONF" > /dev/null
echo "Configuración de Traccar agregada."

# Habilitar los módulos necesarios
echo "Habilitando módulos necesarios..."
sudo a2enmod proxy || handle_error "Error al habilitar proxy"
sudo a2enmod proxy_http || handle_error "Error al habilitar proxy_http"
sudo a2enmod proxy_wstunnel || handle_error "Error al habilitar proxy_wstunnel"
sudo a2enmod ssl || handle_error "Error al habilitar ssl"
echo "Módulos habilitados."

# Reiniciar Apache para aplicar cambios
echo "Reiniciando Apache para aplicar cambios..."
sudo systemctl restart apache2 || handle_error "Error al reiniciar Apache"
echo "Apache reiniciado."

# Habilitar mod_status
enable_mod_status

echo "Configuración de Traccar completada y servicios reiniciados."
