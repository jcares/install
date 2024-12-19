#!/bin/bash

# Mostrar el nombre del dominio en letras grandes
if ! command -v figlet &> /dev/null; then
    echo "El comando 'figlet' no está instalado. Instalando..."
    sudo apt install -y figlet
fi

figlet PCCURICO.CL

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

# Instalar whiptail si no está instalado
install_if_missing "whiptail"

# Función para mostrar progreso
show_progress() {
    echo -n "Progreso: "
    for i in $(seq 1 10); do
        sleep 0.1
        echo -n "#"
    done
    echo ""
}

# Función para desinstalar un servicio
uninstall_service() {
    msg_info "Desinstalando $1..."
    show_progress
    sudo apt purge -y $1
    msg_ok "$1 ha sido desinstalado."
}

# Función para desinstalar Traccar
uninstall_traccar() {
    msg_info "Deteniendo el servicio de Traccar..."
    show_progress
    sudo systemctl stop traccar
    msg_ok "Servicio de Traccar detenido."

    msg_info "Deshabilitando el servicio de Traccar..."
    show_progress
    sudo systemctl disable traccar
    msg_ok "Servicio de Traccar deshabilitado."

    msg_info "Eliminando el archivo del servicio de Traccar..."
    show_progress
    sudo rm /etc/systemd/system/traccar.service
    sudo systemctl daemon-reload
    msg_ok "Archivo del servicio de Traccar eliminado."

    msg_info "Eliminando el directorio de Traccar..."
    show_progress
    sudo rm -R /opt/traccar
    msg_ok "Directorio de Traccar eliminado."
}

# Función para manejar la instalación o desinstalación de un servicio
handle_service() {
    local SERVICE_NAME=$1
    local ACTION=$2

    if [[ "$ACTION" == "install" ]]; then
        install_if_missing "$SERVICE_NAME"
    elif [[ "$ACTION" == "uninstall" ]]; then
        if [[ "$SERVICE_NAME" == "traccar" ]]; then
            uninstall_traccar
        else
            uninstall_service "$SERVICE_NAME"
        fi
    fi
}

# Función principal para manejar la selección de servicios
manage_services() {
    while true; do
        # Preguntar qué servicios desea manejar
        SERVICE_CHOICES=$(whiptail --checklist "Selecciona los servicios que deseas manejar:" 15 60 4 \
        "apache2" "Manejar servidor web Apache" OFF \
        "mysql-server" "Manejar base de datos MySQL" OFF \
        "certbot" "Manejar certificados SSL con Certbot" OFF \
        "traccar" "Manejar Traccar" OFF 3>&1 1>&2 2>&3)

        # Comprobar si se canceló
        if [ $? -ne 0 ]; then
            msg_info "No se realizarán cambios."
            exit 0
        fi

        # Convertir la selección en un array
        IFS='|' read -r -a SELECTED_SERVICES <<< "$SERVICE_CHOICES"

        # Manejar cada servicio seleccionado
        for SERVICE in "${SELECTED_SERVICES[@]}"; do
            # Preguntar al usuario si desea instalar o desinstalar
            ACTION=$(whiptail --radiolist "¿Qué deseas hacer con $SERVICE?" 15 60 2 \
            "install" "Instalar" ON \
            "uninstall" "Desinstalar" OFF 3>&1 1>&2 2>&3)

            # Comprobar si se canceló
            if [ $? -ne 0 ]; then
                msg_info "No se realizarán cambios para $SERVICE."
                continue
            fi

            # Manejar el servicio según la acción seleccionada
            handle_service "$SERVICE" "$ACTION"
            msg_ok "Acción completada para $SERVICE."
        done

        # Mostrar el menú nuevamente automáticamente
        msg_ok "Operaciones completadas. Mostrando el menú nuevamente..."
    done
}

# Ejecutar la función principal
manage_services
