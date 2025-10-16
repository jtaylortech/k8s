# Development Environment Outputs

output "namespace" {
  description = "Application namespace"
  value       = module.app.namespace
}

output "deployment_name" {
  description = "Deployment name"
  value       = module.app.deployment_name
}

output "service_name" {
  description = "Service name"
  value       = module.app.service_name
}

output "service_type" {
  description = "Service type"
  value       = module.app.service_type
}

output "kubectl_get_pods" {
  description = "Command to view pods"
  value       = "kubectl get pods -n ${module.app.namespace}"
}

output "kubectl_logs" {
  description = "Command to view logs"
  value       = "kubectl logs -n ${module.app.namespace} -l app=${var.app_name} --tail=100 -f"
}

output "kubectl_port_forward" {
  description = "Command to port-forward (since using ClusterIP)"
  value       = "kubectl port-forward -n ${module.app.namespace} svc/${module.app.service_name} 8080:80"
}

output "access_instructions" {
  description = "How to access the application"
  value       = <<-EOT
    Development environment uses ClusterIP (no LoadBalancer).

    To access the application:
    1. Port forward: ${self.kubectl_port_forward}
    2. In another terminal: curl http://localhost:8080

    To view logs: ${self.kubectl_logs}
  EOT
}
