# Production Environment Configuration
# Uses the reusable k8s-app module with production-grade settings

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
      Environment = "production"
      ManagedBy   = "Terraform"
      Project     = var.project_name
      CriticalSystem = "true"
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
  namespace        = var.app_name  # Production namespace (no suffix)
  environment      = "prod"
  image_repository = var.image_repository
  image_tag        = var.image_tag  # Always use specific version, never "latest"

  # Production-grade scaling (high availability)
  replicas           = 3              # Start with 3 for HA
  enable_autoscaling = true
  min_replicas       = 3              # Always keep at least 3 running
  max_replicas       = 20             # Scale up to 20 under load
  cpu_threshold      = 70             # More conservative threshold

  # Production-grade resources (large)
  cpu_request    = "500m"   # 0.5 CPU cores guaranteed
  memory_request = "512Mi"  # 512MB guaranteed
  cpu_limit      = "2000m"  # Max 2 CPU cores
  memory_limit   = "1Gi"    # Max 1GB memory

  # Service configuration (LoadBalancer for external access)
  service_type   = "LoadBalancer"
  service_port   = 80
  container_port = var.container_port

  # Health check configuration (more conservative)
  health_check_path        = var.health_check_path
  readiness_initial_delay  = 15
  liveness_initial_delay   = 45

  # Configuration data
  config_data = {
    "log.level"           = "warn"   # Less verbose in production
    "feature.new-ui"      = "false"  # Stable features only
    "cache.enabled"       = "true"
    "cache.ttl"           = "600"    # Longer cache TTL
    "database.pool.size"  = "20"     # Larger connection pool
    "metrics.enabled"     = "true"
    "tracing.enabled"     = "true"
  }

  # Secrets (IMPORTANT: Use AWS Secrets Manager in real production!)
  # Example using data source to fetch from Secrets Manager:
  # data "aws_secretsmanager_secret_version" "api_key" {
  #   secret_id = "prod/myapp/api-key"
  # }
  # Then use: jsondecode(data.aws_secretsmanager_secret_version.api_key.secret_string)
  secret_data = {
    "api-key"     = "CHANGE-ME-USE-SECRETS-MANAGER"
    "db-password" = "CHANGE-ME-USE-SECRETS-MANAGER"
  }

  # Additional environment variables
  env_vars = {
    "DEBUG"                 = "false"
    "ENVIRONMENT"           = "production"
    "API_BASE_URL"          = "https://api.example.com"
    "SENTRY_DSN"            = var.sentry_dsn
    "NEW_RELIC_LICENSE_KEY" = var.newrelic_license_key
  }

  # Labels
  common_labels = {
    managed-by  = "terraform"
    environment = "prod"
    team        = var.team
    cost-center = "production"
    criticality = "high"
    compliance  = "required"
  }

  # Pod annotations (for monitoring and service mesh)
  pod_annotations = {
    "monitoring.enabled"           = "true"
    "alerting.enabled"             = "true"
    "backup.enabled"               = "true"
    "prometheus.io/scrape"         = "true"
    "prometheus.io/port"           = tostring(var.container_port)
    # Uncomment if using Istio service mesh
    # "sidecar.istio.io/inject"    = "true"
  }
}

# =============================================================================
# Production-specific Resources
# =============================================================================

# PodDisruptionBudget to ensure availability during disruptions
resource "kubernetes_pod_disruption_budget_v1" "app" {
  metadata {
    name      = "${var.app_name}-pdb"
    namespace = module.app.namespace
  }

  spec {
    min_available = 2  # Always keep at least 2 pods running

    selector {
      match_labels = module.app.app_labels
    }
  }
}

# NetworkPolicy for enhanced security (example)
# resource "kubernetes_network_policy" "app" {
#   metadata {
#     name      = "${var.app_name}-netpol"
#     namespace = module.app.namespace
#   }
#
#   spec {
#     pod_selector {
#       match_labels = module.app.app_labels
#     }
#
#     policy_types = ["Ingress", "Egress"]
#
#     # Allow ingress from ingress controller
#     ingress {
#       from {
#         namespace_selector {
#           match_labels = {
#             name = "ingress-nginx"
#           }
#         }
#       }
#       ports {
#         port     = var.container_port
#         protocol = "TCP"
#       }
#     }
#
#     # Allow egress to database
#     egress {
#       to {
#         namespace_selector {
#           match_labels = {
#             name = "database"
#           }
#         }
#       }
#       ports {
#         port     = 5432
#         protocol = "TCP"
#       }
#     }
#   }
# }
