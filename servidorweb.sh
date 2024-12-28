#!/bin/bash

# Función para mostrar el encabezado
function show_header() {
    echo "=============================="
    figlet "GPSafe by PC-CURICO"
    echo "=============================="
}

# Mostrar encabezado
show_header

# Preguntar por el nombre del subdominio
read -p "Ingrese el subdominio (ej. srv2.gpsafechile.cl): " SUBDOMINIO
read -p "Ingrese su dirección de correo para certificados SSL: " EMAIL

# Actualizar el sistema
sudo apt update && sudo apt upgrade -y

# Instalar dependencias
sudo apt install -y software-properties-common

# Agregar repositorios
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update

# Instalar Apache
sudo apt install -y apache2

# Instalar PHP y extensiones necesarias
sudo apt install -y php8.3 libapache2-mod-php8.3 php8.3-mysql php8.3-xml php8.3-mbstring php8.3-curl

# Instalar MySQL
sudo apt install -y mysql-server

# Asegurar MySQL (opcional)
sudo mysql_secure_installation

# Instalar phpMyAdmin
sudo apt install -y phpmyadmin

# Configurar phpMyAdmin en Apache
echo "Include /etc/phpmyadmin/apache.conf" | sudo tee -a /etc/apache2/apache2.conf

# Habilitar módulos de Apache
sudo a2enmod rewrite
sudo a2enmod ssl

# Crear directorios para los subdominios
sudo mkdir -p /var/www/$SUBDOMINIO/sn1
sudo mkdir -p /var/www/$SUBDOMINIO/sn2

# Asignar permisos
sudo chown -R www-data:www-data /var/www/$SUBDOMINIO
sudo chmod -R 755 /var/www/$SUBDOMINIO

# Crear un archivo de índice con el texto "pccurico.cl"
for SUB in sn1 sn2; do
    echo "<html>
<head>
    <title>pccurico.cl</title>
    <style>
        body { text-align: center; margin-top: 20%; }
        h1 { font-size: 50px; }
    </style>
</head>
<body>
    <h1>pccurico.cl</h1>
</body>
</html>" | sudo tee /var/www/$SUBDOMINIO/$SUB/index.php
done

# Crear archivos de configuración para los subdominios
for SUB in sn1 sn2; do
    echo "<VirtualHost *:80>
    ServerName $SUB.$SUBDOMINIO
    DocumentRoot /var/www/$SUBDOMINIO/$SUB
    <Directory /var/www/$SUBDOMINIO/$SUB>
        AllowOverride All
    </Directory>
</VirtualHost>" | sudo tee /etc/apache2/sites-available/$SUB.conf
done

# Habilitar los sitios
for SUB in sn1 sn2; do
    sudo a2ensite $SUB.conf
done

# Configurar SSL con Let's Encrypt
sudo apt install -y certbot python3-certbot-apache
sudo certbot --apache -d $SUBDOMINIO -d ns1.$SUBDOMINIO -d ns2.$SUBDOMINIO --email $EMAIL --agree-tos --no-eff-email --redirect

# Reiniciar Apache para aplicar cambios
sudo systemctl restart apache2

# Mensaje de éxito
echo "Servidor web configurado para $SUBDOMINIO"
