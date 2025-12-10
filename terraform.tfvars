# Región donde tienes la VPC y las subnets
aws_region = "us-east-1"

# Identificador de la VPC EXISTENTE (cámbialo por el de tu cuenta)
vpc_id = "vpc-0008af468cf10c190"

# Subnets PÚBLICAS EXISTENTES donde se crearán los ASG y el ALB
public_subnet_ids = [
  "subnet-0b4719532f38aa249",
  "subnet-0a5b1725667fa6852",
  "subnet-0059fd9437a91eb87",
  "subnet-095053c3cfa0b3f24",
  "subnet-091bc5279c696c6cf"
]

# AMI de Amazon Linux 2 en tu región (cámbiala por la oficial de tu región)
ami_id = "ami-068c0051b15cdb816" 

# Tipo de instancia para los Auto Scaling Groups
instance_type = "t3.micro"

# Máximo de instancias por ASG (requisito del curso: 10)
max_instances = 10

# Nombre de la key pair SSH ya creada (opcional, deja vacío o comenta si no la usas)
ssh_key_name = "AWSkeys"

# Nombre del Instance Profile IAM EXISTENTE (opcional, deja vacío o comenta si no lo usas)
# instance_profile_name = ""

# Imágenes Docker del frontend y backend
docker_image_frontend = "letis/digimon-frontend:latest"
docker_image_backend  = "letis/digimon-backend:latest"

# Número de Elastic IPs a reservar (0 por defecto para no consumir límite)
eip_count = 0

# Tags comunes opcionales adicionales
common_tags = {
  Owner       = "student"
  Environment = "dev"
}




