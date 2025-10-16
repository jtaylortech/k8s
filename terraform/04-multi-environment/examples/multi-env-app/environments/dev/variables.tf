# Development Environment Variables

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "k8s-learning"
}

variable "app_name" {
  description = "Application name"
  type        = string
}

variable "image_repository" {
  description = "Docker image repository"
  type        = string
}

variable "image_tag" {
  description = "Docker image tag"
  type        = string
  default     = "latest"
}

variable "container_port" {
  description = "Container port"
  type        = number
  default     = 8080
}

variable "health_check_path" {
  description = "Health check path"
  type        = string
  default     = "/health"
}

variable "team" {
  description = "Team name"
  type        = string
  default     = "platform"
}
