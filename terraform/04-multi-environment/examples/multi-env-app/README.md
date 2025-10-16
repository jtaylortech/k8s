# Multi-Environment Terraform Example

Demonstrates enterprise-grade multi-environment infrastructure patterns:
- Reusable Terraform modules
- Environment-specific configurations (dev, staging, prod)
- Remote state with S3 and DynamoDB locking
- Variable hierarchies and DRY principles
- Team collaboration workflows

## Directory Structure

```
multi-env-app/
├── README.md                          # This file
├── modules/                           # Reusable modules
│   └── k8s-app/                       # Application deployment module
│       ├── main.tf                    # Module resources
│       ├── variables.tf               # Module inputs
│       ├── outputs.tf                 # Module outputs
│       └── README.md                  # Module documentation
├── environments/                      # Environment-specific configs
│   ├── dev/                           # Development environment
│   │   ├── backend.tf                 # Remote state config
│   │   ├── main.tf                    # Root module
│   │   ├── terraform.tfvars           # Dev-specific values
│   │   └── outputs.tf                 # Environment outputs
│   ├── staging/                       # Staging environment
│   │   ├── backend.tf
│   │   ├── main.tf
│   │   ├── terraform.tfvars
│   │   └── outputs.tf
│   └── prod/                          # Production environment
│       ├── backend.tf
│       ├── main.tf
│       ├── terraform.tfvars
│       └── outputs.tf
├── shared/                            # Shared configuration
│   ├── backend-config/                # Backend configuration
│   │   └── setup-backend.sh           # Script to create S3/DynamoDB
│   └── variables.tf                   # Common variables
└── .gitignore
```

## Prerequisites

1. **AWS CLI configured** with appropriate permissions
2. **Terraform installed** (>= 1.0)
3. **EKS cluster** for each environment (or shared cluster with namespace separation)
4. **S3 bucket and DynamoDB table** for remote state (created via setup script)

## Setup

### 1. Create Remote State Backend

```bash
# Navigate to backend config
cd shared/backend-config

# Edit variables in the script
vi setup-backend.sh

# Run setup script
./setup-backend.sh

# This creates:
# - S3 bucket: <project>-terraform-state
# - DynamoDB table: terraform-state-lock
# - Proper bucket policies and encryption
```

### 2. Deploy to Development

```bash
cd environments/dev

# Initialize Terraform
terraform init

# Plan
terraform plan

# Apply
terraform apply
```

### 3. Deploy to Staging

```bash
cd environments/staging

terraform init
terraform plan
terraform apply
```

### 4. Deploy to Production

```bash
cd environments/prod

# Production requires approval
terraform plan -out=prod.tfplan

# Review plan carefully
less prod.tfplan

# Apply with plan file
terraform apply prod.tfplan
```

## How It Works

### Module Pattern

The `modules/k8s-app` directory contains a **reusable module** that:
- Accepts inputs (namespace, replicas, resources, etc.)
- Creates K8s resources (Deployment, Service, ConfigMap)
- Returns outputs (service URL, deployment name, etc.)

Benefits:
- **DRY**: Write once, use multiple times
- **Consistency**: Same code across environments
- **Maintainability**: Update in one place
- **Testability**: Test module independently

### Environment Pattern

Each environment (`dev`, `staging`, `prod`) is a **root module** that:
- Calls the reusable `k8s-app` module
- Provides environment-specific values
- Configures remote state backend
- May include environment-specific resources

### Remote State

Remote state stored in S3 with DynamoDB locking:
- **S3**: Stores Terraform state (encrypted at rest)
- **DynamoDB**: Prevents concurrent modifications (state locking)
- **Separate state files**: Each environment has its own state

Benefits:
- **Team collaboration**: Multiple people can work safely
- **State backup**: S3 provides durability and versioning
- **Security**: State encrypted, access controlled via IAM

## Environment Differences

| Feature | Dev | Staging | Prod |
|---------|-----|---------|------|
| Replicas | 1 | 2 | 3+ |
| Resources | Small | Medium | Large |
| Autoscaling | Disabled | Enabled | Enabled |
| Service Type | ClusterIP | LoadBalancer | LoadBalancer |
| Monitoring | Basic | Full | Full + Alerts |
| Backups | None | Daily | Hourly |
| State Locking | Yes | Yes | Yes |
| Approval Required | No | Recommended | Required |

## Workflows

### Adding a New Feature

```bash
# 1. Develop in local/dev environment
cd environments/dev
terraform apply

# 2. Test thoroughly in dev
kubectl get all -n dev-app

# 3. Promote to staging
cd ../staging
terraform apply

# 4. Validate in staging
# Run integration tests, load tests, etc.

# 5. Deploy to production (with approval)
cd ../prod
terraform plan -out=prod.tfplan
# Get approval from team lead
terraform apply prod.tfplan
```

### Rolling Back

```bash
# Option 1: Revert Terraform code and apply
git revert <commit>
terraform apply

# Option 2: Use Terraform state rollback
terraform state pull > backup.tfstate
# Restore previous state if needed

# Option 3: Kubernetes rollback
kubectl rollout undo deployment/app-name -n namespace
```

### Updating the Module

```bash
# 1. Make changes to modules/k8s-app/
vi modules/k8s-app/main.tf

# 2. Test in dev first
cd environments/dev
terraform init -upgrade  # Update module
terraform plan
terraform apply

# 3. If successful, update staging
cd ../staging
terraform init -upgrade
terraform apply

# 4. Finally update production
cd ../prod
terraform init -upgrade
terraform apply
```

## Variable Hierarchy

Variables are sourced in this order (last wins):

1. **Module defaults** (`modules/k8s-app/variables.tf`)
2. **Environment defaults** (`environments/dev/main.tf`)
3. **Environment tfvars** (`environments/dev/terraform.tfvars`)
4. **Environment variables** (`TF_VAR_*`)
5. **Command line** (`-var` flag)

Example:
```bash
# Module default: app_replicas = 2
# Environment tfvars override: app_replicas = 1
# Command line override: -var="app_replicas=3"
# Result: 3 replicas
```

## Team Collaboration

### Best Practices

1. **Never commit tfvars to git** (if they contain secrets)
   - Use `.gitignore` for `*.tfvars`
   - Store secrets in AWS Secrets Manager
   - Reference secrets via data sources

2. **Always use remote state**
   - Enables team collaboration
   - Provides state locking
   - Automatic backups

3. **Use workspaces cautiously**
   - Prefer separate directories for environments
   - Workspaces can be confusing
   - State files are easier to manage separately

4. **Plan before apply**
   - Always run `terraform plan` first
   - Save plans for production: `terraform plan -out=plan.tfplan`
   - Review plans before applying

5. **Use version constraints**
   - Pin Terraform version: `required_version = "~> 1.6"`
   - Pin provider versions: `version = "~> 5.0"`
   - Pin module versions (if using registry or git tags)

### Approval Workflow

For production deployments:

```bash
# Developer creates plan
cd environments/prod
terraform plan -out=prod.tfplan

# Upload plan for review (example using S3)
aws s3 cp prod.tfplan s3://my-terraform-plans/$(date +%Y%m%d-%H%M%S)-prod.tfplan

# Send Slack/email notification for review
# Team lead reviews plan

# After approval, apply
terraform apply prod.tfplan
```

## Cost Optimization

### Development
- Single replica
- ClusterIP service (no LoadBalancer)
- Spot instances for nodes
- Destroy nightly (optional)

```bash
# Destroy dev environment at night
terraform destroy -auto-approve

# Recreate in morning
terraform apply -auto-approve
```

### Staging
- Minimal replicas
- LoadBalancer for realistic testing
- Destroy after testing cycles

### Production
- Always running
- Multiple replicas
- Autoscaling
- Reserved instances for nodes

## Security

### State File Security

State files contain sensitive data:
- Resource IDs and ARNs
- Outputs (potentially including secrets)
- Provider credentials (if configured incorrectly)

Protect state files:
```hcl
# S3 bucket configuration
resource "aws_s3_bucket" "terraform_state" {
  bucket = "my-terraform-state"

  # Enable versioning
  versioning {
    enabled = true
  }

  # Enable encryption
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  # Block public access
  public_access_block {
    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true
  }
}
```

### IAM Permissions

Principle of least privilege:
- Developers: Full access to dev, read-only to prod
- DevOps: Full access to all environments
- CI/CD: Write access with conditions

Example IAM policy:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:*"],
      "Resource": [
        "arn:aws:s3:::my-terraform-state/dev/*",
        "arn:aws:s3:::my-terraform-state/staging/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject"],
      "Resource": "arn:aws:s3:::my-terraform-state/prod/*"
    }
  ]
}
```

## Troubleshooting

### State Lock Errors

```bash
# If state is locked and shouldn't be
terraform force-unlock <lock-id>

# Check DynamoDB table for lock
aws dynamodb get-item \
  --table-name terraform-state-lock \
  --key '{"LockID": {"S": "my-terraform-state/dev/terraform.tfstate-md5"}}'
```

### Module Not Found

```bash
# Re-initialize to download modules
terraform init -upgrade

# Or manually get modules
terraform get -update
```

### State Drift

```bash
# Detect drift
terraform plan -refresh-only

# Refresh state to match reality
terraform apply -refresh-only

# Or import resources that were created outside Terraform
terraform import <resource_type>.<name> <resource_id>
```

## Next Steps

1. **Add CI/CD** (Module 05): Automate deployments
2. **Implement GitOps**: Use tools like ArgoCD or Flux
3. **Add Policy as Code**: Use OPA or Sentinel
4. **Cost Management**: Implement Infracost
5. **Disaster Recovery**: Implement backup/restore procedures

## References

- [Terraform Modules](https://developer.hashicorp.com/terraform/language/modules)
- [Remote State](https://developer.hashicorp.com/terraform/language/state/remote)
- [Backend Configuration](https://developer.hashicorp.com/terraform/language/settings/backends/s3)
