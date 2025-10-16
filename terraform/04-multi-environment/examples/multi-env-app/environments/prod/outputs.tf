# Production Environment Outputs

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

output "hpa_name" {
  description = "HPA name"
  value       = module.app.hpa_name
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

output "kubectl_top_pods" {
  description = "Command to view resource usage"
  value       = "kubectl top pods -n ${module.app.namespace}"
}

output "access_instructions" {
  description = "How to access the application"
  value       = <<-EOT
    Production environment - LoadBalancer with high availability.

    1. Wait for LoadBalancer to provision:
       kubectl get svc -n ${module.app.namespace} -w

    2. Get LoadBalancer URL:
       export LB_URL=$(kubectl get svc ${module.app.service_name} -n ${module.app.namespace} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

    3. Test the application:
       curl http://$LB_URL

    4. Monitor the deployment:
       ${self.kubectl_get_pods}
       ${self.kubectl_get_hpa}
       ${self.kubectl_top_pods}

    5. View logs:
       ${self.kubectl_logs}

    LoadBalancer hostname: ${module.app.loadbalancer_hostname}

    PRODUCTION NOTICE:
    - Minimum 3 replicas running
    - Autoscaling enabled (3-20 replicas)
    - PodDisruptionBudget ensures 2+ pods during updates
    - Consider adding DNS CNAME to point to LoadBalancer
  EOT
}

output "monitoring_endpoints" {
  description = "Monitoring and observability endpoints"
  value       = <<-EOT
    Metrics: http://${module.app.loadbalancer_hostname}/metrics
    Health:  http://${module.app.loadbalancer_hostname}${var.health_check_path}

    Configure alerts for:
    - Pod restarts
    - High CPU/memory usage
    - Failed health checks
    - HPA at max replicas
  EOT
}
