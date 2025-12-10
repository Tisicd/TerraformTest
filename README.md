## Descripción

Este proyecto contiene una infraestructura de referencia en **Terraform** para desplegar una aplicación **frontend + backend Dockerizada** sobre **AWS EC2 con Auto Scaling Groups y Application Load Balancer (ALB)**, reutilizando **una VPC y subredes ya existentes** en tu cuenta.

Características principales:

- **VPC y subredes existentes** (no se crea red nueva, solo se consumen `vpc_id` y `public_subnet_ids`).
- **3 Security Groups** (ALB, Frontend ASG, Backend ASG) con flujo FE → BE (puertos 80 y 3000).
- **1 ALB público** con listener en **HTTP 80** y **1 Target Group** apuntando al ASG de frontend.
- **2 Launch Templates** (frontend/backend) que:
  - Instalan Docker en Amazon Linux 2.
  - Ejecutan `docker run` de las imágenes definidas por variables.
  - Configuran `--restart always` para resiliencia en pruebas de carga.
- **2 Auto Scaling Groups** (frontend/backend) con:
  - `min=1`, `desired=2`, `max=10` (requisito del curso).
  - ASG frontend asociado al Target Group del ALB.
- **Políticas de Auto Scaling**:
  - CPU > 70% → scale out.
  - CPU < 30% → scale in.
  - Target Tracking `ALBRequestCountPerTarget`.
- **Sin backend S3**: el estado se guarda localmente por defecto.

## Requisitos previos

- Cuenta de **AWS** (puede ser académica) con:
  - Una **VPC existente** y **subredes públicas**.
  - Un **par de claves SSH** (KeyPair) si quieres acceso por SSH a las instancias.
  - (Opcional) Un **Instance Profile IAM existente** si tus instancias necesitan permisos.
- **Terraform ≥ 1.5** instalado localmente.
- **Git** y una cuenta de **GitHub** para usar el workflow de GitHub Actions (opcional).

## Estructura del proyecto

```text
.
├─ main.tf                 # Definición principal de la infraestructura (SG, ALB, LT, ASG, políticas)
├─ variables.tf            # Definición de variables de entrada
├─ outputs.tf              # Salidas principales (DNS del ALB y nombres de ASG)
├─ terraform.tfvars        # Valores concretos para tu cuenta AWS (vpc, subnets, AMI, imágenes Docker, etc.)
├─ user-data-frontend.sh   # Script user-data para el Launch Template del frontend
├─ user-data-backend.sh    # Script user-data para el Launch Template del backend
└─ .github/
   └─ workflows/
      └─ terraform-aws.yml # (Opcional) Workflow de GitHub Actions para ejecutar Terraform en CI/CD
```

## Configuración de variables (`terraform.tfvars`)

En este archivo se definen los valores concretos de tu cuenta y tus imágenes Docker. Ejemplo (ya adaptado a tu cuenta, solo a modo ilustrativo):

```hcl
aws_region = "us-east-1"

vpc_id = "vpc-0008af468cf10c190"

public_subnet_ids = [
  "subnet-0b4719532f38aa249",
  "subnet-0a5b1725667fa6852",
  "subnet-0059fd9437a91eb87",
  "subnet-095053c3cfa0b3f24",
  "subnet-091bc5279c696c6cf"
]

ami_id        = "ami-068c0051b15cdb816"
instance_type = "t3.micro"
max_instances = 10

ssh_key_name = "AWSkeys"
# instance_profile_name = "mi-instance-profile-existente" # opcional

docker_image_frontend = "letis/digimon-frontend:latest"
docker_image_backend  = "letis/digimon-backend:latest"

eip_count = 0
```

> **Importante:** No pongas **credenciales de AWS** (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`) en este archivo. Esas deben ir como **GitHub Secrets** si usas GitHub Actions.

## Cómo desplegar localmente

1. Instala Terraform (si no lo tienes).
2. Exporta tus credenciales de AWS como variables de entorno, por ejemplo:

```bash
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_SESSION_TOKEN=...
export AWS_REGION=us-east-1
```

3. Desde la raíz del proyecto:

```bash
terraform init
terraform plan
terraform apply
```

Al finalizar, Terraform mostrará salidas similares a:

```text
alb_dns = "terrtest-app-frontend-alb-xxxxxxxx.us-east-1.elb.amazonaws.com"
frontend_asg_name = "terrtest-app-frontend-asg"
backend_asg_name  = "terrtest-app-backend-asg"
```

Abre `http://alb_dns` en tu navegador para acceder al frontend.

## Despliegue con GitHub Actions

En el directorio `.github/workflows` hay un workflow `terraform-aws.yml` que:

- Hace `terraform init` y `terraform plan` en cada push a `main` (según configuración).
- Ejecuta `terraform apply` cuando lanzas el workflow manualmente (`workflow_dispatch`).

### 1. Crear el repositorio en GitHub

1. Inicializa git en la carpeta del proyecto:

```bash
git init
git add .
git commit -m "Initial Terraform AWS infra (FE/BE, ALB, ASG)"
```

2. Crea un repositorio en GitHub y añade el remoto:

```bash
git remote add origin git@github.com:TU_USUARIO/TerraTest.git
git push -u origin main
```

### 2. Configurar GitHub Secrets

En GitHub, ve a **Settings → Security → Secrets and variables → Actions → New repository secret** y añade:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_SESSION_TOKEN`

Usa las credenciales de tu IAM User académico.

### 3. Ejecutar el workflow

1. Ve a la pestaña **Actions** del repositorio.
2. Selecciona el workflow **“Terraform AWS”**.
3. Pulsa **“Run workflow”** para lanzar un `plan` + `apply` usando la configuración del repo.

## Notas y futuras mejoras

- El backend actual **no usa subredes privadas** por simplicidad del curso:

  ```hcl
  # TODO: backend should run in private subnets for a production-grade architecture
  ```

  En un entorno real, deberías mover el ASG de backend a subredes privadas y exponer solo el frontend por el ALB.

- No se crea ninguna VPC ni subred nueva; todo se basa en recursos existentes, cumpliendo las restricciones típicas de cuentas académicas.


