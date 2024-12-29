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

    if ! systemctl is-active --quiet "$service_name"; then
        whiptail --title "Instalación de Servicios" --msgbox "$service_name no está activo. Instalando..." 8 45
        eval "$install_command" || handle_error "Instalación de $service_name fallida"
    else
        whiptail --title "Estado de Servicios" --msgbox "$service_name ya está activo." 8 45
    fi
}

# Instalar Whiptail si no está presente
if ! command -v whiptail &> /dev/null; then
    sudo apt update
    sudo apt install -y whiptail || handle_error "Instalación de Whiptail fallida"
fi

# Info inicial
whiptail --title "Bienvenida" --msgbox "Este script instalará y configurará Traccar en su servidor." 8 60

# Preguntar al usuario la URL del repositorio de Traccar
TRACCAR_REPO=$(whiptail --title "URL del Repositorio" --inputbox "Ingrese la URL del repositorio de Traccar:" 10 60 "http://repositorio.traccar.org" 3>&1 1>&2 2>&3)

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
            check_and_install_service "mysql" "sudo apt update && sudo apt install -y mysql-server"
            ;;
        mariadb)
            check_and_install_service "mariadb" "sudo apt update && sudo apt install -y mariadb-server"
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
    if whiptail --title "Instalación de Traccar" --yesno "¿Desea instalar Traccar desde $TRACCAR_REPO?" 8 60; then
        check_and_install_service "traccar" "sudo apt update && sudo apt install -y traccar"
    else
        whiptail --title "Instalación de Traccar" --msgbox "Instalación de Traccar cancelada." 8 45
    fi
}

# Función para configurar SSL
install_ssl() {
    check_and_install_service "ssl" "sudo apt update && sudo apt install -y openssl"
}

# Instalar servicios según la opción seleccionada
if [[ "$INSTALL_MODE" == "all" ]]; then
    install_web_server
    install_database
    install_php
    install_traccar
    install_ssl
elif [[ "$INSTALL_MODE" == "individual" ]]; then
    install_web_server
    install_database
    install_php
    install_traccar
    install_ssl
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
