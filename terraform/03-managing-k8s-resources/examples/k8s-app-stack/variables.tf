# Input Variables for Kubernetes Application Stack

# =============================================================================
# AWS Configuration
# =============================================================================

variable "aws_region" {
  description = "AWS region where EKS cluster is deployed"
  type        = string
  default     = "us-west-2"
}

variable "cluster_name" {
  description = "Name of the EKS cluster to deploy to"
  type        = string

  validation {
    condition     = length(var.cluster_name) > 0
    error_message = "Cluster name cannot be empty."
  }
}

# =============================================================================
# Application Configuration
# =============================================================================

variable "app_name" {
  description = "Name of the application (used for labels and resource names)"
  type        = string
  default     = "demo-app"

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.app_name))
    error_message = "App name must be a valid DNS label (lowercase alphanumeric and hyphens)."
  }
}

variable "namespace" {
  description = "Kubernetes namespace to deploy resources into"
  type        = string
  default     = "demo"

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.namespace))
    error_message = "Namespace must be a valid DNS label."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

# =============================================================================
# Deployment Configuration
# =============================================================================

variable "app_image" {
  description = "Docker image for the application"
  type        = string
  default     = "nginx:1.25-alpine"
}

variable "app_replicas" {
  description = "Number of replicas for the application deployment"
  type        = number
  default     = 2

  validation {
    condition     = var.app_replicas >= 1 && var.app_replicas <= 10
    error_message = "Replicas must be between 1 and 10."
  }
}

variable "app_port" {
  description = "Port the application listens on"
  type        = number
  default     = 80

  validation {
    condition     = var.app_port > 0 && var.app_port < 65536
    error_message = "Port must be between 1 and 65535."
  }
}

variable "cpu_request" {
  description = "CPU request for each pod (e.g., '100m' = 0.1 CPU cores)"
  type        = string
  default     = "100m"
}

variable "memory_request" {
  description = "Memory request for each pod (e.g., '128Mi')"
  type        = string
  default     = "128Mi"
}

variable "cpu_limit" {
  description = "CPU limit for each pod"
  type        = string
  default     = "500m"
}

variable "memory_limit" {
  description = "Memory limit for each pod"
  type        = string
  default     = "256Mi"
}

# =============================================================================
# Service Configuration
# =============================================================================

variable "service_type" {
  description = "Kubernetes service type (ClusterIP, NodePort, LoadBalancer)"
  type        = string
  default     = "LoadBalancer"

  validation {
    condition     = contains(["ClusterIP", "NodePort", "LoadBalancer"], var.service_type)
    error_message = "Service type must be ClusterIP, NodePort, or LoadBalancer."
  }
}

# =============================================================================
# Helm Configuration
# =============================================================================

variable "install_ingress_nginx" {
  description = "Whether to install NGINX Ingress Controller via Helm"
  type        = bool
  default     = true
}

variable "ingress_nginx_version" {
  description = "Version of NGINX Ingress Controller Helm chart"
  type        = string
  default     = "4.8.3"
}

# =============================================================================
# Feature Flags
# =============================================================================

variable "enable_autoscaling" {
  description = "Enable Horizontal Pod Autoscaler for the application"
  type        = bool
  default     = true
}

variable "hpa_min_replicas" {
  description = "Minimum replicas for HPA"
  type        = number
  default     = 2
}

variable "hpa_max_replicas" {
  description = "Maximum replicas for HPA"
  type        = number
  default     = 10
}

variable "hpa_cpu_threshold" {
  description = "CPU utilization threshold for HPA (percentage)"
  type        = number
  default     = 80
}

# =============================================================================
# Labels and Tags
# =============================================================================

variable "common_labels" {
  description = "Common labels to apply to all resources"
  type        = map(string)
  default = {
    managed-by = "terraform"
  }
}
