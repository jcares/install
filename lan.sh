#!/bin/bash

# Cambiar permisos para hacer el script ejecutable
chmod +x $0

# Función para instalar figlet si no está instalado
install_figlet() {
    if ! command -v figlet &> /dev/null; then
        echo "Instalando figlet..."
        apt install figlet -y
    fi
}

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

# Función para obtener el nombre de la interfaz de red
get_network_interface() {
    # Obtener el nombre de la interfaz de red activa
    ip -o -f inet addr show | awk '{print $2}' | head -n 1
}

# Función para editar la configuración de red
edit_network_config() {
    local interface=$(get_network_interface)
    echo "Interfaz de red actual: $interface"
    
    read -p "Ingrese la nueva dirección IP (ejemplo: 192.168.0.3): " new_ip
    read -p "Ingrese la nueva máscara de subred (ejemplo: 24): " new_mask
    read -p "Ingrese la nueva puerta de enlace (ejemplo: 192.168.0.1): " new_gateway
    read -p "Ingrese el nuevo servidor DNS (ejemplo: 192.168.1.254): " new_dns

    # Aplicar la nueva configuración
    ip addr flush dev "$interface"
    ip addr add "$new_ip/$new_mask" dev "$interface"
    ip route add default via "$new_gateway"
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
    local inactive_repos=()
    for repo in "${repos[@]}"; do
        # Obtener la URL del repositorio
        url=$(echo $repo | awk '{print $2}')
        
        # Hacer ping a la URL
        if ping -c 1 -W 1 $(echo $url | awk -F/ '{print $3}') > /dev/null; then
            echo "Repositorio activo: $url"
            echo "$repo" >> /etc/apt/sources.list
        else
            echo "Repositorio inactivo: $url. Se eliminará."
            inactive_repos+=("$url")
        fi
    done

    # Actualizar la lista de paquetes
    apt update

    # Mostrar repositorios inactivos
    if [ ${#inactive_repos[@]} -gt 0 ]; then
        echo "Se encontraron los siguientes repositorios inactivos:"
        for repo in "${inactive_repos[@]}"; do
            echo "- $repo"
        done
    fi
}

# Función para arreglar repositorios duplicados
fix_duplicate_repos() {
    echo "Arreglando repositorios duplicados..."
    local files=(
        "/etc/apt/sources.list.d/pve-install-repo.list"
        "/etc/apt/sources.list.d/pve-no-subscription.list"
    )
    local duplicates_file="/tmp/duplicados_repos.txt"
    > "$duplicates_file"  # Crear o limpiar el archivo de duplicados

    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            echo "Revisando $file..."
            # Identificar y guardar líneas duplicadas
            awk 'seen[$0]++' "$file" >> "$duplicates_file"
        fi
    done

    # Eliminar duplicados a partir de la lista
    if [ -s "$duplicates_file" ]; then
        echo "Se encontraron los siguientes repositorios duplicados:"
        cat "$duplicates_file"
        
        read -p "¿Desea eliminar estos duplicados? (s/n): " confirm
        if [[ "$confirm" =~ ^[Ss]$ ]]; then
            echo "Eliminando duplicados..."
            for file in "${files[@]}"; do
                if [ -f "$file" ]; then
                    awk '!seen[$0]++' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
                fi
            done
            echo "Repositorios duplicados eliminados."
        else
            echo "No se eliminaron los repositorios duplicados."
        fi
    else
        echo "No se encontraron repositorios duplicados."
    fi
}

# Función para eliminar todos los repositorios
remove_all_repos() {
    echo "Eliminando todos los repositorios..."
    > /etc/apt/sources.list
    rm -f /etc/apt/sources.list.d/*.list
    echo "Todos los repositorios han sido eliminados."
}

# Función para verificar conflictos en los repositorios
check_repo_conflicts() {
    echo "Verificando conflictos en los repositorios..."
    apt update 2>&1 | grep -i "conflict"
}

# Instalar figlet si no está instalado
install_figlet

# Mostrar el título
show_title

# Menú principal
while true; do
    echo "Seleccione una opción:"
    echo "1) Mostrar configuración de red"
    echo "2) Editar configuración de red"
    echo "3) Reparar repositorios"
    echo "4) Arreglar repositorios duplicados"
    echo "5) Eliminar todos los repositorios"
    echo "6) Verificar conflictos en repositorios"
    echo "7) Salir"
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
            remove_all_repos
            ;;
        6)
            check_repo_conflicts
            ;;
        7)
            echo "Saliendo..."
            exit 0
            ;;
        *)
            echo "Opción no válida. Intente de nuevo."
            ;;
    esac
done
