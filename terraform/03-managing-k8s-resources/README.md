# Module 03: Managing Kubernetes Resources with Terraform

**Duration**: ~3 hours
**Prerequisites**: [Module 02: Provisioning Clusters](../02-provisioning-clusters/README.md)
**Next Module**: [04-Multi-Environment Patterns](../04-multi-environment/README.md)
**Cost**: Uses existing EKS cluster from Module 02

## Learning Objectives

By the end of this module, you will:
- ✅ Use Kubernetes provider in Terraform
- ✅ Manage K8s resources (Namespaces, Deployments, Services)
- ✅ Deploy applications with Terraform
- ✅ Integrate Helm provider with Terraform
- ✅ Understand when to use Terraform vs kubectl/Helm
- ✅ Implement GitOps-friendly patterns

---

## Part 1: Terraform vs kubectl vs Helm

### When to Use Each

| Tool | Best For | Example |
|------|----------|---------|
| **Terraform** | Infrastructure, cluster setup, long-lived resources | VPC, EKS cluster, node groups, IAM |
| **kubectl** | Day-to-day ops, debugging, quick changes | Port-forward, logs, exec |
| **Helm** | Application deployment, upgrades | Install nginx-ingress, Prometheus |
| **Terraform + K8s Provider** | GitOps, infrastructure apps, foundational resources | Namespaces, RBAC, cluster config |
| **Terraform + Helm Provider** | Declarative Helm releases | Deploy apps with values as code |

### Our Approach

```
Terraform manages:
├── Infrastructure (VPC, EKS, IAM)
├── Foundational K8s resources (Namespaces, RBAC)
└── Helm releases (Applications)

kubectl for:
├── Debugging (logs, exec, port-forward)
└── Manual interventions

Helm CLI for:
└── Local development/testing
```

---

## Part 2: Kubernetes Provider Setup

### Configure Provider

**File**: `kubernetes.tf`
```hcl
# Get EKS cluster info (assumes you created cluster in Module 02)
data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = var.cluster_name
}

# Kubernetes provider
provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

# Helm provider
provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}
```

---

## Part 3: Managing Kubernetes Resources

### Namespaces

```hcl
# Create namespaces
resource "kubernetes_namespace" "environments" {
  for_each = toset(["dev", "staging", "production"])

  metadata {
    name = each.key

    labels = {
      environment = each.key
      managed-by  = "terraform"
    }
  }
}

# Namespace with resource quotas
resource "kubernetes_namespace" "app" {
  metadata {
    name = "my-app"
  }
}

resource "kubernetes_resource_quota" "app" {
  metadata {
    name      = "app-quota"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  spec {
    hard = {
      "requests.cpu"    = "10"
      "requests.memory" = "20Gi"
      "pods"            = "50"
    }
  }
}
```

### ConfigMaps and Secrets

```hcl
# ConfigMap
resource "kubernetes_config_map" "app_config" {
  metadata {
    name      = "app-config"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  data = {
    APP_ENV       = "production"
    LOG_LEVEL     = "info"
    DATABASE_HOST = "db.example.com"
  }
}

# Secret (don't hardcode in production!)
resource "kubernetes_secret" "app_secrets" {
  metadata {
    name      = "app-secrets"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  data = {
    db-password = base64encode("changeme")
    api-key     = base64encode("secret-key-123")
  }

  type = "Opaque"
}
```

### Deployments

```hcl
resource "kubernetes_deployment" "app" {
  metadata {
    name      = "my-app"
    namespace = kubernetes_namespace.app.metadata[0].name

    labels = {
      app = "my-app"
    }
  }

  spec {
    replicas = 3

    selector {
      match_labels = {
        app = "my-app"
      }
    }

    template {
      metadata {
        labels = {
          app = "my-app"
        }
      }

      spec {
        container {
          name  = "app"
          image = "nginx:1.25"

          port {
            container_port = 80
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map.app_config.metadata[0].name
            }
          }

          env {
            name = "DB_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.app_secrets.metadata[0].name
                key  = "db-password"
              }
            }
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 3
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 3
            period_seconds        = 5
          }
        }
      }
    }
  }
}
```

### Services

```hcl
# ClusterIP Service
resource "kubernetes_service" "app" {
  metadata {
    name      = "my-app"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  spec {
    selector = {
      app = kubernetes_deployment.app.spec[0].template[0].metadata[0].labels.app
    }

    port {
      port        = 80
      target_port = 80
    }

    type = "ClusterIP"
  }
}

# LoadBalancer Service
resource "kubernetes_service" "app_lb" {
  metadata {
    name      = "my-app-lb"
    namespace = kubernetes_namespace.app.metadata[0].name

    annotations = {
      "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"
    }
  }

  spec {
    selector = {
      app = kubernetes_deployment.app.spec[0].template[0].metadata[0].labels.app
    }

    port {
      port        = 80
      target_port = 80
    }

    type = "LoadBalancer"
  }
}
```

---

## Part 4: Helm Provider

### Install Ingress Controller with Helm

```hcl
resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true
  version          = "4.8.0"

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "controller.metrics.enabled"
    value = "true"
  }
}
```

### Install with Custom Values

```hcl
resource "helm_release" "prometheus" {
  name             = "prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true

  values = [
    file("${path.module}/prometheus-values.yaml")
  ]

  set {
    name  = "grafana.adminPassword"
    value = var.grafana_password
  }
}
```

**File**: `prometheus-values.yaml`
```yaml
prometheus:
  prometheusSpec:
    retention: 30d
    storageSpec:
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 50Gi

grafana:
  persistence:
    enabled: true
    size: 10Gi
```

### Deploy Application with Helm

```hcl
resource "helm_release" "my_app" {
  name       = "my-app"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "nginx"
  namespace  = kubernetes_namespace.app.metadata[0].name

  values = [
    yamlencode({
      replicaCount = 3
      service = {
        type = "ClusterIP"
      }
      ingress = {
        enabled          = true
        ingressClassName = "nginx"
        hostname         = "app.example.com"
      }
      resources = {
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
      }
    })
  ]

  depends_on = [helm_release.ingress_nginx]
}
```

---

## Part 5: Complete Application Stack

**File**: `complete-app.tf`
```hcl
# Namespace
resource "kubernetes_namespace" "webapp" {
  metadata {
    name = "webapp"
  }
}

# Database Secret
resource "kubernetes_secret" "db" {
  metadata {
    name      = "db-credentials"
    namespace = kubernetes_namespace.webapp.metadata[0].name
  }

  data = {
    username = base64encode("postgres")
    password = base64encode(var.db_password)
  }
}

# PostgreSQL StatefulSet
resource "kubernetes_stateful_set" "postgres" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace.webapp.metadata[0].name
  }

  spec {
    service_name = "postgres"
    replicas     = 1

    selector {
      match_labels = {
        app = "postgres"
      }
    }

    template {
      metadata {
        labels = {
          app = "postgres"
        }
      }

      spec {
        container {
          name  = "postgres"
          image = "postgres:15-alpine"

          port {
            container_port = 5432
          }

          env {
            name  = "POSTGRES_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.db.metadata[0].name
                key  = "username"
              }
            }
          }

          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.db.metadata[0].name
                key  = "password"
              }
            }
          }

          volume_mount {
            name       = "data"
            mount_path = "/var/lib/postgresql/data"
          }
        }
      }
    }

    volume_claim_template {
      metadata {
        name = "data"
      }

      spec {
        access_modes       = ["ReadWriteOnce"]
        storage_class_name = "gp2"

        resources {
          requests = {
            storage = "10Gi"
          }
        }
      }
    }
  }
}

# Database Service
resource "kubernetes_service" "postgres" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace.webapp.metadata[0].name
  }

  spec {
    selector = {
      app = "postgres"
    }

    port {
      port        = 5432
      target_port = 5432
    }

    cluster_ip = "None"  # Headless service
  }
}

# Backend Deployment
resource "kubernetes_deployment" "backend" {
  metadata {
    name      = "backend"
    namespace = kubernetes_namespace.webapp.metadata[0].name
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "backend"
      }
    }

    template {
      metadata {
        labels = {
          app = "backend"
        }
      }

      spec {
        container {
          name  = "backend"
          image = "my-backend:latest"

          env {
            name  = "DATABASE_URL"
            value = "postgresql://$(DB_USER):$(DB_PASS)@postgres:5432/mydb"
          }

          env {
            name = "DB_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.db.metadata[0].name
                key  = "username"
              }
            }
          }

          env {
            name = "DB_PASS"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.db.metadata[0].name
                key  = "password"
              }
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_stateful_set.postgres]
}

# Backend Service
resource "kubernetes_service" "backend" {
  metadata {
    name      = "backend"
    namespace = kubernetes_namespace.webapp.metadata[0].name
  }

  spec {
    selector = {
      app = "backend"
    }

    port {
      port        = 8080
      target_port = 8080
    }
  }
}

# Frontend Deployment
resource "kubernetes_deployment" "frontend" {
  metadata {
    name      = "frontend"
    namespace = kubernetes_namespace.webapp.metadata[0].name
  }

  spec {
    replicas = 3

    selector {
      match_labels = {
        app = "frontend"
      }
    }

    template {
      metadata {
        labels = {
          app = "frontend"
        }
      }

      spec {
        container {
          name  = "frontend"
          image = "nginx:1.25"

          env {
            name  = "API_URL"
            value = "http://backend:8080"
          }
        }
      }
    }
  }
}

# Frontend Service
resource "kubernetes_service" "frontend" {
  metadata {
    name      = "frontend"
    namespace = kubernetes_namespace.webapp.metadata[0].name
  }

  spec {
    selector = {
      app = "frontend"
    }

    port {
      port        = 80
      target_port = 80
    }
  }
}

# Ingress
resource "kubernetes_ingress_v1" "webapp" {
  metadata {
    name      = "webapp"
    namespace = kubernetes_namespace.webapp.metadata[0].name
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      host = "myapp.example.com"

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service.frontend.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.ingress_nginx]
}
```

---

## Part 6: GitOps Patterns

### Outputs for Other Tools

```hcl
output "kubeconfig" {
  description = "kubectl config"
  value       = <<-EOT
    apiVersion: v1
    kind: Config
    clusters:
    - cluster:
        server: ${data.aws_eks_cluster.cluster.endpoint}
        certificate-authority-data: ${data.aws_eks_cluster.cluster.certificate_authority[0].data}
      name: ${var.cluster_name}
    contexts:
    - context:
        cluster: ${var.cluster_name}
        user: ${var.cluster_name}
      name: ${var.cluster_name}
    current-context: ${var.cluster_name}
    users:
    - name: ${var.cluster_name}
      user:
        exec:
          apiVersion: client.authentication.k8s.io/v1beta1
          command: aws
          args:
            - eks
            - get-token
            - --cluster-name
            - ${var.cluster_name}
  EOT
  sensitive   = true
}

output "helm_releases" {
  description = "Deployed Helm releases"
  value = {
    ingress_nginx = helm_release.ingress_nginx.metadata[0].name
    prometheus    = helm_release.prometheus.metadata[0].name
  }
}
```

---

## Hands-On Exercises

### Exercise 1: Deploy WordPress

Use Terraform to deploy WordPress with MySQL:
1. Create namespace
2. Deploy MySQL StatefulSet
3. Deploy WordPress Deployment
4. Expose via LoadBalancer
5. Add persistent storage

### Exercise 2: Monitoring Stack

Deploy complete monitoring:
```hcl
# Prometheus + Grafana
# AlertManager
# Node Exporter
# Configure ServiceMonitors
```

### Exercise 3: Blue-Green Deployment

Create two deployments (blue/green) and switch traffic with Service selector.

---

## Validation Checklist

- [ ] Configure Kubernetes provider with EKS
- [ ] Create namespaces with Terraform
- [ ] Deploy applications with kubernetes provider
- [ ] Use Helm provider to install charts
- [ ] Manage ConfigMaps and Secrets
- [ ] Understand Terraform vs kubectl tradeoffs
- [ ] Implement complete application stack

---

## Key Takeaways

1. **Kubernetes provider** manages K8s resources declaratively
2. **Helm provider** deploys charts with values as code
3. **Use Terraform** for infrastructure and long-lived resources
4. **Use kubectl** for debugging and quick changes
5. **GitOps** works well with Terraform + K8s/Helm providers
6. **Separate concerns**: infrastructure (Terraform) vs applications (Helm/kubectl)

---

## Additional Resources

- [Terraform Kubernetes Provider](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs)
- [Terraform Helm Provider](https://registry.terraform.io/providers/hashicorp/helm/latest/docs)
- [Kubernetes API Reference](https://kubernetes.io/docs/reference/kubernetes-api/)

---

## Next Steps

**Ready for multi-environment?** → [Module 04: Multi-Environment Patterns](../04-multi-environment/README.md)
