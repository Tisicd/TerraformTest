#!/bin/bash
yum update -y
amazon-linux-extras install -y docker
systemctl enable docker
systemctl start docker

# Backend escuchando en 3000
docker run -d --restart always -p 3000:3000 ${docker_image_backend}



