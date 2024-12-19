#!/bin/bash

# Función para mostrar mensajes de información
msg_info() {
    echo -e "\n\033[1;34mINFO:\033[0m $1"
}

# Función para mostrar mensajes de éxito
msg_ok() {
    echo -e "\n\033[1;32mSUCCESS:\033[0m $1"
}

# Función para mostrar mensajes de error
msg_error() {
    echo -e "\n\033[1;31mERROR:\033[0m $1"
}

# Función para instalar un paquete si no está instalado
install_if_missing() {
    PACKAGE_NAME=$1
    if ! dpkg -l | grep -q "^ii  $PACKAGE_NAME"; then
        msg_info "Instalando $PACKAGE_NAME..."
        sudo apt install -y $PACKAGE_NAME
        msg_ok "$PACKAGE_NAME ha sido instalado."
    else
        msg_ok "$PACKAGE_NAME ya está instalado."
    fi
}

# 1. Instalar dependencias obligatorias
msg_info "Instalando dependencias obligatorias..."
install_if_missing "figlet"
install_if_missing "whiptail"
install_if_missing "openjdk-11-jdk"
install_if_missing "mysql-client"
install_if_missing "ufw"

# 2. Verificar servicios
check_service() {
    SERVICE_NAME=$1
    if systemctl is-active --quiet $SERVICE_NAME; then
        msg_ok "$SERVICE_NAME está activo."
    else
        msg_error "$SERVICE_NAME no está activo."
    fi
}

# 3. Abrir menú de manejo de servicios
manage_services() {
    while true; do
        SERVICE_CHOICES=$(whiptail --checklist "Selecciona los servicios que deseas manejar:" 15 60 4 \
        "traccar" "Manejar Traccar" OFF \
        "apache2" "Manejar Apache" OFF \
        "mysql-server" "Manejar MySQL" OFF \
        "certbot" "Manejar Certbot" OFF 3>&1 1>&2 2>&3)

        # Comprobar si se canceló
        if [ $? -ne 0 ]; then
            msg_info "No se realizarán cambios."
            exit 0
        fi

        # Convertir la selección en un array
        IFS='|' read -r -a SELECTED_SERVICES <<< "$SERVICE_CHOICES"

        # Manejar cada servicio seleccionado
        for SERVICE in "${SELECTED_SERVICES[@]}"; do
            ACTION=$(whiptail --radiolist "¿Qué deseas hacer con $SERVICE?" 15 60 2 \
            "uninstall" "Desinstalar" ON \
            "install" "Instalar" OFF 3>&1 1>&2 2>&3)

            # Comprobar si se canceló
            if [ $? -ne 0 ]; then
                msg_info "No se realizarán cambios para $SERVICE."
                continue
            fi

            handle_service "$SERVICE" "$ACTION"
            msg_ok "Acción completada para $SERVICE."
        done
    done
}

# Función para desinstalar un servicio
uninstall_service() {
    SERVICE_NAME=$1
    msg_info "Desinstalando $SERVICE_NAME..."
    sudo apt purge -y $SERVICE_NAME
    msg_ok "$SERVICE_NAME ha sido desinstalado."
}

# Función para instalar servicios
install_services() {
    # 6. Instalar servicios seleccionados
    msg_info "Instalando servicios..."
    install_if_missing "traccar"
    install_if_missing "apache2"
    install_if_missing "mysql-server"
    install_if_missing "mysql-client"
    install_if_missing "mysql-secure"
}

# 7. Configurar firewall para los servicios
configure_firewall() {
    msg_info "Configurando el firewall..."
    sudo ufw allow 8082/tcp
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    for port in {5001..5256}; do
        sudo ufw allow $port/tcp
    done
    sudo ufw enable
    msg_ok "Firewall configurado."
}

# 8. Configurar instalación de Traccar
configure_traccar() {
    msg_info "Configurando Traccar..."
    DB_USER=$(whiptail --inputbox "Introduce el usuario de la base de datos:" 8 39 --title "Usuario de la Base de Datos" 3>&1 1>&2 2>&3)
    DB_PASSWORD=$(whiptail --passwordbox "Introduce la contraseña de la base de datos:" 8 39 --title "Contraseña de la Base de Datos" 3>&1 1>&2 2>&3)
    DB_NAME=$(whiptail --inputbox "Introduce el nombre de la base de datos:" 8 39 --title "Nombre de la Base de Datos" 3>&1 1>&2 2>&3)

    # Crear archivo traccar.xml
    cat <<EOL | sudo tee /opt/traccar/conf/traccar.xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE properties SYSTEM 'http://java.sun.com/dtd/properties.dtd'>
<properties>

    <entry key='database.driver'>com.mysql.cj.jdbc.Driver</entry>
    <entry key='database.url'>jdbc:mysql://localhost/$DB_NAME?zeroDateTimeBehavior=round&amp;serverTimezone=UTC&amp;allowPublicKeyRetrieval=true&amp;useSSL=false&amp;allowMultiQueries=true&amp;autoReconnect=true&amp;useUnicode=yes&amp;characterEncoding=UTF-8&amp;sessionVariables=sql_mode=''</entry>
    <entry key='database.user'>${DB_USER}</entry>
    <entry key='database.password'>${DB_PASSWORD}</entry>

</properties>
EOL

    msg_ok "Archivo traccar.xml configurado."
}

# Configuración de SSL
configure_ssl() {
    SSL_CERT=$(whiptail --inputbox "Introduce la ruta del certificado SSL (crt):" 8 39 --title "Certificado SSL" 3>&1 1>&2 2>&3)
    SSL_KEY=$(whiptail --inputbox "Introduce la ruta de la clave SSL (key):" 8 39 --title "Clave SSL" 3>&1 1>&2 2>&3)

    if [[ -f "$SSL_CERT" && -f "$SSL_KEY" ]]; then
        sudo cp "$SSL_CERT" /etc/ssl/certs/
        sudo cp "$SSL_KEY" /etc/ssl/private/
        msg_ok "Certificado y clave SSL copiados correctamente."
    else
        msg_error "Los archivos de certificado o clave no existen."
    fi
}

# Iniciar todos los servicios
start_services() {
    msg_info "Iniciando servicios..."
    for service in traccar apache2 mysql; do
        sudo systemctl start $service
        msg_ok "$service iniciado."
    done
}

# Ejecutar las funciones en orden
install_services
configure_firewall
configure_traccar
configure_ssl
start_services

# Mostrar todos los datos de la conexión
msg_ok "Instalación y configuración completadas."
msg_info "Parámetros de conexión a la base de datos:"
msg_info "Usuario: $DB_USER"
msg_info "Contraseña: $DB_PASSWORD"
msg_info "Nombre de la base de datos: $DB_NAME"
msg_info "Traccar configurado en: http://<tu-ip>:8082"

# Comprobar el estado de los servicios
check_service "traccar"
check_service "apache2"
check_service "mysql"

