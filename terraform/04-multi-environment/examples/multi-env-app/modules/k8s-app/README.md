# Kubernetes Application Module

Reusable Terraform module for deploying applications to Kubernetes.

## Features

- Namespace creation with proper labels
- ConfigMap for configuration (optional)
- Secret for sensitive data (optional)
- Deployment with rolling updates
- Service (ClusterIP, NodePort, or LoadBalancer)
- Horizontal Pod Autoscaler (optional)
- Health checks (liveness and readiness probes)
- Resource requests and limits
- Security context (run as non-root)

## Usage

```hcl
module "app" {
  source = "../../modules/k8s-app"

  # Cluster configuration
  cluster_name = "my-eks-cluster"
  aws_region   = "us-west-2"

  # Application configuration
  app_name          = "my-app"
  namespace         = "production"
  environment       = "prod"
  image_repository  = "myregistry/myapp"
  image_tag         = "1.0.0"

  # Scaling configuration
  replicas          = 3
  enable_autoscaling = true
  min_replicas      = 3
  max_replicas      = 20

  # Resource configuration
  cpu_request    = "200m"
  memory_request = "256Mi"
  cpu_limit      = "1000m"
  memory_limit   = "512Mi"

  # Service configuration
  service_type = "LoadBalancer"
  service_port = 80
  container_port = 8080

  # Configuration data
  config_data = {
    "log.level"         = "info"
    "database.host"     = "db.example.com"
    "database.port"     = "5432"
    "feature.enabled"   = "true"
  }

  # Secret data
  secret_data = {
    "api-key"      = "secret-api-key"
    "db-password"  = "secret-password"
  }

  # Additional env vars
  env_vars = {
    "NEW_RELIC_LICENSE_KEY" = var.newrelic_key
  }

  # Labels
  common_labels = {
    managed-by  = "terraform"
    team        = "platform"
    cost-center = "engineering"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| cluster_name | EKS cluster name | string | - | yes |
| aws_region | AWS region | string | - | yes |
| app_name | Application name | string | - | yes |
| namespace | Kubernetes namespace | string | - | yes |
| environment | Environment (dev/staging/prod) | string | - | yes |
| image_repository | Docker image repository | string | - | yes |
| image_tag | Docker image tag | string | "latest" | no |
| replicas | Number of replicas | number | 2 | no |
| enable_autoscaling | Enable HPA | bool | false | no |
| min_replicas | Min replicas for HPA | number | 2 | no |
| max_replicas | Max replicas for HPA | number | 10 | no |
| cpu_threshold | CPU threshold for HPA | number | 80 | no |
| cpu_request | CPU request | string | "100m" | no |
| memory_request | Memory request | string | "128Mi" | no |
| cpu_limit | CPU limit | string | "500m" | no |
| memory_limit | Memory limit | string | "256Mi" | no |
| service_type | Service type | string | "ClusterIP" | no |
| service_port | Service port | number | 80 | no |
| container_port | Container port | number | 8080 | no |
| config_data | ConfigMap data | map(string) | {} | no |
| secret_data | Secret data | map(string) | {} | no |
| env_vars | Additional environment variables | map(string) | {} | no |
| common_labels | Common labels | map(string) | {managed-by="terraform"} | no |

## Outputs

| Name | Description |
|------|-------------|
| namespace | Namespace name |
| deployment_name | Deployment name |
| service_name | Service name |
| service_type | Service type |
| loadbalancer_hostname | LB hostname (if applicable) |
| configmap_name | ConfigMap name |
| secret_name | Secret name |
| hpa_enabled | Whether HPA is enabled |
| hpa_name | HPA name |
| app_labels | Application labels |

## Examples

### Development Configuration

```hcl
module "dev_app" {
  source = "../../modules/k8s-app"

  cluster_name     = "dev-eks-cluster"
  aws_region       = "us-west-2"
  app_name         = "myapp"
  namespace        = "dev"
  environment      = "dev"
  image_repository = "myapp"
  image_tag        = "latest"

  # Minimal resources for dev
  replicas          = 1
  enable_autoscaling = false
  service_type      = "ClusterIP"
  cpu_request       = "50m"
  memory_request    = "64Mi"
}
```

### Production Configuration

```hcl
module "prod_app" {
  source = "../../modules/k8s-app"

  cluster_name     = "prod-eks-cluster"
  aws_region       = "us-west-2"
  app_name         = "myapp"
  namespace        = "production"
  environment      = "prod"
  image_repository = "myregistry/myapp"
  image_tag        = "1.0.0"

  # High availability for prod
  replicas          = 5
  enable_autoscaling = true
  min_replicas      = 5
  max_replicas      = 50
  service_type      = "LoadBalancer"
  cpu_request       = "500m"
  memory_request    = "512Mi"
  cpu_limit         = "2000m"
  memory_limit      = "1Gi"
}
```

## Requirements

- Terraform >= 1.0
- Kubernetes provider ~> 2.23
- AWS provider ~> 5.0
- Existing EKS cluster
- kubectl access to the cluster

## License

MIT
