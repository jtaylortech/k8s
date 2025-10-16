# Module 02: Provisioning Kubernetes Clusters

**Duration**: ~4 hours
**Prerequisites**: [Module 01: Terraform Fundamentals](../01-terraform-fundamentals/README.md)
**Next Module**: [03-Managing K8s Resources](../03-managing-k8s-resources/README.md)
**Cost**: ~$0.10/hour for control plane + worker nodes (~$2-5 for this module)
**Primary Focus**: AWS EKS

## Learning Objectives

By the end of this module, you will:
- ✅ Provision a production-ready EKS cluster with Terraform
- ✅ Configure VPC networking for Kubernetes
- ✅ Set up IAM roles and policies
- ✅ Deploy managed node groups with autoscaling
- ✅ Install essential add-ons (VPC CNI, CoreDNS, kube-proxy)
- ✅ Configure kubectl to access your cluster
- ✅ Understand EKS architecture and components
- ✅ (Bonus) Compare with GKE and AKS approaches

---

## Part 1: AWS EKS Overview

### What is EKS?

**Amazon Elastic Kubernetes Service (EKS)** is AWS's managed Kubernetes offering.

**AWS manages**:
- Control plane (API server, etcd, scheduler, controller manager)
- Control plane HA across multiple AZs
- Automatic version upgrades
- Managed add-ons

**You manage**:
- Worker nodes (EC2 or Fargate)
- Node OS patches
- Application workloads
- Cluster add-ons configuration

### EKS Architecture

```
┌─────────────────────────────────────────────────────┐
│                    AWS Account                       │
│  ┌──────────────────────────────────────────────┐   │
│  │              VPC (10.0.0.0/16)               │   │
│  │                                              │   │
│  │  ┌──────────────┐  ┌──────────────┐        │   │
│  │  │ Public Subnet│  │ Public Subnet│        │   │
│  │  │    AZ-A      │  │    AZ-B      │        │   │
│  │  │  NAT Gateway │  │  NAT Gateway │        │   │
│  │  └──────┬───────┘  └──────┬───────┘        │   │
│  │         │                  │                │   │
│  │  ┌──────▼───────┐  ┌──────▼───────┐        │   │
│  │  │Private Subnet│  │Private Subnet│        │   │
│  │  │    AZ-A      │  │    AZ-B      │        │   │
│  │  │  EKS Nodes   │  │  EKS Nodes   │        │   │
│  │  └──────────────┘  └──────────────┘        │   │
│  │                                              │   │
│  └──────────────────────────────────────────────┘   │
│                                                      │
│  ┌──────────────────────────────────────────────┐   │
│  │         EKS Control Plane (AWS Managed)      │   │
│  │  - API Server                                │   │
│  │  - etcd                                      │   │
│  │  - Scheduler                                 │   │
│  │  - Controller Manager                        │   │
│  └──────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
```

### Costs

- **Control Plane**: $0.10/hour (~$73/month)
- **Worker Nodes**: EC2 instance pricing
  - t3.medium: ~$0.042/hour
  - t3.small: ~$0.021/hour
- **Data Transfer**: Varies by region
- **EBS Volumes**: $0.10/GB-month

**For this module**: Budget ~$2-5 (create, test, destroy within a few hours)

---

## Part 2: Prerequisites Setup

### AWS Account Setup

```bash
# Install AWS CLI
brew install awscli

# Configure credentials
aws configure
# AWS Access Key ID: <your-key>
# AWS Secret Access Key: <your-secret>
# Default region: us-west-2
# Default output format: json

# Verify
aws sts get-caller-identity
```

### IAM Permissions Required

Your AWS user/role needs:
- `AmazonEKSClusterPolicy`
- `AmazonEKSServicePolicy`
- `AmazonEKSVPCResourceController`
- EC2 permissions (create VPC, subnets, security groups)
- IAM permissions (create roles, policies)

**For learning**: Use AdministratorAccess (not for production!)

### Install kubectl

```bash
# macOS
brew install kubectl

# Verify
kubectl version --client
```

---

## Part 3: EKS with Terraform - Simple Version

### Project Structure

```
eks-simple/
├── main.tf           # Main configuration
├── variables.tf      # Input variables
├── outputs.tf        # Outputs
├── providers.tf      # Provider configuration
└── terraform.tfvars  # Variable values (don't commit secrets!)
```

### providers.tf

```hcl
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = "eks-terraform-learning"
      ManagedBy   = "Terraform"
    }
  }
}
```

### variables.tf

```hcl
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "my-eks-cluster"
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}
```

### main.tf - VPC Configuration

```hcl
# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.cluster_name}-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.cluster_name}-igw"
  }
}

# Public Subnets (for load balancers, NAT gateways)
resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                                        = "${var.cluster_name}-public-${count.index + 1}"
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# Private Subnets (for EKS nodes)
resource "aws_subnet" "private" {
  count = 2

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 2)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name                                        = "${var.cluster_name}-private-${count.index + 1}"
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  count  = 2
  domain = "vpc"

  tags = {
    Name = "${var.cluster_name}-nat-eip-${count.index + 1}"
  }
}

# NAT Gateways
resource "aws_nat_gateway" "main" {
  count = 2

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "${var.cluster_name}-nat-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.main]
}

# Route table for public subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.cluster_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count = 2

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Route tables for private subnets
resource "aws_route_table" "private" {
  count = 2

  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = {
    Name = "${var.cluster_name}-private-rt-${count.index + 1}"
  }
}

resource "aws_route_table_association" "private" {
  count = 2

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
```

### main.tf - IAM Roles

```hcl
# EKS Cluster IAM Role
resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.cluster.name
}

# EKS Node Group IAM Role
resource "aws_iam_role" "node" {
  name = "${var.cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node.name
}
```

### main.tf - EKS Cluster

```hcl
# Security group for EKS cluster
resource "aws_security_group" "cluster" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "Security group for EKS cluster"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-cluster-sg"
  }
}

# EKS Cluster
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = concat(aws_subnet.private[*].id, aws_subnet.public[*].id)
    endpoint_private_access = true
    endpoint_public_access  = true
    security_group_ids      = [aws_security_group.cluster.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSVPCResourceController,
  ]

  tags = {
    Name = var.cluster_name
  }
}

# EKS Node Group
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-node-group"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = aws_subnet.private[*].id

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  instance_types = ["t3.medium"]

  # Update configuration
  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly,
  ]

  tags = {
    Name = "${var.cluster_name}-node-group"
  }
}
```

### outputs.tf

```hcl
output "cluster_id" {
  description = "EKS cluster ID"
  value       = aws_eks_cluster.main.id
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = aws_eks_cluster.main.name
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "configure_kubectl" {
  description = "Configure kubectl command"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main.name}"
}
```

---

## Part 4: Deploying Your First EKS Cluster

```bash
# 1. Create project directory
mkdir ~/eks-terraform
cd ~/eks-terraform

# 2. Create the files above (providers.tf, variables.tf, main.tf, outputs.tf)

# 3. Initialize Terraform
terraform init

# 4. Plan (preview)
terraform plan

# 5. Apply (create cluster - takes 10-15 minutes)
terraform apply

# 6. Configure kubectl
aws eks update-kubeconfig --region us-west-2 --name my-eks-cluster

# 7. Verify
kubectl get nodes
kubectl get pods -A
```

**Expected output**:
```
NAME                                         STATUS   ROLES    AGE   VERSION
ip-10-0-2-xxx.us-west-2.compute.internal     Ready    <none>   5m    v1.28.x
ip-10-0-3-xxx.us-west-2.compute.internal     Ready    <none>   5m    v1.28.x
```

---

## Part 5: Testing Your Cluster

```bash
# Deploy test application
kubectl create deployment nginx --image=nginx:latest --replicas=2

# Expose it
kubectl expose deployment nginx --port=80 --type=LoadBalancer

# Wait for LoadBalancer
kubectl get svc nginx -w

# Get LoadBalancer URL
export LB_URL=$(kubectl get svc nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl http://$LB_URL

# Clean up test
kubectl delete svc nginx
kubectl delete deployment nginx
```

---

## Part 6: Production Enhancements

### Add-ons

**File**: `addons.tf`
```hcl
# VPC CNI Add-on
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "vpc-cni"
}

# CoreDNS Add-on
resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "coredns"

  depends_on = [aws_eks_node_group.main]
}

# kube-proxy Add-on
resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "kube-proxy"
}

# EBS CSI Driver (for persistent volumes)
resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "aws-ebs-csi-driver"
}
```

### Autoscaling

```hcl
resource "aws_eks_node_group" "main" {
  # ... existing config ...

  scaling_config {
    desired_size = 2
    max_size     = 10  # Increased for autoscaling
    min_size     = 1
  }

  # Enable cluster autoscaler tags
  labels = {
    "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
    "k8s.io/cluster-autoscaler/enabled"             = "true"
  }
}
```

### Security Group Rules

```hcl
# Allow pods to communicate with cluster API
resource "aws_security_group_rule" "cluster_ingress_workstation_https" {
  description       = "Allow workstation to communicate with the cluster API Server"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]  # Restrict in production!
  security_group_id = aws_security_group.cluster.id
}
```

---

## Part 7: Cost Optimization

### Use Spot Instances

```hcl
resource "aws_eks_node_group" "spot" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-spot-node-group"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = aws_subnet.private[*].id
  capacity_type   = "SPOT"  # Use spot instances

  scaling_config {
    desired_size = 2
    max_size     = 5
    min_size     = 1
  }

  instance_types = ["t3.medium", "t3a.medium"]  # Multiple types for availability

  tags = {
    Name = "${var.cluster_name}-spot-nodes"
  }
}
```

### Right-Size Instances

```hcl
# For learning/dev
instance_types = ["t3.small"]  # ~$0.02/hour

# For production
instance_types = ["t3.medium"]  # ~$0.04/hour
```

---

## Part 8: Cleanup

**IMPORTANT**: Always destroy resources when done!

```bash
# 1. Delete any LoadBalancers first (kubectl creates them outside Terraform)
kubectl get svc --all-namespaces
kubectl delete svc <any-loadbalancer-services>

# 2. Destroy Terraform resources
terraform destroy

# Confirm with: yes
```

**Cost if you forget**: ~$75/month for control plane + nodes!

---

## Bonus: GKE and AKS Quick Comparison

### GKE (Google Kubernetes Engine)

**Simpler** than EKS - less configuration needed:

```hcl
resource "google_container_cluster" "primary" {
  name     = "my-gke-cluster"
  location = "us-central1"

  # Can't create cluster without node pool
  remove_default_node_pool = true
  initial_node_count       = 1
}

resource "google_container_node_pool" "primary_nodes" {
  name       = "my-node-pool"
  cluster    = google_container_cluster.primary.name
  location   = "us-central1"
  node_count = 2

  node_config {
    machine_type = "e2-medium"
  }
}
```

**Key differences from EKS**:
- No VPC setup needed (GKE creates it)
- Simpler IAM
- Free control plane under 1 zone cluster
- kubectl config: `gcloud container clusters get-credentials <name>`

### AKS (Azure Kubernetes Service)

**Middle ground** between EKS and GKE:

```hcl
resource "azurerm_kubernetes_cluster" "main" {
  name                = "my-aks-cluster"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "myaks"

  default_node_pool {
    name       = "default"
    node_count = 2
    vm_size    = "Standard_D2_v2"
  }

  identity {
    type = "SystemAssigned"
  }
}
```

**Key differences from EKS**:
- Free control plane
- Simpler than EKS, more complex than GKE
- kubectl config: `az aks get-credentials --name <name> --resource-group <rg>`

---

## Hands-On Exercises

### Exercise 1: Customize Your Cluster

Modify the EKS configuration to:
1. Use different instance types
2. Change node count (min/max/desired)
3. Add custom tags
4. Use a different AWS region

### Exercise 2: Deploy Complete Application

Deploy the multi-tier app from the examples:
```bash
kubectl apply -f https://raw.githubusercontent.com/<user>/k8s/main/examples/multi-tier-app/database/
kubectl apply -f https://raw.githubusercontent.com/<user>/k8s/main/examples/multi-tier-app/backend/
kubectl apply -f https://raw.githubusercontent.com/<user>/k8s/main/examples/multi-tier-app/frontend/
```

### Exercise 3: Enable Logging

Add CloudWatch logging to your cluster:
```hcl
resource "aws_eks_cluster" "main" {
  # ... existing config ...

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}
```

---

## Validation Checklist

Before moving to next module:

- [ ] Successfully provision EKS cluster with Terraform
- [ ] Configure kubectl to access cluster
- [ ] Deploy test application
- [ ] Understand VPC/networking setup
- [ ] Know how to destroy resources
- [ ] Can read AWS EKS documentation
- [ ] Understand IAM roles for EKS

**Self-test**:
```bash
# Can you do this?
1. Create new EKS cluster with different name
2. Change to 3 nodes
3. Deploy nginx
4. Access it via LoadBalancer
5. Destroy everything
```

---

## Troubleshooting

### Issue: Cluster creation fails

**Check**:
```bash
# IAM permissions
aws sts get-caller-identity

# Service quotas
aws service-quotas list-service-quotas --service-code eks
```

### Issue: Nodes not joining cluster

**Check**:
```bash
# Node group status
aws eks describe-nodegroup --cluster-name <cluster> --nodegroup-name <nodegroup>

# IAM role permissions
aws iam get-role --role-name <node-role-name>
```

### Issue: kubectl can't connect

```bash
# Update kubeconfig
aws eks update-kubeconfig --region us-west-2 --name my-eks-cluster

# Test connection
kubectl cluster-info

# Check cluster status
aws eks describe-cluster --name my-eks-cluster
```

---

## Key Takeaways

1. **EKS** requires VPC, IAM, and cluster configuration
2. **Terraform** makes EKS reproducible
3. **Node groups** provide worker capacity
4. **Add-ons** extend cluster functionality
5. **Always destroy** resources when done to avoid costs
6. **GKE/AKS** are simpler but EKS gives more AWS integration

---

## Additional Resources

- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Terraform AWS Provider - EKS](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_cluster)
- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [EKS Workshop](https://www.eksworkshop.com/)

---

## Next Steps

**Ready to manage K8s resources?** → [Module 03: Managing K8s with Terraform](../03-managing-k8s-resources/README.md)

**Want production EKS?** → Stay tuned for detailed EKS learning path (including CDK!)

---

**Cleanup reminder**:
```bash
terraform destroy
# Verify in AWS console that ELBs are deleted
```
