# Outputs - Information about deployed resources

# =============================================================================
# Namespace Information
# =============================================================================

output "namespace" {
  description = "Namespace where application is deployed"
  value       = kubernetes_namespace.app.metadata[0].name
}

# =============================================================================
# Application Information
# =============================================================================

output "deployment_name" {
  description = "Name of the Kubernetes deployment"
  value       = kubernetes_deployment.app.metadata[0].name
}

output "service_name" {
  description = "Name of the Kubernetes service"
  value       = kubernetes_service.app.metadata[0].name
}

output "configmap_name" {
  description = "Name of the ConfigMap"
  value       = kubernetes_config_map.app.metadata[0].name
}

output "secret_name" {
  description = "Name of the Secret"
  value       = kubernetes_secret.app.metadata[0].name
  sensitive   = true
}

# =============================================================================
# Service Access Information
# =============================================================================

output "service_type" {
  description = "Type of Kubernetes service"
  value       = kubernetes_service.app.spec[0].type
}

output "service_port" {
  description = "Service port"
  value       = kubernetes_service.app.spec[0].port[0].port
}

# LoadBalancer hostname (if service type is LoadBalancer)
output "loadbalancer_hostname" {
  description = "LoadBalancer hostname (if service type is LoadBalancer)"
  value = var.service_type == "LoadBalancer" ? (
    length(kubernetes_service.app.status[0].load_balancer[0].ingress) > 0 ?
    kubernetes_service.app.status[0].load_balancer[0].ingress[0].hostname : "Pending..."
  ) : "N/A - Service type is not LoadBalancer"
}

# LoadBalancer IP (if assigned)
output "loadbalancer_ip" {
  description = "LoadBalancer IP (if assigned)"
  value = var.service_type == "LoadBalancer" ? (
    length(kubernetes_service.app.status[0].load_balancer[0].ingress) > 0 ?
    try(kubernetes_service.app.status[0].load_balancer[0].ingress[0].ip, "Hostname-based LB") : "Pending..."
  ) : "N/A - Service type is not LoadBalancer"
}

# =============================================================================
# Autoscaling Information
# =============================================================================

output "hpa_enabled" {
  description = "Whether Horizontal Pod Autoscaler is enabled"
  value       = var.enable_autoscaling
}

output "hpa_name" {
  description = "Name of the HPA resource (if enabled)"
  value       = var.enable_autoscaling ? kubernetes_horizontal_pod_autoscaler_v2.app[0].metadata[0].name : "N/A - HPA disabled"
}

output "hpa_scaling_range" {
  description = "HPA scaling range (if enabled)"
  value       = var.enable_autoscaling ? "${var.hpa_min_replicas}-${var.hpa_max_replicas} replicas" : "N/A - HPA disabled"
}

# =============================================================================
# Helm Release Information
# =============================================================================

output "ingress_nginx_installed" {
  description = "Whether NGINX Ingress Controller is installed"
  value       = var.install_ingress_nginx
}

output "ingress_nginx_status" {
  description = "NGINX Ingress Controller deployment status"
  value       = var.install_ingress_nginx ? helm_release.ingress_nginx[0].status : "N/A - Not installed"
}

output "ingress_nginx_version" {
  description = "NGINX Ingress Controller version"
  value       = var.install_ingress_nginx ? helm_release.ingress_nginx[0].version : "N/A - Not installed"
}

# Ingress Controller LoadBalancer (for external access)
output "ingress_controller_hostname" {
  description = "NGINX Ingress Controller LoadBalancer hostname"
  value = var.install_ingress_nginx ? (
    "Run: kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
  ) : "N/A - NGINX Ingress not installed"
}

# =============================================================================
# Kubectl Commands
# =============================================================================

output "kubectl_get_pods" {
  description = "Command to view pods"
  value       = "kubectl get pods -n ${kubernetes_namespace.app.metadata[0].name}"
}

output "kubectl_get_service" {
  description = "Command to view service details"
  value       = "kubectl get svc ${kubernetes_service.app.metadata[0].name} -n ${kubernetes_namespace.app.metadata[0].name}"
}

output "kubectl_describe_deployment" {
  description = "Command to describe deployment"
  value       = "kubectl describe deployment ${kubernetes_deployment.app.metadata[0].name} -n ${kubernetes_namespace.app.metadata[0].name}"
}

output "kubectl_logs" {
  description = "Command to view application logs"
  value       = "kubectl logs -n ${kubernetes_namespace.app.metadata[0].name} -l app=${var.app_name} --tail=100 -f"
}

output "kubectl_port_forward" {
  description = "Command to port-forward to the service (for testing)"
  value       = "kubectl port-forward -n ${kubernetes_namespace.app.metadata[0].name} svc/${kubernetes_service.app.metadata[0].name} 8080:80"
}

# =============================================================================
# Next Steps
# =============================================================================

output "next_steps" {
  description = "What to do next"
  value       = <<-EOT
    ✅ Application deployed successfully!

    📋 Check deployment status:
       ${self.kubectl_get_pods}
       ${self.kubectl_get_service}

    🔍 View logs:
       ${self.kubectl_logs}

    🌐 Access application:
       ${var.service_type == "LoadBalancer" ? "Wait for LoadBalancer to provision, then access via: http://<LOADBALANCER_HOSTNAME>" : ""}
       ${var.service_type == "ClusterIP" ? "Use port-forward for local access: ${self.kubectl_port_forward}" : ""}

    📊 View HPA status (if enabled):
       kubectl get hpa -n ${kubernetes_namespace.app.metadata[0].name}

    🎯 View Ingress Controller (if installed):
       kubectl get svc -n ingress-nginx

    🧹 Clean up when done:
       terraform destroy
  EOT
}

# =============================================================================
# Testing Commands
# =============================================================================

output "test_commands" {
  description = "Commands to test the application"
  value = var.service_type == "LoadBalancer" ? <<-EOT
    # Wait for LoadBalancer to provision
    kubectl get svc ${kubernetes_service.app.metadata[0].name} -n ${kubernetes_namespace.app.metadata[0].name} -w

    # Get LoadBalancer URL
    export LB_URL=$(kubectl get svc ${kubernetes_service.app.metadata[0].name} -n ${kubernetes_namespace.app.metadata[0].name} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

    # Test the application
    curl http://$LB_URL/
    curl http://$LB_URL/health

    # Load test (requires 'hey' or 'ab' tool)
    hey -z 60s -c 50 http://$LB_URL/
  EOT : <<-EOT
    # Use port-forward to access the application locally
    kubectl port-forward -n ${kubernetes_namespace.app.metadata[0].name} svc/${kubernetes_service.app.metadata[0].name} 8080:80 &

    # Test the application
    curl http://localhost:8080/
    curl http://localhost:8080/health

    # Stop port-forward
    kill %1
  EOT
}
