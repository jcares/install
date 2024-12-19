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
    if ! command -v $1 &> /dev/null; then
        msg_info "Instalando $1..."
        sudo apt install -y $1
    else
        msg_ok "$1 ya está instalado."
    fi
}

# Función para desinstalar un servicio
uninstall_service() {
    msg_info "Desinstalando $1..."
    sudo apt remove --purge -y $1
    msg_ok "$1 ha sido desinstalado."
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
            msg_info "El archivo ZIP existe pero el tamaño es diferente. Eliminando archivo corrupto..."
            rm -f "$ZIP_FILE"
            msg_info "Descargando Traccar v${RELEASE}..."
            wget -q --show-progress "$ZIP_URL" -O "$ZIP_FILE" || { msg_error "Error al descargar Traccar."; exit 1; }
        fi
    else
        msg_info "Descargando Traccar v${RELEASE}..."
        wget -q --show-progress "$ZIP_URL" -O "$ZIP_FILE" || { msg_error "Error al descargar Traccar."; exit 1; }
    fi

    # Verificar si el archivo es un zip válido
    if ! unzip -t "$ZIP_FILE" &> /dev/null; then
        msg_error "Error: El archivo descargado no es un zip válido. Eliminando archivo..."
        rm -f "$ZIP_FILE"
        exit 1
    fi

    # Descomprimir Traccar
    sudo unzip -q "$ZIP_FILE" -d /root/ || { msg_error "Error al descomprimir Traccar."; exit 1; }

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
}

# Instalar Traccar primero
install_traccar

# Detectar dependencias
msg_info "Detectando dependencias..."
install_if_missing curl
install_if_missing sudo
install_if_missing mc
install_if_missing unzip

# Preguntar qué servicios desea desinstalar si se detecta alguno ya instalado
UNINSTALL_SERVICES=$(whiptail --checklist "Selecciona los servicios que deseas desinstalar:" 15 60 4 \
"Apache" "Desinstalar servidor web Apache" OFF \
"MySQL" "Desinstalar base de datos MySQL" OFF \
"Certbot" "Desinstalar certificados SSL con Certbot" OFF 3>&1 1>&2 2>&3)

# Comprobar si se canceló
if [ $? -ne 0 ]; then
    msg_info "No se desinstalarán servicios."
else
    # Convertir la selección en un array
    IFS='|' read -r -a UNSELECTED_SERVICES <<< "$UNINSTALL_SERVICES"
    
    for SERVICE in "${UNSELECTED_SERVICES[@]}"; do
        case $SERVICE in
            "Apache")
                if systemctl is-active --quiet apache2; then
                    uninstall_service apache2
                    install_if_missing apache2  # Reinstalar después de desinstalar
                else
                    msg_info "Apache no está instalado."
                fi
                ;;
            "MySQL")
                if systemctl is-active --quiet mysql; then
                    uninstall_service mysql-server
                    install_if_missing mysql-server  # Reinstalar después de desinstalar
                else
                    msg_info "MySQL no está instalado."
                fi
                ;;
            "Certbot")
                if systemctl is-active --quiet certbot; then
                    uninstall_service certbot
                    install_if_missing certbot  # Reinstalar después de desinstalar
                else
                    msg_info "Certbot no está instalado."
                fi
                ;;
        esac
    done
fi

# Preguntar qué servicios desea instalar
msg_info "Selecciona los servicios que deseas instalar:"
SERVICE_CHOICES=$(whiptail --checklist "Selecciona los servicios que deseas instalar:" 15 60 4 \
"Apache" "Instalar servidor web Apache" OFF \
"MySQL" "Instalar base de datos MySQL" OFF \
"Certbot" "Instalar certificados SSL con Certbot" OFF 3>&1 1>&2 2>&3)

# Comprobar si se canceló
if [ $? -ne 0 ]; then
    msg_info "No se instalarán servicios."
else
    # Convertir la selección en un array
    IFS='|' read -r -a SELECTED_SERVICES <<< "$SERVICE_CHOICES"
    
    for SERVICE in "${SELECTED_SERVICES[@]}"; do
        case $SERVICE in
            "Apache")
                if systemctl is-active --quiet apache2; then
                    msg_info "Apache ya está instalado."
                else
                    install_if_missing apache2
                fi
                ;;
            "MySQL")
                if systemctl is-active --quiet mysql; then
                    msg_info "MySQL ya está instalado."
                else
                    install_if_missing mysql-server
                fi
                ;;
            "Certbot")
                if systemctl is-active --quiet certbot; then
                    msg_info "Certbot ya está instalado."
                else
                    install_if_missing certbot
                fi
                ;;
        esac
    done
fi

# Configurar el firewall
msg_info "Configurando el firewall para permitir tráfico en puertos 80 y 443."
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw reload

# Solicitar datos al usuario para Certbot
if [[ " ${SELECTED_SERVICES[@]} " =~ " Certbot " ]]; then
    read -p "Ingresa el dominio (ejemplo: clientes.gpsafechile.cl): " DOMAIN
    read -p "Ingresa tu correo electrónico para Let's Encrypt: " EMAIL

    # Obtener el certificado SSL
    msg_info "Obteniendo certificado SSL para $DOMAIN."
    sudo certbot certonly --standalone -d $DOMAIN --non-interactive --agree-tos --email $EMAIL

    # Verificar si el certificado se obtuvo correctamente
    if [ $? -eq 0 ]; then
        msg_ok "Certificado SSL obtenido exitosamente."
    else
        msg_info "Error al obtener el certificado SSL. Verifica la configuración del dominio y el firewall."
        exit 1
    fi
fi

# Resumen de la configuración
msg_info "Resumen de la configuración:"
echo "------------------------------------"
echo "Servicios instalados:"

for SERVICE in "${SELECTED_SERVICES[@]}"; do
    case $SERVICE in
        "Apache")
            echo "- Apache (httpd) instalado."
            ;;
        "MySQL")
            echo "- MySQL instalado."
            ;;
        "Certbot")
            echo "- Certbot instalado."
            ;;
    esac
done

echo "------------------------------------"
echo "Información de conexión:"
echo "Dominio: $DOMAIN"
echo "Correo electrónico: $EMAIL"
echo "Usuario de base de datos: $(whoami)"  # Usuario registrado
echo "------------------------------------"

msg_ok "Instalación y configuración completadas."

# Limpiar archivos temporales
msg_info "Limpiando archivos temporales..."
rm -rf "/root/traccar-linux-64-*.zip"
msg_ok "Archivos temporales limpiados."
