# AWS EKS Deep Dive Learning Path

Comprehensive guide to mastering Amazon Elastic Kubernetes Service (EKS), from fundamentals to production-grade deployments.

## Overview

This learning path focuses exclusively on AWS EKS with both Terraform and AWS CDK approaches. Estimated completion time: **30-40 hours**.

## Prerequisites

- AWS account with appropriate permissions
- Basic Kubernetes knowledge (complete beginner track first)
- AWS CLI configured
- kubectl installed
- Terraform or AWS CDK installed

## Learning Path Structure

### Module 01: EKS Fundamentals (4 hours)
**What you'll learn:**
- EKS architecture and components
- Control plane vs data plane
- EKS vs self-managed Kubernetes
- Pricing and cost optimization
- When to use EKS

**Hands-on:**
- Create your first EKS cluster (console)
- Connect with kubectl
- Deploy a simple application
- Clean up resources

### Module 02: Networking Deep Dive (6 hours)
**What you'll learn:**
- VPC design for EKS
- Public vs private subnets
- NAT Gateways and Internet Gateways
- Security groups and NACLs
- Amazon VPC CNI plugin
- IP address management (IPAM)
- Custom networking
- Prefix delegation

**Hands-on:**
- Design production-ready VPC
- Configure custom networking
- Implement security groups
- Test pod-to-pod communication

### Module 03: IAM and Security (5 hours)
**What you'll learn:**
- IAM roles for service accounts (IRSA)
- Pod Identity (new method)
- Cluster authentication
- RBAC integration with IAM
- Security best practices
- Secrets management (AWS Secrets Manager, SSM)
- Pod security standards

**Hands-on:**
- Configure IRSA for applications
- Implement least privilege access
- Integrate with AWS Secrets Manager
- Set up pod security policies

### Module 04: Managed Node Groups and Compute (5 hours)
**What you'll learn:**
- Managed node groups
- Self-managed nodes
- Fargate profiles
- Spot instances
- Bottlerocket OS
- Graviton processors
- Node affinity and taints
- Cluster autoscaler
- Karpenter autoscaler

**Hands-on:**
- Create managed node groups
- Configure Fargate profiles
- Implement cluster autoscaler
- Set up Karpenter
- Use spot instances

### Module 05: Add-ons and Controllers (6 hours)
**What you'll learn:**
- EKS add-ons (CoreDNS, kube-proxy, VPC CNI)
- AWS Load Balancer Controller
- EBS CSI driver
- EFS CSI driver
- Amazon FSx for Lustre
- External DNS
- Cert Manager
- Metrics Server

**Hands-on:**
- Install AWS Load Balancer Controller
- Configure EBS persistent volumes
- Set up EFS for shared storage
- Implement External DNS
- Configure SSL with Cert Manager

### Module 06: Observability and Monitoring (5 hours)
**What you'll learn:**
- CloudWatch Container Insights
- Control plane logging
- Application logging (Fluent Bit)
- Prometheus and Grafana on EKS
- AWS Distro for OpenTelemetry (ADOT)
- X-Ray integration
- Cost monitoring with Kubecost

**Hands-on:**
- Enable Container Insights
- Set up centralized logging
- Deploy Prometheus and Grafana
- Configure ADOT collector
- Implement cost tracking

### Module 07: Advanced Patterns (5 hours)
**What you'll learn:**
- Multi-cluster management
- Cross-region deployments
- Disaster recovery
- Blue-green deployments
- GitOps with ArgoCD/Flux
- Service mesh (App Mesh, Istio)
- Multi-tenancy patterns

**Hands-on:**
- Set up multi-cluster environment
- Implement GitOps workflow
- Configure cross-region replication
- Deploy service mesh

### Module 08: Infrastructure as Code (4 hours)
**What you'll learn:**
- Terraform for EKS
- AWS CDK for EKS
- eksctl vs IaC tools
- Module design patterns
- State management
- CI/CD integration

**Hands-on:**
- Build EKS cluster with Terraform
- Build EKS cluster with CDK
- Create reusable modules
- Implement automated deployments

## Learning Paths

### Path 1: Quick Start (8 hours)
For those who need to get started quickly:
- Module 01: EKS Fundamentals
- Module 04: Compute (managed nodes only)
- Module 05: Essential add-ons (LB Controller, EBS CSI)
- Module 08: Terraform basics

### Path 2: Production Ready (20 hours)
For deploying production workloads:
- Module 01: EKS Fundamentals
- Module 02: Networking Deep Dive
- Module 03: IAM and Security
- Module 04: Compute
- Module 05: Add-ons
- Module 06: Observability
- Module 08: Infrastructure as Code

### Path 3: Complete Mastery (40 hours)
For EKS experts:
- All modules in order

## Tools You'll Use

- **AWS CLI**: Interact with AWS services
- **kubectl**: Kubernetes command-line tool
- **eksctl**: EKS cluster management tool
- **Terraform**: Infrastructure as Code
- **AWS CDK**: Infrastructure as Code (TypeScript/Python)
- **Helm**: Kubernetes package manager
- **k9s**: Terminal UI for Kubernetes

## Cost Management

### Expected Costs

**Minimal Setup (Dev):**
- EKS Control Plane: ~$73/month
- 2x t3.small nodes: ~$30/month
- 1x NAT Gateway: ~$32/month
- **Total**: ~$135/month

**Production Setup:**
- EKS Control Plane: ~$73/month
- 5x t3.medium nodes: ~$300/month
- 2x NAT Gateways: ~$64/month
- Load Balancers: ~$18-36/month
- Data transfer: Variable
- **Total**: ~$455-500/month

### Cost Optimization Tips

1. **Use Spot Instances**: Save up to 90%
2. **Right-size nodes**: Don't over-provision
3. **Use Fargate selectively**: Only for specific workloads
4. **Single NAT Gateway for dev**: Use one instead of per-AZ
5. **Delete unused resources**: Clean up after learning
6. **Use AWS Free Tier**: Where applicable
7. **Enable autoscaling**: Scale to zero when not in use

## Repository Structure

```
eks/
├── README.md                           # This file
├── 01-fundamentals/
│   ├── README.md
│   ├── architecture.md
│   ├── getting-started.md
│   └── examples/
├── 02-networking/
│   ├── README.md
│   ├── vpc-design.md
│   ├── cni-deep-dive.md
│   └── examples/
├── 03-iam-security/
│   ├── README.md
│   ├── irsa-guide.md
│   ├── rbac-integration.md
│   └── examples/
├── 04-compute/
│   ├── README.md
│   ├── managed-nodes.md
│   ├── fargate.md
│   ├── karpenter.md
│   └── examples/
├── 05-addons/
│   ├── README.md
│   ├── aws-load-balancer-controller.md
│   ├── storage.md
│   └── examples/
├── 06-observability/
│   ├── README.md
│   ├── cloudwatch.md
│   ├── prometheus.md
│   └── examples/
├── 07-advanced/
│   ├── README.md
│   ├── multi-cluster.md
│   ├── gitops.md
│   └── examples/
├── 08-iac/
│   ├── README.md
│   ├── terraform/
│   │   └── examples/
│   └── cdk/
│       └── examples/
└── cheatsheets/
    ├── eksctl.md
    ├── aws-cli.md
    └── troubleshooting.md
```

## Getting Started

### 1. Set Up AWS Environment

```bash
# Install AWS CLI
brew install awscli  # macOS
# or: https://aws.amazon.com/cli/

# Configure credentials
aws configure
```

### 2. Install Required Tools

```bash
# Install kubectl
brew install kubectl

# Install eksctl
brew tap weaveworks/tap
brew install weaveworks/tap/eksctl

# Install Terraform
brew install terraform

# Install AWS CDK
npm install -g aws-cdk

# Install Helm
brew install helm

# Install k9s (optional but recommended)
brew install k9s
```

### 3. Verify Installation

```bash
aws --version
kubectl version --client
eksctl version
terraform version
cdk --version
helm version
```

### 4. Start Learning

Begin with [Module 01: EKS Fundamentals](./01-fundamentals/README.md)

## Additional Resources

### AWS Documentation
- [EKS User Guide](https://docs.aws.amazon.com/eks/)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [EKS Workshop](https://www.eksworkshop.com/)

### Community
- [EKS Roadmap](https://github.com/aws/containers-roadmap)
- [AWS Containers Blog](https://aws.amazon.com/blogs/containers/)
- [Kubernetes Slack #eks-users](https://kubernetes.slack.com)

### Certifications
- AWS Certified Solutions Architect
- Certified Kubernetes Administrator (CKA)
- Certified Kubernetes Application Developer (CKAD)

## Next Steps

After completing this path:
1. Build production-grade applications on EKS
2. Contribute to open-source EKS tools
3. Obtain AWS and Kubernetes certifications
4. Explore other managed Kubernetes offerings (GKE, AKS)

## Support

For questions or issues:
1. Check the [troubleshooting guide](./cheatsheets/troubleshooting.md)
2. Search [AWS re:Post](https://repost.aws/)
3. Open an issue on GitHub

---

**Ready to start?** Head to [Module 01: EKS Fundamentals](./01-fundamentals/README.md)
