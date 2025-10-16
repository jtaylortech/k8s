# Production Environment Variables

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
  description = "Docker image tag (should be specific version, not 'latest')"
  type        = string

  validation {
    condition     = var.image_tag != "latest"
    error_message = "Production should use specific version tags, not 'latest'."
  }
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

variable "sentry_dsn" {
  description = "Sentry DSN for error tracking"
  type        = string
  default     = ""
  sensitive   = true
}

variable "newrelic_license_key" {
  description = "New Relic license key for APM"
  type        = string
  default     = ""
  sensitive   = true
}
