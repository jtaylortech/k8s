# Helm Chart Deployments
# This file demonstrates how to deploy Helm charts using Terraform

# =============================================================================
# NGINX Ingress Controller
# =============================================================================

# Deploy NGINX Ingress Controller using Helm
# Ingress controllers route external HTTP/HTTPS traffic to services
resource "helm_release" "ingress_nginx" {
  count = var.install_ingress_nginx ? 1 : 0

  # Release name in K8s
  name = "ingress-nginx"

  # Helm repository configuration
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = var.ingress_nginx_version

  # Install into dedicated namespace
  namespace        = "ingress-nginx"
  create_namespace = true

  # Wait for all resources to be ready before marking as successful
  wait          = true
  wait_for_jobs = true
  timeout       = 600  # 10 minutes

  # Atomic ensures rollback on failure
  atomic = true

  # Cleanup on delete
  cleanup_on_fail = true

  # Values to customize the Helm chart
  # These override default values in the chart's values.yaml
  values = [
    yamlencode({
      controller = {
        # Replica count for high availability
        replicaCount = 2

        # Resource requests and limits
        resources = {
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "256Mi"
          }
        }

        # Service configuration
        service = {
          type = "LoadBalancer"

          annotations = {
            # AWS Load Balancer Controller annotations
            "service.beta.kubernetes.io/aws-load-balancer-type"                              = "nlb"
            "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = "true"
            "service.beta.kubernetes.io/aws-load-balancer-backend-protocol"                  = "tcp"

            # Enable PROXY protocol for client IP preservation
            "service.beta.kubernetes.io/aws-load-balancer-proxy-protocol" = "*"

            # SSL certificate ARN (if using HTTPS)
            # "service.beta.kubernetes.io/aws-load-balancer-ssl-cert" = "arn:aws:acm:region:account:certificate/id"
          }
        }

        # Metrics for monitoring
        metrics = {
          enabled = true
          serviceMonitor = {
            enabled = false  # Enable if using Prometheus Operator
          }
        }

        # Pod anti-affinity - spread replicas across nodes
        affinity = {
          podAntiAffinity = {
            preferredDuringSchedulingIgnoredDuringExecution = [
              {
                weight = 100
                podAffinityTerm = {
                  labelSelector = {
                    matchExpressions = [
                      {
                        key      = "app.kubernetes.io/name"
                        operator = "In"
                        values   = ["ingress-nginx"]
                      }
                    ]
                  }
                  topologyKey = "kubernetes.io/hostname"
                }
              }
            ]
          }
        }

        # Autoscaling
        autoscaling = {
          enabled     = true
          minReplicas = 2
          maxReplicas = 10
          targetCPUUtilizationPercentage    = 80
          targetMemoryUtilizationPercentage = 80
        }

        # Configuration for the ingress controller
        config = {
          # Enable PROXY protocol
          "use-proxy-protocol" = "true"

          # Increase body size limit
          "proxy-body-size" = "100m"

          # SSL configuration
          "ssl-protocols" = "TLSv1.2 TLSv1.3"
          "ssl-ciphers"   = "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256"

          # Client source IP preservation
          "use-forwarded-headers" = "true"
          "compute-full-forwarded-for" = "true"

          # Rate limiting (requests per second per IP)
          # "limit-rps" = "100"

          # Enable real IP from proxy
          "enable-real-ip" = "true"
        }
      }

      # Default backend (serves 404 for unknown routes)
      defaultBackend = {
        enabled = true
        replicaCount = 1
        resources = {
          requests = {
            cpu    = "10m"
            memory = "20Mi"
          }
          limits = {
            cpu    = "20m"
            memory = "40Mi"
          }
        }
      }
    })
  ]

  # Additional individual values (alternative to values block above)
  # set {
  #   name  = "controller.replicaCount"
  #   value = "2"
  # }

  # Set sensitive values (won't show in plan output)
  # set_sensitive {
  #   name  = "controller.config.ssl-certificate"
  #   value = var.ssl_certificate
  # }
}

# =============================================================================
# Example: Deploy Application using Helm
# =============================================================================

# This shows how you might deploy your own Helm chart
# Uncomment if you have a Helm chart for your application

# resource "helm_release" "app" {
#   name       = var.app_name
#   namespace  = kubernetes_namespace.app.metadata[0].name
#
#   # If using a public chart repository
#   repository = "https://charts.example.com"
#   chart      = "myapp"
#   version    = "1.0.0"
#
#   # Or if using a local chart directory
#   # chart = "${path.module}/charts/myapp"
#
#   values = [
#     yamlencode({
#       image = {
#         repository = "myregistry/myapp"
#         tag        = "1.0.0"
#         pullPolicy = "IfNotPresent"
#       }
#
#       replicaCount = var.app_replicas
#
#       service = {
#         type = "ClusterIP"
#         port = 80
#       }
#
#       ingress = {
#         enabled   = true
#         className = "nginx"
#         hosts = [
#           {
#             host = "myapp.example.com"
#             paths = [
#               {
#                 path     = "/"
#                 pathType = "Prefix"
#               }
#             ]
#           }
#         ]
#       }
#
#       resources = {
#         requests = {
#           cpu    = var.cpu_request
#           memory = var.memory_request
#         }
#         limits = {
#           cpu    = var.cpu_limit
#           memory = var.memory_limit
#         }
#       }
#
#       autoscaling = {
#         enabled                        = var.enable_autoscaling
#         minReplicas                    = var.hpa_min_replicas
#         maxReplicas                    = var.hpa_max_replicas
#         targetCPUUtilizationPercentage = var.hpa_cpu_threshold
#       }
#     })
#   ]
#
#   depends_on = [
#     helm_release.ingress_nginx
#   ]
# }

# =============================================================================
# Example: Metrics Server (Required for HPA)
# =============================================================================

# Metrics Server collects resource metrics from Kubelets
# Required for Horizontal Pod Autoscaler to work

# resource "helm_release" "metrics_server" {
#   name       = "metrics-server"
#   repository = "https://kubernetes-sigs.github.io/metrics-server/"
#   chart      = "metrics-server"
#   version    = "3.11.0"
#
#   namespace        = "kube-system"
#   create_namespace = false
#
#   values = [
#     yamlencode({
#       args = [
#         "--kubelet-preferred-address-types=InternalIP"
#       ]
#
#       resources = {
#         requests = {
#           cpu    = "100m"
#           memory = "200Mi"
#         }
#       }
#     })
#   ]
# }
