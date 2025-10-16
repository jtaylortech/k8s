# Development Environment Configuration
# Uses the reusable k8s-app module with dev-specific settings

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

# AWS Provider
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "dev"
      ManagedBy   = "Terraform"
      Project     = var.project_name
    }
  }
}

# Kubernetes Provider
# Connects to the EKS cluster specified in variables
data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = var.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

# =============================================================================
# Deploy Application using Module
# =============================================================================

module "app" {
  source = "../../modules/k8s-app"

  # Cluster configuration
  cluster_name = var.cluster_name
  aws_region   = var.aws_region

  # Application configuration
  app_name         = var.app_name
  namespace        = "${var.app_name}-dev"  # Dev namespace
  environment      = "dev"
  image_repository = var.image_repository
  image_tag        = var.image_tag

  # Dev-specific scaling (minimal)
  replicas           = 1
  enable_autoscaling = false  # No autoscaling in dev

  # Dev-specific resources (small)
  cpu_request    = "50m"
  memory_request = "64Mi"
  cpu_limit      = "200m"
  memory_limit   = "128Mi"

  # Service configuration (ClusterIP = no LoadBalancer costs)
  service_type   = "ClusterIP"
  service_port   = 80
  container_port = var.container_port

  # Health check configuration
  health_check_path        = var.health_check_path
  readiness_initial_delay  = 5
  liveness_initial_delay   = 15

  # Configuration data
  config_data = {
    "log.level"           = "debug"  # Verbose logging in dev
    "feature.new-ui"      = "true"   # Enable experimental features
    "cache.enabled"       = "false"  # Disable cache for faster iteration
    "database.pool.size"  = "5"
  }

  # Secrets (example - use AWS Secrets Manager in production!)
  secret_data = {
    "api-key"     = "dev-api-key-12345"
    "db-password" = "dev-password"
  }

  # Additional environment variables
  env_vars = {
    "DEBUG"                 = "true"
    "ENVIRONMENT"           = "development"
    "API_BASE_URL"          = "https://api-dev.example.com"
  }

  # Labels
  common_labels = {
    managed-by  = "terraform"
    environment = "dev"
    team        = var.team
    cost-center = "engineering"
  }

  # Pod annotations
  pod_annotations = {
    "dev.mode" = "true"
  }
}
