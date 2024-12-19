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
        if sudo apt install -y $PACKAGE_NAME; then
            msg_ok "$PACKAGE_NAME ha sido instalado."
        else
            msg_error "Error al instalar $PACKAGE_NAME."
            exit 1
        fi
    else
        msg_ok "$PACKAGE_NAME ya está instalado."
    fi
}

# Función para instalar Traccar
install_traccar() {
    RELEASE=$(curl -s https://api.github.com/repos/traccar/traccar/releases/latest | grep "tag_name" | awk '{print substr($2, 3, length($2)-4) }')
    ZIP_FILE="/root/traccar-linux-64-${RELEASE}.zip"
    ZIP_URL="https://github.com/traccar/traccar/releases/download/v${RELEASE}/traccar-linux-64-${RELEASE}.zip"

    # Comprobar si el archivo ZIP ya existe y su tamaño
    if [[ -f "$ZIP_FILE" ]]; then
        LOCAL_SIZE=$(stat -c%s "$ZIP_FILE")
        REMOTE_SIZE=$(curl -sI "$ZIP_URL" | grep -i Content-Length | awk '{print $2}' | tr -d '\r')

        if [[ "$LOCAL_SIZE" -eq "$REMOTE_SIZE" ]]; then
            msg_info "El archivo ZIP ya existe y tiene el mismo tamaño. Usando el archivo existente."
        else
            msg_info "El archivo ZIP existe pero el tamaño es diferente. Descargando nuevamente..."
            wget -q --show-progress "$ZIP_URL" -O "$ZIP_FILE"
        fi
    else
        msg_info "Descargando Traccar v${RELEASE}..."
        wget -q --show-progress "$ZIP_URL" -O "$ZIP_FILE"
    fi

    # Verificar si el archivo es un zip válido
    if ! unzip -t "$ZIP_FILE" &> /dev/null; then
        msg_error "Error: El archivo descargado no es un zip válido."
        exit 1
    fi

    # Descomprimir Traccar
    sudo unzip -q "$ZIP_FILE" -d /root/
    if [[ $? -ne 0 ]]; then
        msg_error "Error al descomprimir Traccar."
        exit 1
    fi

    # Mover y configurar Traccar
    sudo chmod +x /root/traccar.run

    msg_info "Ejecutando el instalador de Traccar..."
    sudo /root/traccar.run &> /tmp/traccar_install.log

    # Mostrar progreso de la instalación
    if [[ $? -ne 0 ]]; then
        msg_error "Error al ejecutar el instalador de Traccar."
        exit 1
    fi

    # Habilitar y iniciar el servicio de Traccar
    msg_info "Habilitando e iniciando el servicio de Traccar..."
    sudo systemctl enable -q --now traccar
    msg_ok "Traccar v${RELEASE} instalado y en ejecución."

    TRACCAR_XML="/opt/traccar/conf/traccar.xml"

    if [[ -f "$TRACCAR_XML" ]]; then
        msg_info "Configurando $TRACCAR_XML..."

        # Solicitar información de conexión a la base de datos
        read -p "Ingresa la dirección de la base de datos (localhost para local): " DB_HOST
        read -p "Ingresa el nombre de la base de datos: " DB_NAME
        read -p "Ingresa el usuario de la base de datos: " DB_USER
        read -sp "Ingresa la contraseña de la base de datos: " DB_PASS
        echo

        # Reescribir el archivo traccar.xml con los nuevos datos
        sudo bash -c "cat > $TRACCAR_XML" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE properties SYSTEM 'http://java.sun.com/dtd/properties.dtd'>
<properties>

    <entry key='database.driver'>com.mysql.cj.jdbc.Driver</entry>
    <entry key='database.url'>jdbc:mysql://$DB_HOST/$DB_NAME?zeroDateTimeBehavior=round&amp;serverTimezone=UTC&amp;allowPublicKeyRetrieval=true&amp;useSSL=false&amp;allowMultiQueries=true&amp;autoReconnect=true&amp;useUnicode=yes&amp;characterEncoding=UTF-8&amp;sessionVariables=sql_mode=''</entry>
    <entry key='database.user'>$DB_USER</entry>
    <entry key='database.password'>$DB_PASS</entry>

</properties>
EOF

        msg_ok "Configuración de $TRACCAR_XML completada."
    else
        msg_error "No se encontró $TRACCAR_XML."
        exit 1
    fi
}

# 1. Instalar dependencias obligatorias
msg_info "Instalando dependencias obligatorias..."
install_if_missing "figlet"
install_if_missing "whiptail"
install_if_missing "openjdk-11-jdk"
install_if_missing "mysql-client"
install_if_missing "ufw"

# 2. Instalar Traccar
install_traccar

# 3. Configurar firewall para los servicios
configure_firewall() {
    sudo ufw allow 8082/tcp
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    for port in {5001..5256}; do
        sudo ufw allow $port/tcp
    done
    sudo ufw enable
}

# Llamar a la función de configuración del firewall
configure_firewall

# 4. Manejo de servicios
manage_services() {
    while true; do
        echo -e "\n\033[1;36mManejo de Servicios de Traccar\033[0m"
        echo "1. Iniciar Traccar"
        echo "2. Detener Traccar"
        echo "3. Reiniciar Traccar"
        echo "4. Ver estado de Traccar"
        echo "5. Salir"
        read -p "Selecciona una opción: " OPTION

        case $OPTION in
            1)
                msg_info "Iniciando Traccar..."
                sudo systemctl start traccar
                msg_ok "Traccar iniciado."
                ;;
            2)
                msg_info "Deteniendo Traccar..."
                sudo systemctl stop traccar
                msg_ok "Traccar detenido."
                ;;
            3)
                msg_info "Reiniciando Traccar..."
                sudo systemctl restart traccar
                msg_ok "Traccar reiniciado."
                ;;
            4)
                msg_info "Verificando estado de Traccar..."
                if systemctl is-active --quiet traccar; then
                    msg_ok "Traccar está activo."
                else
                    msg_error "Traccar no está activo."
                fi
                ;;
            5)
                msg_ok "Saliendo del manejo de servicios."
                break
                ;;
            *)
                msg_error "Opción no válida. Intenta de nuevo."
                ;;
        esac
    done
}

# Llamar a la función de manejo de servicios
manage_services

# Mostrar mensaje final
msg_ok "Instalación y configuración completadas."
