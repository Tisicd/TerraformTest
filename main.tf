terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

########################
## VPC Y SUBREDES EXISTENTES
########################

data "aws_vpc" "existing" {
  id = var.vpc_id
}

########################
## GRUPOS DE SEGURIDAD (3 SG: ALB, FRONTEND, BACKEND)
########################

# SG del ALB - HTTP 80 desde Internet, outbound all
resource "aws_security_group" "alb_sg" {
  name        = "${var.project_name}-alb-sg"
  description = "Security Group del ALB de frontend"
  vpc_id      = data.aws_vpc.existing.id

  ingress {
    description = "HTTP 80 desde Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-alb-sg"
      Project     = var.project_name
      Environment = "LoadTest"
    }
  )
}

# SG del ASG Frontend
resource "aws_security_group" "frontend_sg" {
  name        = "${var.project_name}-frontend-sg"
  description = "Security Group del ASG de frontend"
  vpc_id      = data.aws_vpc.existing.id

  # HTTP 80 desde el ALB
  ingress {
    description     = "HTTP 80 desde ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  # Outbound all (incluye tráfico hacia el backend en 3000)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-frontend-sg"
      Project     = var.project_name
      Environment = "LoadTest"
    }
  )
}

# SG del ASG Backend
resource "aws_security_group" "backend_sg" {
  name        = "${var.project_name}-backend-sg"
  description = "Security Group del ASG de backend"
  vpc_id      = data.aws_vpc.existing.id

  # HTTP 3000 desde el SG de frontend
  ingress {
    description     = "HTTP 3000 desde frontend"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend_sg.id]
  }

  # Outbound all
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-backend-sg"
      Project     = var.project_name
      Environment = "LoadTest"
    }
  )
}

########################
## LOAD BALANCER (ALB FRONTEND)
########################

resource "aws_lb" "frontend_alb" {
  name               = "${var.project_name}-frontend-alb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-frontend-alb"
      Project     = var.project_name
      Environment = "LoadTest"
    }
  )
}

resource "aws_lb_target_group" "frontend_tg" {
  name        = "${var.project_name}-frontend-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.existing.id
  target_type = "instance"

  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/"
    matcher             = "200-399"
  }

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-frontend-tg"
      Project     = var.project_name
      Environment = "LoadTest"
    }
  )
}

resource "aws_lb_listener" "frontend_http_80" {
  load_balancer_arn = aws_lb.frontend_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_tg.arn
  }
}

########################
## LAUNCH TEMPLATES (FRONTEND Y BACKEND)
########################

resource "aws_launch_template" "frontend_lt" {
  name_prefix   = "${var.project_name}-frontend-lt-"
  image_id      = var.ami_id
  instance_type = var.instance_type

  key_name = var.ssh_key_name

  vpc_security_group_ids = [aws_security_group.frontend_sg.id]

  # IMPORTANTE: no creamos roles/políticas IAM, solo usamos uno existente si se indica.
  iam_instance_profile {
    name = var.instance_profile_name
  }

  # User Data: instala Docker y levanta el contenedor de frontend
  user_data = base64encode(
    templatefile("${path.module}/user-data-frontend.sh", {
      docker_image_frontend = var.docker_image_frontend
    })
  )

  tag_specifications {
    resource_type = "instance"

    tags = merge(
      var.common_tags,
      {
        Name        = "${var.project_name}-frontend-ec2"
        Project     = var.project_name
        Environment = "LoadTest"
      }
    )
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_launch_template" "backend_lt" {
  name_prefix   = "${var.project_name}-backend-lt-"
  image_id      = var.ami_id
  instance_type = var.instance_type

  key_name = var.ssh_key_name

  vpc_security_group_ids = [aws_security_group.backend_sg.id]

  iam_instance_profile {
    name = var.instance_profile_name
  }

  # User Data: instala Docker y levanta el contenedor de backend
  user_data = base64encode(
    templatefile("${path.module}/user-data-backend.sh", {
      docker_image_backend = var.docker_image_backend
    })
  )

  tag_specifications {
    resource_type = "instance"

    tags = merge(
      var.common_tags,
      {
        Name        = "${var.project_name}-backend-ec2"
        Project     = var.project_name
        Environment = "LoadTest"
      }
    )
  }

  lifecycle {
    create_before_destroy = true
  }
}

########################
## AUTO SCALING GROUPS (FRONTEND Y BACKEND)
########################

resource "aws_autoscaling_group" "frontend_asg" {
  name                = "${var.project_name}-frontend-asg"
  min_size            = 1
  desired_capacity    = 2
  max_size            = var.max_instances
  vpc_zone_identifier = var.public_subnet_ids

  health_check_type         = "EC2"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.frontend_lt.id
    version = "$Latest"
  }

  target_group_arns = [
    aws_lb_target_group.frontend_tg.arn
  ]

  tag {
    key                 = "Name"
    value               = "${var.project_name}-frontend-asg-ec2"
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = var.project_name
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = "LoadTest"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_lb_listener.frontend_http_80]
}

resource "aws_autoscaling_group" "backend_asg" {
  name                = "${var.project_name}-backend-asg"
  min_size            = 1
  desired_capacity    = 2
  max_size            = var.max_instances
  # TODO: backend should run in private subnets for a production-grade architecture
  vpc_zone_identifier = var.public_subnet_ids

  health_check_type         = "EC2"
  health_check_grace_period = 120

  launch_template {
    id      = aws_launch_template.backend_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-backend-asg-ec2"
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = var.project_name
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = "LoadTest"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

########################
## POLÍTICAS DE AUTO SCALING (CPU Y REQUEST COUNT - FRONTEND)
########################

# CPU: Scale out > 70%, scale in < 30%
resource "aws_autoscaling_policy" "frontend_scale_out_cpu" {
  name                   = "${var.project_name}-frontend-cpu-scale-out"
  autoscaling_group_name = aws_autoscaling_group.frontend_asg.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 60
  policy_type            = "SimpleScaling"
}

resource "aws_autoscaling_policy" "frontend_scale_in_cpu" {
  name                   = "${var.project_name}-frontend-cpu-scale-in"
  autoscaling_group_name = aws_autoscaling_group.frontend_asg.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 60
  policy_type            = "SimpleScaling"
}

resource "aws_cloudwatch_metric_alarm" "frontend_cpu_high" {
  alarm_name          = "${var.project_name}-frontend-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 70

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.frontend_asg.name
  }

  alarm_description = "CPU > 70% - scale out"
  alarm_actions     = [aws_autoscaling_policy.frontend_scale_out_cpu.arn]
}

resource "aws_cloudwatch_metric_alarm" "frontend_cpu_low" {
  alarm_name          = "${var.project_name}-frontend-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 30

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.frontend_asg.name
  }

  alarm_description = "CPU < 30% - scale in"
  alarm_actions     = [aws_autoscaling_policy.frontend_scale_in_cpu.arn]
}

# RequestCountPerTarget (Target Tracking) para el ALB/Target Group del frontend
resource "aws_autoscaling_policy" "frontend_req_count" {
  name                   = "${var.project_name}-frontend-req-per-target"
  autoscaling_group_name = aws_autoscaling_group.frontend_asg.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      # resource_label = app/load-balancer-name/xxx/targetgroup/target-group-name/yyy
      resource_label = "${aws_lb.frontend_alb.name}/${aws_lb_target_group.frontend_tg.name}"
    }
    # Número objetivo de requests por instancia (ajústalo según tus pruebas)
    target_value = 100.0
  }
}

########################
## ELASTIC IPs OPCIONALES (MÁXIMO 5)
########################

resource "aws_eip" "extra_eip" {
  count = var.eip_count

  domain = "vpc"

  # No los asociamos automáticamente para no romper ASG ni otros recursos.
  # Puedes usarlos luego para NAT Gateways o instancias específicas.

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-eip-${count.index}"
    }
  )
}

