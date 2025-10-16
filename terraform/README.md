# Terraform Track: Infrastructure as Code for Kubernetes

**Duration**: ~15 hours total
**Prerequisites**: [Beginner Track](../beginner/README.md) completed or equivalent K8s knowledge
**Goal**: Provision and manage Kubernetes infrastructure with Terraform

---

## Who This Is For

- Cloud engineers provisioning K8s clusters
- DevOps engineers implementing Infrastructure as Code
- Platform teams managing multi-environment setups
- Anyone moving from manual K8s setup to automated provisioning

---

## What You'll Learn

By completing this track, you'll be able to:

- ✅ Write Terraform configurations (HCL)
- ✅ Provision managed Kubernetes clusters (EKS, GKE, AKS)
- ✅ Manage Kubernetes resources with Terraform
- ✅ Implement multi-environment patterns (dev/staging/prod)
- ✅ Set up GitOps workflows with Terraform
- ✅ Manage state and collaborate on teams
- ✅ Build reusable infrastructure modules

---

## Track Structure

### [Module 01: Terraform Fundamentals](01-terraform-fundamentals/README.md)
**Duration**: ~3 hours | **Level**: Beginner

- Introduction to Infrastructure as Code
- Terraform basics (HCL syntax, providers, resources)
- State management fundamentals
- Working with variables and outputs
- Terraform CLI commands
- Your first infrastructure

**What you'll build**: Local infrastructure with Docker provider

---

### [Module 02: Provisioning Kubernetes Clusters](02-provisioning-clusters/README.md)
**Duration**: ~4 hours | **Level**: Intermediate

- Cloud provider setup (AWS, GCP, Azure)
- Provisioning EKS (AWS)
- Provisioning GKE (Google Cloud)
- Provisioning AKS (Azure)
- Networking and security configuration
- Node groups and autoscaling
- Add-ons and integrations

**What you'll build**: Production-ready managed K8s cluster

---

### [Module 03: Managing Kubernetes Resources](03-managing-k8s-resources/README.md)
**Duration**: ~3 hours | **Level**: Intermediate

- Kubernetes provider setup
- Managing namespaces, deployments, services
- ConfigMaps and Secrets in Terraform
- Helm provider integration
- When to use Terraform vs kubectl/Helm
- GitOps patterns

**What you'll build**: Complete application stack via Terraform

---

### [Module 04: Multi-Environment Patterns](04-multi-environment/README.md)
**Duration**: ~3 hours | **Level**: Advanced

- Workspaces for environment separation
- Building reusable modules
- Variable patterns (tfvars, environment-specific)
- Remote state and state locking
- Team collaboration workflows
- DRY principles in Terraform

**What you'll build**: Multi-environment setup (dev/staging/prod)

---

### [Module 05: Advanced Patterns](05-advanced-patterns/README.md)
**Duration**: ~2 hours | **Level**: Advanced

- CI/CD integration (GitHub Actions, GitLab CI)
- Terragrunt for DRY configuration
- Policy as Code (OPA, Sentinel)
- Cost estimation and management
- Disaster recovery strategies
- Troubleshooting and debugging

**What you'll build**: Automated Terraform pipeline

---

## Prerequisites

### Required Knowledge
- ✅ Kubernetes fundamentals (complete beginner track)
- ✅ Basic command line usage
- ✅ Understanding of cloud concepts
- ✅ Git basics

### Required Tools
```bash
# Terraform
brew install terraform

# Cloud CLI (choose one or more)
brew install awscli      # AWS
brew install google-cloud-sdk  # GCP
brew install azure-cli   # Azure

# Optional but recommended
brew install terraform-docs
brew install tflint
brew install tfswitch    # Terraform version manager
```

### Cloud Account
You'll need **at least one** cloud account:
- **AWS**: Free tier available
- **GCP**: $300 free credits
- **Azure**: $200 free credits

**Cost warning**: Some resources (like managed K8s clusters) cost money. Module 01 uses free local resources. Budget ~$5-10/day for cloud modules if left running.

---

## Learning Paths

### Path 1: AWS Focused
1. Module 01: Fundamentals
2. Module 02: Focus on EKS
3. Module 03: K8s Resources
4. Module 04: Multi-Environment
5. Module 05: Advanced Patterns

**Best for**: AWS-heavy organizations, EKS users

### Path 2: Multi-Cloud
1. Module 01: Fundamentals
2. Module 02: All three providers (EKS, GKE, AKS)
3. Module 03: K8s Resources
4. Module 04: Multi-Environment
5. Module 05: Advanced Patterns

**Best for**: Platform engineers, consultants

### Path 3: Application Developer
1. Module 01: Fundamentals
2. Module 02: Single provider (your org's cloud)
3. Module 03: K8s Resources (focus here)
4. Module 04: Multi-Environment

**Best for**: App developers deploying to K8s

---

## Repository Structure

```
terraform/
├── README.md                      # You are here
├── 01-terraform-fundamentals/     # IaC basics
│   ├── README.md
│   ├── examples/
│   └── exercises/
├── 02-provisioning-clusters/      # EKS, GKE, AKS
│   ├── README.md
│   ├── aws-eks/
│   ├── gcp-gke/
│   └── azure-aks/
├── 03-managing-k8s-resources/     # K8s provider
│   ├── README.md
│   └── examples/
├── 04-multi-environment/          # Workspaces, modules
│   ├── README.md
│   └── examples/
├── 05-advanced-patterns/          # CI/CD, GitOps
│   ├── README.md
│   └── examples/
└── examples/                      # Complete projects
    ├── eks-complete/
    ├── gke-complete/
    └── multi-cloud/
```

---

## Cost Management

**Important**: Cloud resources cost money!

### Free Tier Resources
- **AWS**: t3.micro instances, limited hours
- **GCP**: $300 credits (12 months)
- **Azure**: $200 credits (30 days)

### Cluster Costs (Approximate)
- **EKS**: ~$0.10/hour (control plane) + worker nodes
- **GKE**: ~$0.10/hour (control plane) + worker nodes
- **AKS**: Free control plane + worker nodes

**Worker nodes** typically cost $0.05-0.10/hour for small instances.

### Cost Reduction Tips
```bash
# Always destroy resources when done
terraform destroy

# Use small instance types
instance_type = "t3.small"  # AWS
machine_type = "e2-small"   # GCP

# Minimize node count
node_count = 1  # For learning

# Use spot/preemptible instances (advanced)
```

### Budget Alerts
Set up billing alerts in your cloud console:
- AWS: CloudWatch billing alerts
- GCP: Budget alerts
- Azure: Cost Management alerts

---

## Terraform vs Other Tools

| Tool | Purpose | When to Use |
|------|---------|-------------|
| **Terraform** | Provision infrastructure | Clusters, networks, IAM |
| **kubectl** | Manage K8s workloads | Day-to-day operations |
| **Helm** | Package K8s applications | Application deployment |
| **Pulumi** | IaC (code, not HCL) | Prefer TypeScript/Python |
| **CloudFormation** | AWS-specific IaC | AWS-only environments |

**This track's approach**: Use Terraform for infrastructure, integrate with kubectl/Helm for applications.

---

## Best Practices

### ✅ Do
- Version control all Terraform code
- Use remote state (S3, GCS, Azure Blob)
- Enable state locking
- Use modules for reusability
- Run `terraform plan` before `apply`
- Use `.tfvars` for sensitive values (don't commit!)
- Tag/label all resources

### ❌ Don't
- Commit `.tfstate` files to Git
- Store secrets in plain text
- Modify state files manually
- Run `terraform apply` without reviewing plan
- Use default VPCs in production
- Skip resource tagging

---

## Getting Started

### Quick Start

```bash
# Install Terraform
brew install terraform

# Verify installation
terraform version

# Start with Module 01 (no cloud account needed)
cd terraform/01-terraform-fundamentals
cat README.md
```

### What You'll Build

By the end of this track, you'll have:

1. **Module 01**: Docker containers managed by Terraform
2. **Module 02**: Production-ready K8s cluster on your chosen cloud
3. **Module 03**: Full application stack (frontend/backend/database) deployed via Terraform
4. **Module 04**: Multi-environment setup with dev/staging/prod
5. **Module 05**: Automated CI/CD pipeline for infrastructure

---

## Additional Resources

### Official Documentation
- [Terraform Documentation](https://www.terraform.io/docs)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform Google Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Terraform Kubernetes Provider](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs)

### Terraform Registry
- [Module Registry](https://registry.terraform.io/)
- [Provider Registry](https://registry.terraform.io/browse/providers)

### Learning Resources
- [HashiCorp Learn](https://learn.hashicorp.com/terraform)
- [Terraform Up & Running](https://www.terraformupandrunning.com/) (book)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)

### Community
- [Terraform Community Forum](https://discuss.hashicorp.com/c/terraform-core/)
- [r/Terraform](https://reddit.com/r/Terraform)

---

## Certification

**HashiCorp Certified: Terraform Associate**
- Covers: HCL, workflow, state, modules, providers
- After: Modules 01-04
- Cost: $70
- Format: Online proctored exam

---

## FAQ

**Q: Do I need cloud credits/money?**
A: Module 01 is free (local only). Modules 02-05 require cloud accounts. Use free tiers and destroy resources after each module.

**Q: Which cloud should I learn?**
A: Pick your organization's cloud, or AWS (most popular). The concepts transfer between clouds.

**Q: Should I use Terraform or kubectl?**
A: Both! Terraform for infrastructure (clusters, networks), kubectl/Helm for applications. Module 03 explains the boundary.

**Q: What about Pulumi/CDK?**
A: They're alternatives. Terraform has the largest community and most providers. Learn Terraform first, then explore alternatives.

**Q: How long until I'm job-ready?**
A: Complete this track + deploy 2-3 real projects = production-ready Terraform skills.

**Q: Terraform vs Ansible?**
A: Different tools. Terraform provisions infrastructure (immutable), Ansible configures servers (mutable). Use Terraform for K8s clusters.

---

## Module Status

| Module | Status | Estimated Time |
|--------|--------|----------------|
| 01 - Fundamentals | ✅ Complete | ~3 hours |
| 02 - Provisioning Clusters | ✅ Complete | ~4 hours |
| 03 - K8s Resources | ✅ Complete | ~3 hours |
| 04 - Multi-Environment | ✅ Complete | ~3 hours |
| 05 - Advanced Patterns | ✅ Complete | ~2 hours |

---

## Ready to Start?

**Prerequisites complete?** → [Module 01: Terraform Fundamentals](01-terraform-fundamentals/README.md)

**Need K8s knowledge first?** → [Beginner Track](../beginner/README.md)

**Questions?** → Open an issue or check [FAQ](#faq)

---

**Let's provision some infrastructure! 🚀**
