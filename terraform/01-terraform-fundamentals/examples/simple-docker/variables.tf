# Input variables for the Docker nginx example

variable "container_name" {
  description = "Name of the Docker container"
  type        = string
  default     = "my-nginx"

  validation {
    condition     = length(var.container_name) > 0
    error_message = "Container name cannot be empty"
  }
}

variable "external_port" {
  description = "External port to expose nginx"
  type        = number
  default     = 8080

  validation {
    condition     = var.external_port >= 1024 && var.external_port <= 65535
    error_message = "Port must be between 1024 and 65535"
  }
}

variable "nginx_version" {
  description = "Nginx Docker image version"
  type        = string
  default     = "latest"

  # Consider pinning to specific version in production
  # default = "1.25"
}
