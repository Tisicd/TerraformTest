variable "project_name" {
  description = "Nombre lógico del proyecto para nombrar recursos"
  type        = string
  default     = "terrtest-app"
}

variable "aws_region" {
  description = "Región de AWS donde desplegar la infraestructura"
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "ID de la VPC EXISTENTE donde se desplegarán los recursos (ej: vpc-1234567890abcdef0)"
  type        = string
}

variable "public_subnet_ids" {
  description = "Lista de IDs de subredes PÚBLICAS existentes para los ASG (ej: [\"subnet-aaa\", \"subnet-bbb\"])"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Lista de IDs de subredes PRIVADAS existentes (opcional, por si las necesitas en el futuro)"
  type        = list(string)
  default     = []
}

variable "ami_id" {
  type        = string
  description = "Amazon Linux 2 AMI ID"
}

variable "instance_type" {
  description = "Tipo de instancia EC2 para los ASG"
  type        = string
  default     = "t3.micro"
}

variable "ssh_key_name" {
  description = "Nombre de la key pair SSH ya creada en AWS para acceder a las instancias (opcional)"
  type        = string
  default     = null
}

variable "instance_profile_name" {
  description = "Nombre del Instance Profile IAM EXISTENTE a usar por las instancias (no se crea nada nuevo)"
  type        = string
  default     = null
}

variable "max_instances" {
  description = "Número máximo de instancias para los Auto Scaling Groups (requisito del curso: 10)"
  type        = number
  default     = 10
}

variable "docker_image_frontend" {
  description = "Imagen Docker del frontend (por ejemplo: usuario/mi-frontend:tag)"
  type        = string
}

variable "docker_image_backend" {
  description = "Imagen Docker del backend (por ejemplo: usuario/mi-backend:tag)"
  type        = string
}

variable "eip_count" {
  description = "Número de Elastic IPs a reservar (máximo 5). Por defecto 0 para no consumir límite."
  type        = number
  default     = 0

  validation {
    condition     = var.eip_count <= 5 && var.eip_count >= 0
    error_message = "eip_count debe estar entre 0 y 5 para cumplir el límite de la cuenta."
  }
}

variable "common_tags" {
  description = "Mapa de tags comunes a aplicar a todos los recursos"
  type        = map(string)
  default = {
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

