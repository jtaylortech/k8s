# Main Kubernetes Resources
# This file demonstrates how to manage K8s resources using Terraform

# =============================================================================
# Namespace
# =============================================================================

# Create a dedicated namespace for our application
# Namespaces provide logical separation and resource isolation
resource "kubernetes_namespace" "app" {
  metadata {
    name = var.namespace

    labels = merge(
      var.common_labels,
      {
        name        = var.namespace
        environment = var.environment
      }
    )

    # Annotations can be used for additional metadata
    annotations = {
      "description" = "Namespace for ${var.app_name} application"
      "managed-by"  = "terraform"
    }
  }
}

# =============================================================================
# ConfigMap
# =============================================================================

# ConfigMaps store non-sensitive configuration data
# This example stores application configuration
resource "kubernetes_config_map" "app" {
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

  # Configuration data as key-value pairs
  data = {
    # Application-specific config
    "app.name"        = var.app_name
    "app.environment" = var.environment
    "app.version"     = "1.0.0"

    # Feature flags
    "feature.logging.enabled" = "true"
    "feature.logging.level"   = var.environment == "prod" ? "info" : "debug"

    # Example Nginx configuration
    "nginx.conf" = <<-EOT
      server {
          listen ${var.app_port};
          server_name _;

          location / {
              root /usr/share/nginx/html;
              index index.html;
          }

          location /health {
              access_log off;
              return 200 "healthy\n";
              add_header Content-Type text/plain;
          }
      }
    EOT
  }
}

# =============================================================================
# Secret (Example - Never commit real secrets to Git!)
# =============================================================================

# Secrets store sensitive data (base64 encoded in K8s)
# IMPORTANT: Use external secret management in production (AWS Secrets Manager, Vault, etc.)
resource "kubernetes_secret" "app" {
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

  # Type can be: Opaque, kubernetes.io/service-account-token, kubernetes.io/dockerconfigjson, etc.
  type = "Opaque"

  # Example secrets (these are just examples!)
  data = {
    # Terraform automatically base64 encodes these values
    "api-key"      = "demo-api-key-not-real"
    "db-password"  = "demo-password-not-real"
    "db-username"  = "demo-user"
    "redis-url"    = "redis://redis-service:6379"
  }
}

# =============================================================================
# Deployment
# =============================================================================

# Deployment manages a replicated application
# It ensures the desired number of pods are always running
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

    annotations = {
      "deployment.kubernetes.io/revision" = "1"
    }
  }

  spec {
    # Number of pod replicas (if HPA is enabled, it will override this)
    replicas = var.enable_autoscaling ? null : var.app_replicas

    # Selector determines which pods belong to this deployment
    selector {
      match_labels = {
        app         = var.app_name
        environment = var.environment
      }
    }

    # Pod template - defines what each pod looks like
    template {
      metadata {
        labels = merge(
          var.common_labels,
          {
            app         = var.app_name
            environment = var.environment
            version     = "1.0.0"
          }
        )

        annotations = {
          # Prometheus scraping annotations (if using Prometheus)
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = tostring(var.app_port)
          "prometheus.io/path"   = "/metrics"
        }
      }

      spec {
        # Container specification
        container {
          name  = var.app_name
          image = var.app_image

          # Container port
          port {
            name           = "http"
            container_port = var.app_port
            protocol       = "TCP"
          }

          # Resource requests and limits
          # Requests: guaranteed resources
          # Limits: maximum resources the container can use
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

          # Liveness probe - determines if container is alive
          # If fails, K8s will restart the container
          liveness_probe {
            http_get {
              path = "/health"
              port = var.app_port
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          # Readiness probe - determines if container is ready to serve traffic
          # If fails, K8s removes pod from service endpoints
          readiness_probe {
            http_get {
              path = "/health"
              port = var.app_port
            }
            initial_delay_seconds = 10
            period_seconds        = 5
            timeout_seconds       = 3
            failure_threshold     = 3
          }

          # Environment variables from ConfigMap
          env {
            name = "APP_NAME"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.app.metadata[0].name
                key  = "app.name"
              }
            }
          }

          env {
            name = "ENVIRONMENT"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.app.metadata[0].name
                key  = "app.environment"
              }
            }
          }

          # Environment variables from Secret
          env {
            name = "API_KEY"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.app.metadata[0].name
                key  = "api-key"
              }
            }
          }

          env {
            name = "DB_USERNAME"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.app.metadata[0].name
                key  = "db-username"
              }
            }
          }

          env {
            name = "DB_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.app.metadata[0].name
                key  = "db-password"
              }
            }
          }

          # Mount ConfigMap as volume (for nginx.conf example)
          # volume_mount {
          #   name       = "config-volume"
          #   mount_path = "/etc/nginx/conf.d"
          #   read_only  = true
          # }
        }

        # Volume definition for ConfigMap
        # volume {
        #   name = "config-volume"
        #   config_map {
        #     name = kubernetes_config_map.app.metadata[0].name
        #     items {
        #       key  = "nginx.conf"
        #       path = "default.conf"
        #     }
        #   }
        # }

        # Restart policy
        restart_policy = "Always"

        # DNS policy
        dns_policy = "ClusterFirst"

        # Security context (pod-level)
        security_context {
          # Run as non-root user
          run_as_non_root = true
          run_as_user     = 1000
          fs_group        = 1000
        }
      }
    }

    # Deployment strategy
    strategy {
      type = "RollingUpdate"

      rolling_update {
        # Maximum number of pods that can be unavailable during update
        max_unavailable = "1"
        # Maximum number of pods that can be created over desired replicas
        max_surge = "1"
      }
    }

    # Minimum time for which a newly created pod should be ready
    min_ready_seconds = 10

    # Number of old ReplicaSets to retain for rollback
    revision_history_limit = 10

    # Gradually increase time between restarts if pod fails repeatedly
    progress_deadline_seconds = 600
  }

  # Prevent recreation of deployment on changes to replicas (HPA manages this)
  lifecycle {
    ignore_changes = var.enable_autoscaling ? [spec[0].replicas] : []
  }
}

# =============================================================================
# Service
# =============================================================================

# Service exposes the deployment to network traffic
# It provides a stable endpoint for accessing pods
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

    # Annotations for AWS Load Balancer Controller (if using LoadBalancer type)
    annotations = var.service_type == "LoadBalancer" ? {
      # Use Network Load Balancer (faster, Layer 4)
      "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"

      # Enable cross-zone load balancing
      "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = "true"

      # Use internal load balancer (remove for public)
      # "service.beta.kubernetes.io/aws-load-balancer-internal" = "true"

      # Health check configuration
      "service.beta.kubernetes.io/aws-load-balancer-healthcheck-path" = "/health"
    } : {}
  }

  spec {
    # Service type: ClusterIP (internal), NodePort (node IP:port), LoadBalancer (cloud LB)
    type = var.service_type

    # Selector determines which pods receive traffic
    # Must match deployment's pod labels
    selector = {
      app         = var.app_name
      environment = var.environment
    }

    # Port configuration
    port {
      name        = "http"
      port        = 80              # Service port (what clients connect to)
      target_port = var.app_port    # Container port (where traffic is forwarded)
      protocol    = "TCP"

      # NodePort (only used if service_type is NodePort or LoadBalancer)
      # If not specified, K8s assigns a random port from 30000-32767
      # node_port = 30080
    }

    # Session affinity - route requests from same client to same pod
    # Options: None, ClientIP
    session_affinity = "None"

    # Preserve client source IP
    # external_traffic_policy = "Local"  # Only for NodePort/LoadBalancer
  }
}

# =============================================================================
# Horizontal Pod Autoscaler (HPA)
# =============================================================================

# HPA automatically scales the number of pods based on metrics
# Requires metrics-server to be installed in the cluster
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
    # Target deployment to scale
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.app.metadata[0].name
    }

    # Scaling bounds
    min_replicas = var.hpa_min_replicas
    max_replicas = var.hpa_max_replicas

    # Metrics to scale on
    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = var.hpa_cpu_threshold
        }
      }
    }

    # Optional: Scale on memory as well
    # metric {
    #   type = "Resource"
    #   resource {
    #     name = "memory"
    #     target {
    #       type                = "Utilization"
    #       average_utilization = 80
    #     }
    #   }
    # }

    # Scaling behavior - controls how fast HPA scales up/down
    behavior {
      scale_up {
        stabilization_window_seconds = 60  # Wait 60s before scaling up again
        select_policy                = "Max"
        policy {
          type          = "Pods"
          value         = 2                # Add max 2 pods at a time
          period_seconds = 60
        }
        policy {
          type          = "Percent"
          value         = 50               # Or scale up by max 50% at a time
          period_seconds = 60
        }
      }

      scale_down {
        stabilization_window_seconds = 300  # Wait 5min before scaling down
        select_policy                = "Min"
        policy {
          type          = "Pods"
          value         = 1                 # Remove max 1 pod at a time
          period_seconds = 60
        }
        policy {
          type          = "Percent"
          value         = 10                # Or scale down by max 10% at a time
          period_seconds = 60
        }
      }
    }
  }

  depends_on = [
    kubernetes_deployment.app
  ]
}
