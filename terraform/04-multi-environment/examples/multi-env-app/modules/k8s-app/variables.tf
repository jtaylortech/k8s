# Module Input Variables
# These are the inputs that environments will provide to the module

# =============================================================================
# Cluster Configuration
# =============================================================================

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "aws_region" {
  description = "AWS region where EKS cluster is deployed"
  type        = string
}

# =============================================================================
# Application Configuration
# =============================================================================

variable "app_name" {
  description = "Name of the application"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.app_name))
    error_message = "App name must be a valid DNS label."
  }
}

variable "namespace" {
  description = "Kubernetes namespace"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.namespace))
    error_message = "Namespace must be a valid DNS label."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

# =============================================================================
# Deployment Configuration
# =============================================================================

variable "image_repository" {
  description = "Docker image repository"
  type        = string
}

variable "image_tag" {
  description = "Docker image tag"
  type        = string
  default     = "latest"
}

variable "replicas" {
  description = "Number of pod replicas"
  type        = number
  default     = 2

  validation {
    condition     = var.replicas >= 1 && var.replicas <= 100
    error_message = "Replicas must be between 1 and 100."
  }
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 8080

  validation {
    condition     = var.container_port > 0 && var.container_port < 65536
    error_message = "Port must be between 1 and 65535."
  }
}

# =============================================================================
# Resource Configuration
# =============================================================================

variable "cpu_request" {
  description = "CPU request (e.g., '100m' = 0.1 cores)"
  type        = string
  default     = "100m"
}

variable "memory_request" {
  description = "Memory request (e.g., '128Mi')"
  type        = string
  default     = "128Mi"
}

variable "cpu_limit" {
  description = "CPU limit"
  type        = string
  default     = "500m"
}

variable "memory_limit" {
  description = "Memory limit"
  type        = string
  default     = "256Mi"
}

# =============================================================================
# Service Configuration
# =============================================================================

variable "service_type" {
  description = "Kubernetes service type"
  type        = string
  default     = "ClusterIP"

  validation {
    condition     = contains(["ClusterIP", "NodePort", "LoadBalancer"], var.service_type)
    error_message = "Service type must be ClusterIP, NodePort, or LoadBalancer."
  }
}

variable "service_port" {
  description = "Service port (external)"
  type        = number
  default     = 80
}

# =============================================================================
# Autoscaling Configuration
# =============================================================================

variable "enable_autoscaling" {
  description = "Enable Horizontal Pod Autoscaler"
  type        = bool
  default     = false
}

variable "min_replicas" {
  description = "Minimum replicas for HPA"
  type        = number
  default     = 2
}

variable "max_replicas" {
  description = "Maximum replicas for HPA"
  type        = number
  default     = 10
}

variable "cpu_threshold" {
  description = "CPU utilization threshold for HPA (%)"
  type        = number
  default     = 80

  validation {
    condition     = var.cpu_threshold > 0 && var.cpu_threshold <= 100
    error_message = "CPU threshold must be between 1 and 100."
  }
}

# =============================================================================
# Health Check Configuration
# =============================================================================

variable "health_check_path" {
  description = "HTTP path for health checks"
  type        = string
  default     = "/health"
}

variable "readiness_initial_delay" {
  description = "Initial delay for readiness probe (seconds)"
  type        = number
  default     = 10
}

variable "liveness_initial_delay" {
  description = "Initial delay for liveness probe (seconds)"
  type        = number
  default     = 30
}

# =============================================================================
# Configuration and Secrets
# =============================================================================

variable "config_data" {
  description = "Configuration data for ConfigMap"
  type        = map(string)
  default     = {}
}

variable "secret_data" {
  description = "Secret data (will be base64 encoded by K8s)"
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "env_vars" {
  description = "Additional environment variables"
  type        = map(string)
  default     = {}
}

# =============================================================================
# Labels and Annotations
# =============================================================================

variable "common_labels" {
  description = "Common labels to apply to all resources"
  type        = map(string)
  default = {
    managed-by = "terraform"
  }
}

variable "pod_annotations" {
  description = "Annotations for pods"
  type        = map(string)
  default     = {}
}
