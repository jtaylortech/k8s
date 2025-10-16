# Module Outputs
# These values are returned to the calling environment

output "namespace" {
  description = "Namespace where application is deployed"
  value       = kubernetes_namespace.app.metadata[0].name
}

output "deployment_name" {
  description = "Name of the deployment"
  value       = kubernetes_deployment.app.metadata[0].name
}

output "service_name" {
  description = "Name of the service"
  value       = kubernetes_service.app.metadata[0].name
}

output "service_type" {
  description = "Type of service"
  value       = kubernetes_service.app.spec[0].type
}

output "loadbalancer_hostname" {
  description = "LoadBalancer hostname (if applicable)"
  value = var.service_type == "LoadBalancer" ? (
    length(kubernetes_service.app.status[0].load_balancer[0].ingress) > 0 ?
    try(kubernetes_service.app.status[0].load_balancer[0].ingress[0].hostname, "Pending...") : "Pending..."
  ) : null
}

output "configmap_name" {
  description = "Name of the ConfigMap (if created)"
  value       = length(var.config_data) > 0 ? kubernetes_config_map.app[0].metadata[0].name : null
}

output "secret_name" {
  description = "Name of the Secret (if created)"
  value       = length(var.secret_data) > 0 ? kubernetes_secret.app[0].metadata[0].name : null
  sensitive   = true
}

output "hpa_enabled" {
  description = "Whether HPA is enabled"
  value       = var.enable_autoscaling
}

output "hpa_name" {
  description = "Name of the HPA (if enabled)"
  value       = var.enable_autoscaling ? kubernetes_horizontal_pod_autoscaler_v2.app[0].metadata[0].name : null
}

output "app_labels" {
  description = "Labels applied to application resources"
  value = {
    app         = var.app_name
    environment = var.environment
  }
}
