# Staging Environment Configuration
# Uses the reusable k8s-app module with staging-specific settings

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
      Environment = "staging"
      ManagedBy   = "Terraform"
      Project     = var.project_name
    }
  }
}

# Kubernetes Provider
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
  namespace        = "${var.app_name}-staging"  # Staging namespace
  environment      = "staging"
  image_repository = var.image_repository
  image_tag        = var.image_tag

  # Staging-specific scaling (moderate)
  replicas           = 2
  enable_autoscaling = true  # Enable autoscaling in staging
  min_replicas       = 2
  max_replicas       = 5
  cpu_threshold      = 75

  # Staging-specific resources (medium)
  cpu_request    = "100m"
  memory_request = "128Mi"
  cpu_limit      = "500m"
  memory_limit   = "256Mi"

  # Service configuration (LoadBalancer for realistic testing)
  service_type   = "LoadBalancer"
  service_port   = 80
  container_port = var.container_port

  # Health check configuration
  health_check_path        = var.health_check_path
  readiness_initial_delay  = 10
  liveness_initial_delay   = 30

  # Configuration data
  config_data = {
    "log.level"           = "info"   # Less verbose than dev
    "feature.new-ui"      = "true"   # Test new features
    "cache.enabled"       = "true"   # Enable cache
    "cache.ttl"           = "300"
    "database.pool.size"  = "10"
  }

  # Secrets (example - use AWS Secrets Manager in production!)
  secret_data = {
    "api-key"     = "staging-api-key-67890"
    "db-password" = "staging-password"
  }

  # Additional environment variables
  env_vars = {
    "DEBUG"                 = "false"
    "ENVIRONMENT"           = "staging"
    "API_BASE_URL"          = "https://api-staging.example.com"
  }

  # Labels
  common_labels = {
    managed-by  = "terraform"
    environment = "staging"
    team        = var.team
    cost-center = "engineering"
  }

  # Pod annotations
  pod_annotations = {
    "monitoring.enabled" = "true"
  }
}
