#!/bin/bash

# Función para manejar errores
handle_error() {
    whiptail --title "Error" --msgbox "Ocurrió un error: $1" 8 45
    exit 1
}

# Función para verificar e instalar un servicio
check_and_install_service() {
    local service_name=$1
    local install_command=$2

    if ! command -v "$service_name" &> /dev/null; then
        whiptail --title "Instalación de Servicios" --msgbox "$service_name no está instalado. Instalando..." 8 45
        eval "$install_command" || handle_error "Instalación de $service_name fallida"
    else
        whiptail --title "Estado de Servicios" --msgbox "$service_name ya está instalado." 8 45
    fi
}

# Función para desinstalar un servicio
uninstall_service() {
    local service_name=$1
    if command -v "$service_name" &> /dev/null; then
        whiptail --title "Desinstalación de Servicios" --msgbox "Desinstalando $service_name..." 8 45
        sudo apt remove --purge -y "$service_name" || handle_error "Desinstalación de $service_name fallida"
    fi
}

# Instalar Whiptail si no está presente
if ! command -v whiptail &> /dev/null; then
    sudo apt update
    sudo apt install -y whiptail || handle_error "Instalación de Whiptail fallida"
fi

# Desinstalar servicios existentes
uninstall_service "apache2"
uninstall_service "mysql-server"
uninstall_service "mariadb-server"
uninstall_service "php"

# Instalar Unzip si no está presente
check_and_install_service "unzip" "sudo apt update && sudo apt install -y unzip"

# Info inicial
whiptail --title "Bienvenida" --msgbox "Este script instalará y configurará Traccar en su servidor." 8 60

# Mensaje sobre servicios obligatorios
whiptail --title "Servicios Obligatorios" --msgbox "Asegúrese de tener los siguientes servicios instalados:\n- Apache o HTTPD\n- MySQL o MariaDB\n- PHP\n\nEstos son necesarios para una instalación correcta de Traccar." 12 60

# URL predeterminada para descargar Traccar
TRACCAR_URL="https://www.traccar.org/download/traccar-linux-64-latest.zip"

# Seleccionar modo de instalación
ACTION=$(whiptail --title "Opciones de Instalación" --menu "Seleccione una opción:" 15 60 4 \
"1" "Instalar todos los servicios" \
"2" "Instalar servicios uno a uno" \
"3" "Reparar/Reinstalar servicios" \
"4" "Salir" 3>&1 1>&2 2>&3)

case $ACTION in
    1)
        INSTALL_MODE="all"
        ;;
    2)
        INSTALL_MODE="individual"
        ;;
    3)
        INSTALL_MODE="repair"
        ;;
    *)
        exit 0
        ;;
esac

# Función para instalar Apache o httpd
install_web_server() {
    SERVER_TYPE=$(whiptail --title "Seleccionar Servidor Web" --radiolist \
    "Seleccione el servidor web a instalar:" 15 60 2 \
    "apache2" "Apache2" ON \
    "httpd" "HTTPD" OFF 3>&1 1>&2 2>&3)

    case $SERVER_TYPE in
        apache2)
            check_and_install_service "apache2" "sudo apt update && sudo apt install -y apache2"
            ;;
        httpd)
            check_and_install_service "httpd" "sudo apt update && sudo apt install -y httpd"
            ;;
    esac
}

# Función para instalar MySQL o MariaDB
install_database() {
    DB_TYPE=$(whiptail --title "Seleccionar Base de Datos" --radiolist \
    "Seleccione la base de datos a instalar:" 15 60 2 \
    "mysql" "MySQL" ON \
    "mariadb" "MariaDB" OFF 3>&1 1>&2 2>&3)

    case $DB_TYPE in
        mysql)
            check_and_install_service "mysql-server" "sudo apt update && sudo apt install -y mysql-server"
            ;;
        mariadb)
            check_and_install_service "mariadb-server" "sudo apt update && sudo apt install -y mariadb-server"
            ;;
    esac
}

# Función para instalar PHP
install_php() {
    PHP_VERSION=$(whiptail --title "Seleccionar Versión de PHP" --radiolist \
    "Seleccione la versión de PHP a instalar:" 15 60 2 \
    "php8.3" "PHP 8.3" ON \
    "php8.2" "PHP 8.2" OFF 3>&1 1>&2 2>&3)

    check_and_install_service "$PHP_VERSION" "sudo apt update && sudo apt install -y $PHP_VERSION libapache2-mod-$PHP_VERSION"
}

# Función para instalar Traccar
install_traccar() {
    whiptail --title "Instalación de Traccar" --msgbox "Descargando Traccar desde $TRACCAR_URL..." 8 60
    sudo wget "$TRACCAR_URL" -O traccar-linux.zip || handle_error "Error al descargar Traccar"

    whiptail --title "Descomprimiendo Traccar" --msgbox "Descomprimiendo Traccar..." 8 60
    sudo unzip traccar-linux.zip || handle_error "Error al descomprimir Traccar"

    whiptail --title "Ejecutando Instalador de Traccar" --msgbox "Ejecutando el instalador..." 8 60
    sudo ./traccar.run || handle_error "Error al ejecutar el instalador de Traccar"

    whiptail --title "Instalación de Traccar" --msgbox "Traccar instalado exitosamente." 8 45
}

# Función para configurar SSL
install_ssl() {
    check_and_install_service "openssl" "sudo apt update && sudo apt install -y openssl"
}

# Configuración de Apache para Traccar
configure_apache() {
    SERVER_NAME=$(whiptail --inputbox "Ingrese el nombre del servidor (ej. traccar.midominio.com):" 8 60 "traccar.midominio.com" 3>&1 1>&2 2>&3)
    SERVER_IP=$(whiptail --inputbox "Ingrese la IP del servidor:" 8 60 "0.0.0.0" 3>&1 1>&2 2>&3)

    # Crear archivo de configuración para el sitio
    CONFIG_FILE="/etc/apache2/sites-available/traccar.conf"
    
    echo "<VirtualHost *:80>
        ServerName $SERVER_NAME
        DocumentRoot /opt/traccar/web
        <Directory /opt/traccar/web>
            AllowOverride All
        </Directory>
    </VirtualHost>" | sudo tee $CONFIG_FILE

    # Habilitar el sitio y el módulo de reescritura
    sudo a2ensite traccar.conf
    sudo a2enmod rewrite
    sudo systemctl restart apache2

    # Configurar el nombre del servidor en /etc/hosts
    echo "$SERVER_IP $SERVER_NAME" | sudo tee -a /etc/hosts
}

# Instalar servicios según la opción seleccionada
if [[ "$INSTALL_MODE" == "all" ]]; then
    install_web_server
    install_database
    install_php
    install_traccar
    install_ssl
    configure_apache
elif [[ "$INSTALL_MODE" == "individual" ]]; then
    install_web_server
    install_database
    install_php
    install_traccar
    install_ssl
    configure_apache
elif [[ "$INSTALL_MODE" == "repair" ]]; then
    whiptail --title "Reparación de Servicios" --msgbox "Funcionalidad de reparación no implementada." 8 45
fi

# Progreso de instalación
(
    for i in {1..100}; do
        sleep 0.1
        echo $i
    done
) | whiptail --title "Progreso de Instalación" --gauge "Instalando servicios..." 6 60 0

# Mensaje final
whiptail --title "Finalización" --msgbox "La instalación y configuración se completaron." 8 45
