# Module 04: Multi-Environment Patterns

**Duration**: ~3 hours
**Prerequisites**: [Module 03: Managing K8s Resources](../03-managing-k8s-resources/README.md)
**Next Module**: [05-Advanced Patterns](../05-advanced-patterns/README.md)

## Learning Objectives

By the end of this module, you will:
- ✅ Implement DRY (Don't Repeat Yourself) infrastructure
- ✅ Use Terraform workspaces for environment separation
- ✅ Build reusable modules
- ✅ Manage environment-specific variables
- ✅ Use remote state and state locking
- ✅ Implement team collaboration workflows

---

## Part 1: Environment Separation Strategies

### Option 1: Workspaces

**Best for**: Same infrastructure, different configurations

```bash
# Create environments
terraform workspace new dev
terraform workspace new staging
terraform workspace new production

# Switch between them
terraform workspace select dev
terraform apply -var-file="dev.tfvars"

terraform workspace select production
terraform apply -var-file="prod.tfvars"
```

### Option 2: Separate Directories

**Best for**: Different infrastructure per environment

```
environments/
├── dev/
│   ├── main.tf
│   ├── variables.tf
│   └── terraform.tfvars
├── staging/
│   ├── main.tf
│   ├── variables.tf
│   └── terraform.tfvars
└── production/
    ├── main.tf
    ├── variables.tf
    └── terraform.tfvars
```

### Option 3: Modules (Our Approach)

**Best for**: Maximum reusability, DRY

```
project/
├── modules/
│   └── eks-cluster/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── environments/
    ├── dev/
    ├── staging/
    └── production/
```

---

## Part 2: Building Reusable Modules

### Module Structure

**File**: `modules/eks-cluster/main.tf`
```hcl
# VPC
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  enable_nat_gateway   = true
  single_nat_gateway   = var.environment == "dev" ? true : false
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = var.tags
}

# EKS Cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.0.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access = true

  eks_managed_node_groups = {
    main = {
      desired_size   = var.node_desired_size
      min_size       = var.node_min_size
      max_size       = var.node_max_size
      instance_types = var.node_instance_types

      capacity_type = var.environment == "production" ? "ON_DEMAND" : "SPOT"
    }
  }

  tags = var.tags
}
```

**File**: `modules/eks-cluster/variables.tf`
```hcl
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28"
}

variable "environment" {
  description = "Environment name"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production"
  }
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "AWS availability zones"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDR blocks"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks"
  type        = list(string)
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 5
}

variable "node_instance_types" {
  description = "EC2 instance types for worker nodes"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
```

**File**: `modules/eks-cluster/outputs.tf`
```hcl
output "cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnets
}
```

---

## Part 3: Environment-Specific Configurations

### Development Environment

**File**: `environments/dev/main.tf`
```hcl
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "eks/dev/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = "terraform-lock"
  }
}

provider "aws" {
  region = var.aws_region
}

module "eks_cluster" {
  source = "../../modules/eks-cluster"

  cluster_name    = "dev-cluster"
  cluster_version = "1.28"
  environment     = "dev"

  vpc_cidr = "10.0.0.0/16"

  availability_zones   = ["us-west-2a", "us-west-2b"]
  private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24"]

  node_desired_size    = 1  # Small for dev
  node_min_size        = 1
  node_max_size        = 2
  node_instance_types  = ["t3.small"]  # Cheaper instances

  tags = {
    Environment = "dev"
    ManagedBy   = "terraform"
    Owner       = "dev-team"
  }
}
```

**File**: `environments/dev/terraform.tfvars`
```hcl
aws_region = "us-west-2"
```

### Production Environment

**File**: `environments/production/main.tf`
```hcl
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "eks/production/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = "terraform-lock"
  }
}

provider "aws" {
  region = var.aws_region
}

module "eks_cluster" {
  source = "../../modules/eks-cluster"

  cluster_name    = "prod-cluster"
  cluster_version = "1.28"
  environment     = "production"

  vpc_cidr = "10.1.0.0/16"  # Different CIDR

  availability_zones   = ["us-west-2a", "us-west-2b", "us-west-2c"]  # 3 AZs
  private_subnet_cidrs = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
  public_subnet_cidrs  = ["10.1.101.0/24", "10.1.102.0/24", "10.1.103.0/24"]

  node_desired_size    = 3  # Higher for production
  node_min_size        = 2
  node_max_size        = 10
  node_instance_types  = ["t3.medium"]  # Better instances

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
    Owner       = "platform-team"
    CostCenter  = "engineering"
  }
}
```

---

## Part 4: Remote State Management

### S3 Backend Setup

**Create state bucket** (one-time setup):
```bash
# Create S3 bucket
aws s3 mb s3://my-terraform-state --region us-west-2

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket my-terraform-state \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket my-terraform-state \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name terraform-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-west-2
```

### Backend Configuration

```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "eks/dev/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = "terraform-lock"
  }
}
```

### State Management Commands

```bash
# Initialize backend
terraform init

# Migrate existing state to remote
terraform init -migrate-state

# View state
terraform state list

# Pull remote state
terraform state pull

# Push local state (rarely needed)
terraform state push
```

---

## Part 5: Variable Patterns

### Hierarchical Variables

```
common.tfvars          # Shared across all environments
dev.tfvars             # Dev-specific
staging.tfvars         # Staging-specific
production.tfvars      # Production-specific
```

**File**: `common.tfvars`
```hcl
aws_region      = "us-west-2"
cluster_version = "1.28"
```

**File**: `dev.tfvars`
```hcl
cluster_name        = "dev-cluster"
node_desired_size   = 1
node_instance_types = ["t3.small"]
```

**File**: `production.tfvars`
```hcl
cluster_name        = "prod-cluster"
node_desired_size   = 3
node_instance_types = ["t3.medium"]
```

**Apply with multiple var files**:
```bash
terraform apply \
  -var-file="common.tfvars" \
  -var-file="production.tfvars"
```

---

## Part 6: Team Collaboration Workflow

### Git Workflow

```
main
├── environments/
│   ├── dev/
│   ├── staging/
│   └── production/
└── modules/
    └── eks-cluster/
```

**Workflow**:
1. Developer creates feature branch
2. Makes infrastructure changes
3. Runs `terraform plan` in CI
4. Creates pull request
5. Team reviews plan output
6. Merges to main
7. CI applies to dev automatically
8. Manual approval for staging/prod

### CI/CD Example (GitHub Actions)

**File**: `.github/workflows/terraform.yml`
```yaml
name: Terraform

on:
  pull_request:
    paths:
      - 'environments/**'
      - 'modules/**'
  push:
    branches:
      - main

jobs:
  terraform:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        environment: [dev, staging, production]

    steps:
      - uses: actions/checkout@v3

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2

      - name: Terraform Init
        run: terraform init
        working-directory: environments/${{ matrix.environment }}

      - name: Terraform Validate
        run: terraform validate
        working-directory: environments/${{ matrix.environment }}

      - name: Terraform Plan
        run: terraform plan
        working-directory: environments/${{ matrix.environment }}
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}

      - name: Terraform Apply (dev only, on main)
        if: github.ref == 'refs/heads/main' && matrix.environment == 'dev'
        run: terraform apply -auto-approve
        working-directory: environments/${{ matrix.environment }}
```

---

## Part 7: Module Versioning

### Using Module Versions

```hcl
module "eks_cluster" {
  source  = "git::https://github.com/myorg/terraform-modules.git//eks-cluster?ref=v1.2.0"
  # or
  source  = "../../modules/eks-cluster"
  version = "~> 1.2"

  # ... configuration
}
```

### Publishing Modules

1. Create Git repository
2. Tag releases: `git tag v1.0.0`
3. Reference in projects: `?ref=v1.0.0`

---

## Hands-On Exercises

### Exercise 1: Three-Environment Setup

Create complete dev/staging/prod environments:
1. Build reusable EKS module
2. Create 3 environment directories
3. Configure different sizes for each
4. Set up remote state
5. Deploy all three

### Exercise 2: Module Registry

Create a private module registry:
1. Publish module to Git
2. Version it with tags
3. Reference from multiple environments

### Exercise 3: Cost Optimization

Implement cost-saving patterns:
- Spot instances for dev
- Smaller nodes for dev
- Single NAT gateway for dev
- Multiple AZs only for prod

---

## Validation Checklist

- [ ] Build reusable Terraform module
- [ ] Deploy multiple environments
- [ ] Configure remote state with S3
- [ ] Use state locking with DynamoDB
- [ ] Implement environment-specific variables
- [ ] Understand module versioning
- [ ] Set up team collaboration workflow

---

## Key Takeaways

1. **DRY**: Use modules to avoid repetition
2. **Remote state**: Enable team collaboration
3. **State locking**: Prevent concurrent modifications
4. **Environment separation**: Use different state files
5. **Variable files**: Separate configuration per environment
6. **Version modules**: Pin versions for stability

---

## Additional Resources

- [Terraform Modules](https://www.terraform.io/language/modules)
- [Managing Terraform State](https://www.terraform.io/language/state)
- [Terraform Cloud/Enterprise](https://www.terraform.io/cloud)

---

## Next Steps

**Ready for advanced patterns?** → [Module 05: Advanced Patterns](../05-advanced-patterns/README.md)
