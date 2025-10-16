# Simple Docker container example
# This deploys an nginx container on your local Docker daemon

terraform {
  required_version = ">= 1.0"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

# Provider configuration
provider "docker" {
  # Connects to local Docker daemon
  # Ensure Docker Desktop is running
}

# Pull the nginx image
resource "docker_image" "nginx" {
  name         = "nginx:${var.nginx_version}"
  keep_locally = false # Remove image when destroying
}

# Create nginx container
resource "docker_container" "nginx" {
  name  = var.container_name
  image = docker_image.nginx.image_id

  # Port mapping
  ports {
    internal = 80
    external = var.external_port
  }

  # Health check
  healthcheck {
    test     = ["CMD", "curl", "-f", "http://localhost"]
    interval = "30s"
    timeout  = "3s"
    retries  = 3
  }

  # Container lifecycle
  restart = "unless-stopped"
}
