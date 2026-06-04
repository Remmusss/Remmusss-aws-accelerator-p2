output "alb_dns_name" {
  description = "DNS name of the public ALB."
  value       = aws_lb.app.dns_name
}

output "app_url" {
  description = "Public URL for the app behind the ALB."
  value       = "http://${aws_lb.app.dns_name}"
}

output "ec2_public_ip" {
  description = "Public IP of the minikube host EC2 instance."
  value       = aws_instance.minikube_host.public_ip
}

output "ec2_instance_id" {
  description = "EC2 instance id that hosts minikube."
  value       = aws_instance.minikube_host.id
}

output "nodeport" {
  description = "Fixed NodePort exposed by the Kubernetes service."
  value       = var.nodeport
}
