z# Outputs - useful information after apply

output "container_id" {
  description = "ID of the Docker container"
  value       = docker_container.nginx.id
}

output "container_name" {
  description = "Name of the Docker container"
  value       = docker_container.nginx.name
}

output "image_id" {
  description = "ID of the Docker image"
  value       = docker_image.nginx.image_id
}

output "access_url" {
  description = "URL to access nginx"
  value       = "http://localhost:${var.external_port}"
}

output "docker_command" {
  description = "Equivalent docker run command"
  value       = "docker run -d -p ${var.external_port}:80 --name ${var.container_name} nginx:${var.nginx_version}"
}
