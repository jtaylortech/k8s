# Staging Environment Outputs

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

output "loadbalancer_hostname" {
  description = "LoadBalancer hostname"
  value       = module.app.loadbalancer_hostname
}

output "kubectl_get_pods" {
  description = "Command to view pods"
  value       = "kubectl get pods -n ${module.app.namespace}"
}

output "kubectl_get_hpa" {
  description = "Command to view HPA"
  value       = "kubectl get hpa -n ${module.app.namespace}"
}

output "kubectl_logs" {
  description = "Command to view logs"
  value       = "kubectl logs -n ${module.app.namespace} -l app=${var.app_name} --tail=100 -f"
}

output "access_instructions" {
  description = "How to access the application"
  value       = <<-EOT
    Staging environment uses LoadBalancer.

    1. Wait for LoadBalancer to provision:
       kubectl get svc -n ${module.app.namespace} -w

    2. Get LoadBalancer URL:
       export LB_URL=$(kubectl get svc ${module.app.service_name} -n ${module.app.namespace} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

    3. Test the application:
       curl http://$LB_URL

    4. View HPA status:
       ${self.kubectl_get_hpa}

    LoadBalancer hostname: ${module.app.loadbalancer_hostname}
  EOT
}
