#!/bin/bash

# Cambiar permisos para hacer el script ejecutable
chmod +x $0
sudo apt install figlet -y 

# Función para mostrar el mensaje en letras grandes usando figlet
show_title() {
    echo -e "\n"
    figlet "PC-CURICO.CL"
    echo -e "\n"
}

# Función para mostrar la barra de progreso
progress_bar() {
    local duration=$1
    for ((i=0; i<=duration; i++)); do
        sleep 1
        echo -ne "\rProgreso: ["
        for ((j=0; j<i*100/duration; j+=2)); do
            echo -n "#"
        done
        for ((j=i*100/duration; j<100; j+=2)); do
            echo -n "-"
        done
        echo -ne "] $i/$duration segundos"
    done
    echo -e "\n"
}

# Función para mostrar la configuración de red actual
show_network_config() {
    echo "Configuración de red actual:"
    ip addr show
    echo ""
}

# Función para editar la configuración de red
edit_network_config() {
    read -p "Ingrese la nueva dirección IP (ejemplo: 192.168.0.3): " new_ip
    read -p "Ingrese la nueva máscara de subred (ejemplo: 24): " new_mask
    read -p "Ingrese la nueva puerta de enlace (ejemplo: 192.168.0.1): " new_gateway
    read -p "Ingrese el nuevo servidor DNS (ejemplo: 192.168.1.254): " new_dns

    # Aplicar la nueva configuración
    ip addr flush dev eth0
    ip addr add $new_ip/$new_mask dev eth0
    ip route add default via $new_gateway
    echo -e "nameserver $new_dns\nnameserver 8.8.8.8" > /etc/resolv.conf

    echo "Configuración de red actualizada."
}

# Función para reparar los repositorios
repair_repos() {
    echo "Reparando repositorios..."
    
    # Hacer una copia de seguridad del archivo sources.list
    cp /etc/apt/sources.list /etc/apt/sources.list.bak
    
    # Lista de repositorios por defecto
    repos=(
        "deb http://deb.debian.org/debian/ bullseye main contrib non-free"
        "deb http://deb.debian.org/debian-security/ bullseye-security main contrib non-free"
        "deb http://deb.debian.org/debian/ bullseye-updates main contrib non-free"
    )

    # Crear un nuevo sources.list vacío
    > /etc/apt/sources.list

    # Verificar cada repositorio
    for repo in "${repos[@]}"; do
        # Obtener la URL del repositorio
        url=$(echo $repo | awk '{print $2}')
        
        # Hacer ping a la URL
        if ping -c 1 -W 1 $(echo $url | awk -F/ '{print $3}') > /dev/null; then
            echo "Repositorio activo: $url"
            echo "$repo" >> /etc/apt/sources.list
        else
            echo "Repositorio inactivo: $url. Se eliminará."
        fi
    done

    # Actualizar la lista de paquetes
    apt update
}

# Función para arreglar repositorios duplicados
fix_duplicate_repos() {
    echo "Arreglando repositorios duplicados..."
    local files=(
        "/etc/apt/sources.list.d/pve-install-repo.list"
        "/etc/apt/sources.list.d/pve-no-subscription.list"
    )

    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            echo "Revisando $file..."
            # Comentar líneas duplicadas
            awk '!seen[$0]++' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
        fi
    done

    echo "Repositorios duplicados arreglados."
}

# Mostrar el título
show_title

# Menú principal
while true; do
    echo "Seleccione una opción:"
    echo "1) Mostrar configuración de red"
    echo "2) Editar configuración de red"
    echo "3) Reparar repositorios"
    echo "4) Arreglar repositorios duplicados"
    echo "5) Salir"
    read -p "Opción: " option

    case $option in
        1)
            show_network_config
            ;;
        2)
            show_network_config
            edit_network_config
            ;;
        3)
            progress_bar 5 # Mostrar barra de progreso por 5 segundos
            repair_repos
            ;;
        4)
            fix_duplicate_repos
            ;;
        5)
            echo "Saliendo..."
            exit 0
            ;;
        *)
            echo "Opción no válida. Intente de nuevo."
            ;;
    esac
done
