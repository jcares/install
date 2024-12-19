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

# Función para desinstalar Traccar
uninstall_traccar() {
    msg_info "Desinstalando Traccar..."
    sudo systemctl stop traccar
    sudo systemctl disable traccar
    sudo rm /etc/systemd/system/traccar.service
    sudo systemctl daemon-reload
    sudo rm -rf /opt/traccar
    msg_ok "Traccar ha sido desinstalado."
}

# Función para instalar Apache2
install_apache() {
    install_if_missing "apache2"
    sudo apt install -y apache2
    msg_ok "Apache2 ha sido instalado."
}

# Función principal del menú
main_menu() {
    # Mostrar el nombre del dominio en letras grandes
    if ! command -v figlet &> /dev/null; then
        msg_info "El comando 'figlet' no está instalado. Instalando..."
        sudo apt install -y figlet
    fi

    figlet PCCURICO.CL

    while true; do
        echo -e "\n\033[1;36mMenú de Instalación de Traccar y Apache2\033[0m"
        echo "1. Instalar Traccar"
        echo "2. Desinstalar Traccar"
        echo "3. Instalar Apache2"
        echo "4. Salir"
        read -p "Selecciona una opción: " OPTION

        case $OPTION in
            1)
                install_if_missing "curl"
                install_if_missing "unzip"
                install_traccar
                ;;
            2)
                uninstall_traccar
                ;;
            3)
                install_apache
                ;;
            4)
                msg_ok "Saliendo."
                exit 0
                ;;
            *)
                msg_error "Opción no válida. Intenta de nuevo."
                ;;
        esac
    done
}

# Llamar a la función principal del menú
main_menu
