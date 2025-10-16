# Outputs - important information after cluster creation

# Cluster Information
output "cluster_id" {
  description = "EKS cluster ID"
  value       = aws_eks_cluster.main.id
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_version" {
  description = "Kubernetes version running on cluster"
  value       = aws_eks_cluster.main.version
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "cluster_iam_role_arn" {
  description = "IAM role ARN of the EKS cluster"
  value       = aws_eks_cluster.main.role_arn
}

# Network Information
output "vpc_id" {
  description = "VPC ID where cluster is deployed"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

# Node Group Information
output "node_group_id" {
  description = "EKS node group ID"
  value       = aws_eks_node_group.main.id
}

output "node_group_status" {
  description = "Status of the EKS node group"
  value       = aws_eks_node_group.main.status
}

output "node_iam_role_arn" {
  description = "IAM role ARN of the EKS node group"
  value       = aws_iam_role.node.arn
}

# kubectl Configuration
output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main.name}"
}

output "kubeconfig" {
  description = "kubectl config file contents"
  value       = <<-EOT
    apiVersion: v1
    kind: Config
    clusters:
    - cluster:
        server: ${aws_eks_cluster.main.endpoint}
        certificate-authority-data: ${aws_eks_cluster.main.certificate_authority[0].data}
      name: ${aws_eks_cluster.main.name}
    contexts:
    - context:
        cluster: ${aws_eks_cluster.main.name}
        user: ${aws_eks_cluster.main.name}
      name: ${aws_eks_cluster.main.name}
    current-context: ${aws_eks_cluster.main.name}
    users:
    - name: ${aws_eks_cluster.main.name}
      user:
        exec:
          apiVersion: client.authentication.k8s.io/v1beta1
          command: aws
          args:
            - eks
            - get-token
            - --cluster-name
            - ${aws_eks_cluster.main.name}
            - --region
            - ${var.aws_region}
  EOT
  sensitive   = true
}

# Cost Estimation
output "estimated_monthly_cost" {
  description = "Estimated monthly cost (approximate)"
  value       = <<-EOT
    EKS Control Plane: ~$73/month
    Worker Nodes (${var.node_desired_size}x ${var.node_instance_types[0]}): ~$${var.node_desired_size * 60}/month
    NAT Gateways (${var.azs_count}): ~$${var.azs_count * 32}/month
    Total: ~$${73 + (var.node_desired_size * 60) + (var.azs_count * 32)}/month

    Note: This is an estimate. Actual costs vary by region and usage.
  EOT
}

# Next Steps
output "next_steps" {
  description = "What to do next"
  value       = <<-EOT
    1. Configure kubectl:
       ${self.configure_kubectl}

    2. Verify cluster:
       kubectl get nodes
       kubectl get pods -A

    3. Deploy test app:
       kubectl create deployment nginx --image=nginx
       kubectl expose deployment nginx --port=80 --type=LoadBalancer

    4. When done, destroy to avoid costs:
       terraform destroy
  EOT
}
