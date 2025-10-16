# Reusable Kubernetes Application Module
# This module can be called multiple times with different configurations

# Get EKS cluster information
data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = var.cluster_name
}

# =============================================================================
# Namespace
# =============================================================================

resource "kubernetes_namespace" "app" {
  metadata {
    name = var.namespace

    labels = merge(
      var.common_labels,
      {
        name        = var.namespace
        environment = var.environment
        app         = var.app_name
      }
    )
  }
}

# =============================================================================
# ConfigMap
# =============================================================================

resource "kubernetes_config_map" "app" {
  count = length(var.config_data) > 0 ? 1 : 0

  metadata {
    name      = "${var.app_name}-config"
    namespace = kubernetes_namespace.app.metadata[0].name

    labels = merge(
      var.common_labels,
      {
        app         = var.app_name
        environment = var.environment
      }
    )
  }

  data = merge(
    var.config_data,
    {
      "app.name"        = var.app_name
      "app.environment" = var.environment
    }
  )
}

# =============================================================================
# Secret
# =============================================================================

resource "kubernetes_secret" "app" {
  count = length(var.secret_data) > 0 ? 1 : 0

  metadata {
    name      = "${var.app_name}-secrets"
    namespace = kubernetes_namespace.app.metadata[0].name

    labels = merge(
      var.common_labels,
      {
        app         = var.app_name
        environment = var.environment
      }
    )
  }

  type = "Opaque"
  data = var.secret_data
}

# =============================================================================
# Deployment
# =============================================================================

resource "kubernetes_deployment" "app" {
  metadata {
    name      = var.app_name
    namespace = kubernetes_namespace.app.metadata[0].name

    labels = merge(
      var.common_labels,
      {
        app         = var.app_name
        environment = var.environment
      }
    )
  }

  spec {
    replicas = var.enable_autoscaling ? null : var.replicas

    selector {
      match_labels = {
        app         = var.app_name
        environment = var.environment
      }
    }

    template {
      metadata {
        labels = merge(
          var.common_labels,
          {
            app         = var.app_name
            environment = var.environment
          }
        )

        annotations = merge(
          var.pod_annotations,
          {
            "prometheus.io/scrape" = "true"
            "prometheus.io/port"   = tostring(var.container_port)
          }
        )
      }

      spec {
        container {
          name  = var.app_name
          image = "${var.image_repository}:${var.image_tag}"

          port {
            name           = "http"
            container_port = var.container_port
            protocol       = "TCP"
          }

          # Resource requests and limits
          resources {
            requests = {
              cpu    = var.cpu_request
              memory = var.memory_request
            }
            limits = {
              cpu    = var.cpu_limit
              memory = var.memory_limit
            }
          }

          # Liveness probe
          liveness_probe {
            http_get {
              path = var.health_check_path
              port = var.container_port
            }
            initial_delay_seconds = var.liveness_initial_delay
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          # Readiness probe
          readiness_probe {
            http_get {
              path = var.health_check_path
              port = var.container_port
            }
            initial_delay_seconds = var.readiness_initial_delay
            period_seconds        = 5
            timeout_seconds       = 3
            failure_threshold     = 3
          }

          # Environment variables from ConfigMap
          dynamic "env" {
            for_each = length(var.config_data) > 0 ? var.config_data : {}
            content {
              name = upper(replace(env.key, ".", "_"))
              value_from {
                config_map_key_ref {
                  name = kubernetes_config_map.app[0].metadata[0].name
                  key  = env.key
                }
              }
            }
          }

          # Environment variables from Secret
          dynamic "env" {
            for_each = length(var.secret_data) > 0 ? var.secret_data : {}
            content {
              name = upper(replace(env.key, ".", "_"))
              value_from {
                secret_key_ref {
                  name = kubernetes_secret.app[0].metadata[0].name
                  key  = env.key
                }
              }
            }
          }

          # Additional environment variables
          dynamic "env" {
            for_each = var.env_vars
            content {
              name  = env.key
              value = env.value
            }
          }

          # Standard environment variables
          env {
            name  = "APP_NAME"
            value = var.app_name
          }

          env {
            name  = "ENVIRONMENT"
            value = var.environment
          }

          env {
            name = "POD_NAME"
            value_from {
              field_ref {
                field_path = "metadata.name"
              }
            }
          }

          env {
            name = "POD_NAMESPACE"
            value_from {
              field_ref {
                field_path = "metadata.namespace"
              }
            }
          }
        }

        # Security context
        security_context {
          run_as_non_root = true
          run_as_user     = 1000
          fs_group        = 1000
        }

        restart_policy = "Always"
      }
    }

    strategy {
      type = "RollingUpdate"
      rolling_update {
        max_unavailable = "25%"
        max_surge       = "25%"
      }
    }
  }

  lifecycle {
    ignore_changes = var.enable_autoscaling ? [spec[0].replicas] : []
  }
}

# =============================================================================
# Service
# =============================================================================

resource "kubernetes_service" "app" {
  metadata {
    name      = var.app_name
    namespace = kubernetes_namespace.app.metadata[0].name

    labels = merge(
      var.common_labels,
      {
        app         = var.app_name
        environment = var.environment
      }
    )

    annotations = var.service_type == "LoadBalancer" ? {
      "service.beta.kubernetes.io/aws-load-balancer-type"                              = "nlb"
      "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = "true"
    } : {}
  }

  spec {
    type = var.service_type

    selector = {
      app         = var.app_name
      environment = var.environment
    }

    port {
      name        = "http"
      port        = var.service_port
      target_port = var.container_port
      protocol    = "TCP"
    }

    session_affinity = "None"
  }
}

# =============================================================================
# Horizontal Pod Autoscaler
# =============================================================================

resource "kubernetes_horizontal_pod_autoscaler_v2" "app" {
  count = var.enable_autoscaling ? 1 : 0

  metadata {
    name      = "${var.app_name}-hpa"
    namespace = kubernetes_namespace.app.metadata[0].name

    labels = merge(
      var.common_labels,
      {
        app         = var.app_name
        environment = var.environment
      }
    )
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.app.metadata[0].name
    }

    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = var.cpu_threshold
        }
      }
    }

    behavior {
      scale_up {
        stabilization_window_seconds = 60
        select_policy                = "Max"
        policy {
          type          = "Pods"
          value         = 2
          period_seconds = 60
        }
      }

      scale_down {
        stabilization_window_seconds = 300
        select_policy                = "Min"
        policy {
          type          = "Pods"
          value         = 1
          period_seconds = 60
        }
      }
    }
  }

  depends_on = [kubernetes_deployment.app]
}
