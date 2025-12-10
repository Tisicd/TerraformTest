output "alb_dns" {
  value = aws_lb.frontend_alb.dns_name
}

output "frontend_asg_name" {
  value = aws_autoscaling_group.frontend_asg.name
}

output "backend_asg_name" {
  value = aws_autoscaling_group.backend_asg.name
}

