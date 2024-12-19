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
    if ! dpkg -l | grep -q "^ii  $1"; then
        msg_info "Instalando $1..."
        sudo apt install -y $1
        msg_ok "$1 ha sido instalado."
    else
        msg_ok "$1 ya está instalado."
    fi
}

# Instalar whiptail si no está instalado
install_if_missing "whiptail"

# Función para instalar un paquete si no está instalado
install_if_missing() {
    if ! dpkg -l | grep -q "^ii  $1"; then
        msg_info "Instalando $1..."
        sudo apt install -y $1
        msg_ok "$1 ha sido instalado."
    else
        msg_ok "$1 ya está instalado."
    fi
}

# Función para desinstalar un servicio
uninstall_service() {
    msg_info "Desinstalando $1..."
    sudo apt purge -y $1
    msg_ok "$1 ha sido desinstalado."
}

# Función para desinstalar Traccar
uninstall_traccar() {
    msg_info "Deteniendo el servicio de Traccar..."
    sudo systemctl stop traccar
    msg_ok "Servicio de Traccar detenido."

    msg_info "Deshabilitando el servicio de Traccar..."
    sudo systemctl disable traccar
    msg_ok "Servicio de Traccar deshabilitado."

    msg_info "Eliminando el archivo del servicio de Traccar..."
    sudo rm /etc/systemd/system/traccar.service
    sudo systemctl daemon-reload
    msg_ok "Archivo del servicio de Traccar eliminado."

    msg_info "Eliminando el directorio de Traccar..."
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
        if [[ "$SERVICE_NAME" == "Traccar" ]]; then
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
        "Apache" "Manejar servidor web Apache" OFF \
        "MySQL" "Manejar base de datos MySQL" OFF \
        "Certbot" "Manejar certificados SSL con Certbot" OFF \
        "Traccar" "Manejar Traccar" OFF 3>&1 1>&2 2>&3)

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
        done

        # Preguntar si desea continuar manejando servicios
        CONTINUE=$(whiptail --yesno "¿Deseas manejar más servicios?" 8 45 --title "Continuar" && echo "yes" || echo "no")

        if [[ "$CONTINUE" == "no" ]]; then
            break
        fi
    done

    msg_ok "Operaciones completadas."
}

# Ejecutar la función principal
manage_services
