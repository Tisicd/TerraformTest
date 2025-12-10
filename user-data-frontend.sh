#!/bin/bash
# Detectar versión de Amazon Linux e instalar Docker apropiadamente
if command -v amazon-linux-extras &> /dev/null; then
    # Amazon Linux 2
    sudo yum update -y
    sudo amazon-linux-extras enable docker
    sudo yum install -y docker
else
    # Amazon Linux 2023
    sudo dnf update -y
    sudo dnf install -y docker
fi

sudo systemctl enable docker
sudo systemctl start docker

# Esperar a que Docker esté completamente iniciado
sleep 10

# Añadir el usuario ec2-user al grupo docker para poder ejecutar comandos docker sin sudo
sudo usermod -a -G docker ec2-user

# Frontend (Vite) escuchando en 5173 internamente, mapeado al puerto 80 externo
sudo docker run -d --restart always -p 80:5173 ${docker_image_frontend}