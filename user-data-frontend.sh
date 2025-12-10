#!/bin/bash
yum update -y
amazon-linux-extras install -y docker
systemctl enable docker
systemctl start docker

# Suponemos que el contenedor expone 3000, lo publicamos en el 80 de la instancia
docker run -d --restart always -p 80:3000 ${docker_image_frontend}



