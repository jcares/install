#!/bin/bash

# Función para mostrar el encabezado
function show_header() {
    echo "=============================="
    figlet "GPSafe by PC-CURICO"
    echo "=============================="
}

# Función para mostrar el menú
function show_menu() {
    echo "1. Instalar Dependencias"
    echo "2. Configurar IP y Parámetros de Red"
    echo "3. Revisar Servicios"
    echo "4. Activar Sitios Disponibles"
    echo "5. Configurar Firewall/Iptables"
    echo "6. Reconfigurar Servicios"
    echo "7. Salir"
    read -p "Seleccione una opción: " OPTION
}

# Instalar figlet si no está instalado
if ! command -v figlet &> /dev/null; then
    sudo apt install -y figlet
fi

# Mostrar encabezado
show_header

# Actualizar el sistema
sudo apt update && sudo apt upgrade -y

# Menú principal
while true; do
    show_menu

    case $OPTION in
        1)
            # Instalar dependencias
            sudo apt install -y software-properties-common apache2 mysql-server php8.3 libapache2-mod-php8.3 php8.3-mysql php8.3-xml php8.3-mbstring php8.3-curl phpmyadmin
            echo "Dependencias instaladas."
            ;;
        2)
            # Configurar IP y Parámetros de Red
            read -p "Ingrese la nueva dirección IP (ej. 192.168.1.10): " NEW_IP
            read -p "Ingrese la máscara de subred (ej. 255.255.255.0): " NETMASK
            read -p "Ingrese la puerta de enlace (ej. 192.168.1.1): " GATEWAY
            read -p "Ingrese el nombre del servidor (ej. srv2): " HOSTNAME

            # Configurar IP estática
            echo -e "auto eth0\niface eth0 inet static\naddress $NEW_IP\nnetmask $NETMASK\ngateway $GATEWAY" | sudo tee /etc/network/interfaces.d/eth0

            # Configurar el nombre de la máquina
            sudo hostnamectl set-hostname $HOSTNAME
            echo "La IP y el nombre de la máquina se han configurado."
            ;;
        3)
            # Revisar servicios
            echo "Servicios en ejecución:"
            systemctl list-units --type=service --state=running
            ;;
        4)
            # Activar sitios disponibles
            echo "Sitios disponibles:"
            ls /etc/apache2/sites-available/
            read -p "Ingrese el nombre del sitio que desea activar (ej. ejemplo.conf): " SITE_NAME
            sudo a2ensite $SITE_NAME
            echo "Sitio $SITE_NAME activado."
            sudo systemctl reload apache2
            ;;
        5)
            # Configurar Firewall/Iptables
            echo "Configurando Firewall/Iptables..."
            sudo ufw allow 'Apache Full'
            sudo ufw enable
            echo "Firewall configurado para permitir tráfico de Apache."
            ;;
        6)
            # Reconfigurar servicios
            echo "1. Reconfigurar MySQL"
            echo "2. Reconfigurar PHPMyAdmin"
            echo "3. Reconfigurar Apache2"
            echo "4. Cambiar nombre de dominio"
            read -p "Seleccione una opción: " RECONFIG_OPTION

            case $RECONFIG_OPTION in
                1)
                    sudo mysql_secure_installation
                    ;;
                2)
                    echo "Reconfigurando PHPMyAdmin..."
                    # Aquí puedes agregar la lógica para reconfigurar PHPMyAdmin
                    ;;
                3)
                    echo "Reconfigurando Apache2..."
                    # Aquí puedes agregar la lógica para reconfigurar Apache2
                    ;;
                4)
                    read -p "Ingrese el nuevo nombre de dominio: " NEW_DOMAIN
                    echo "Dominio cambiado a: $NEW_DOMAIN"
                    # Aquí puedes agregar la lógica para cambiar el nombre de dominio
                    ;;
                *)
                    echo "Opción no válida."
                    ;;
            esac
            ;;
        7)
            echo "Saliendo..."
            break
            ;;
        *)
            echo "Opción no válida. Intente de nuevo."
            ;;
    esac
done
