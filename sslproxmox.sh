#!/bin/bash

# Variables
DOMAIN="srv2.pccurico.cl"
CRT_FILE="/etc/ca-certificates/srv2_pcc.crt"
KEY_FILE="/etc/ca-certificates/srv2_pcc.key"
NGINX_CONF="/etc/nginx/sites-available/proxmox"
NGINX_ENABLED="/etc/nginx/sites-enabled/proxmox"

# Función para manejar errores
handle_error() {
    echo "Ocurrió un error: $1"
    exit 1
}

# Copiar certificados
copy_certificates() {
    echo "Copiando certificados..."
    cp "$CRT_FILE" "/etc/ssl/certs/$CRT_FILE.crt" || handle_error "Error al copiar el certificado"
    cp "$KEY_FILE" "/etc/ssl/private/$CRT_FILE.key" || handle_error "Error al copiar la clave"
    echo "Certificados copiados."
}

# Configurar Nginx
configure_nginx() {
    echo "Configurando Nginx..."
    sudo tee "$NGINX_CONF" > /dev/null <<EOL
server {
    listen 443 ssl;
    server_name $DOMAIN;

    ssl_certificate /etc/ssl/certs/$CRT_FILE.crt;
    ssl_certificate_key /etc/ssl/private/$CRT_FILE.key;

    location / {
        proxy_pass https://127.0.0.1:8006;  # Puerto de Proxmox
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}

server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$host\$request_uri;  # Redirigir HTTP a HTTPS
}
EOL
    echo "Configuración de Nginx completada."
}

# Habilitar configuración de Nginx
enable_nginx_conf() {
    echo "Habilitando la configuración de Nginx..."
    if [ ! -f "$NGINX_ENABLED" ]; then
        sudo ln -s "$NGINX_CONF" "$NGINX_ENABLED" || handle_error "Error al habilitar la configuración de Nginx"
        echo "Configuración de Nginx habilitada."
    else
        echo "La configuración de Nginx ya está habilitada."
    fi
}

# Reiniciar Nginx
restart_nginx() {
    echo "Reiniciando Nginx..."
    sudo systemctl restart nginx || handle_error "Error al reiniciar Nginx"
    echo "Nginx reiniciado."
}

# Comenzar el proceso
copy_certificates
configure_nginx
enable_nginx_conf
restart_nginx

echo "Configuración de navegación segura completa para Proxmox en $DOMAIN."
