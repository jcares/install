#!/bin/bash

# Variables
SERVER_NAME="srv2.pccurico.cl"  # Nombre de dominio
ROOT_DIR="/var/www/html"         # Ruta de tu directorio web
NGINX_CONF="/etc/nginx/sites-available/srv2.conf"
NGINX_ENABLED="/etc/nginx/sites-enabled/srv2.conf"

# Crear archivo de configuración de Nginx
cat <<EOF > $NGINX_CONF
server {
    listen 443 ssl;
    server_name $SERVER_NAME;

    ssl_certificate /etc/ssl/certs/srv2.crt;
    ssl_certificate_key /etc/ssl/private/srv2.key;

    location / {
        root $ROOT_DIR;
        index index.html index.htm;
    }

    # Otras configuraciones...
}
EOF

# Activar la configuración del sitio
if ln -s $NGINX_CONF $NGINX_ENABLED; then
    echo "Configuración de Nginx activada."
else
    echo "Error al activar la configuración de Nginx." >&2
    exit 1
fi

# Probar la configuración de Nginx
if nginx -t; then
    echo "La configuración de Nginx es válida."
else
    echo "Error en la configuración de Nginx." >&2
    exit 1
fi

# Reiniciar Nginx
if systemctl restart nginx; then
    echo "Nginx reiniciado correctamente."
else
    echo "Error al reiniciar Nginx." >&2
    exit 1
fi

# Verificar el estado de Nginx
if systemctl status nginx.service; then
    echo "Nginx está funcionando correctamente."
else
    echo "Nginx no está funcionando." >&2
    exit 1
fi
