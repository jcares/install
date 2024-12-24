#!/bin/bash

# Actualizar el sistema
echo "Actualizando el sistema..."
sudo apt update && sudo apt upgrade -y

# Instalar dependencias necesarias
echo "Instalando dependencias..."
sudo apt install -y git curl python3 python3-pip python3-venv

# Clonar el repositorio de BookMedic
echo "Clonando el repositorio de BookMedic..."
git clone https://github.com/evilnapsis/bookmedik.git # Reemplaza con la URL correcta

# Navegar al directorio del proyecto
cd bookmedic || { echo "Error al entrar en el directorio bookmedic"; exit 1; }

# Crear un entorno virtual
echo "Creando un entorno virtual..."
python3 -m venv venv

# Activar el entorno virtual
source venv/bin/activate

# Instalar las dependencias de BookMedic
echo "Instalando dependencias de BookMedic..."
pip install -r requirements.txt

# Configuración inicial (si aplica)
# Puedes agregar aquí pasos adicionales de configuración si son necesarios

# Finalización
echo "Instalación completada. Para activar BookMedic, usa 'source venv/bin/activate' y luego ejecuta el script correspondiente."

# Desactivar el entorno virtual (opcional)
deactivate