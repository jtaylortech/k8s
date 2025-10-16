# Module 05: Advanced Patterns

**Duration**: ~2 hours
**Prerequisites**: [Module 04: Multi-Environment Patterns](../04-multi-environment/README.md)
**Next**: Build real projects!

## Learning Objectives

By the end of this module, you will:
- ✅ Integrate Terraform with CI/CD pipelines
- ✅ Implement GitOps workflows
- ✅ Use Terragrunt for DRY configuration
- ✅ Apply Policy as Code (OPA/Sentinel)
- ✅ Estimate and optimize costs
- ✅ Handle disaster recovery scenarios
- ✅ Debug and troubleshoot effectively

---

## Part 1: CI/CD Integration

### GitHub Actions Workflow

**File**: `.github/workflows/terraform-deploy.yml`
```yaml
name: Terraform Deploy

on:
  pull_request:
  push:
    branches:
      - main

env:
  AWS_REGION: us-west-2

jobs:
  terraform:
    name: Terraform Plan & Apply
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v3

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.6.0

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Terraform Init
        run: terraform init

      - name: Terraform Format Check
        run: terraform fmt -check -recursive

      - name: Terraform Validate
        run: terraform validate

      - name: Terraform Plan
        run: terraform plan -out=tfplan

      - name: Upload Plan
        uses: actions/upload-artifact@v3
        with:
          name: tfplan
          path: tfplan

      - name: Terraform Apply (on main)
        if: github.ref == 'refs/heads/main'
        run: terraform apply -auto-approve tfplan

      - name: Post Plan Comment (on PR)
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v6
        with:
          script: |
            const plan = require('fs').readFileSync('tfplan.txt', 'utf8');
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `## Terraform Plan\n\`\`\`\n${plan}\n\`\`\``
            })
```

### GitLab CI/CD

**File**: `.gitlab-ci.yml`
```yaml
image: hashicorp/terraform:latest

variables:
  TF_ROOT: ${CI_PROJECT_DIR}
  TF_STATE_NAME: default

stages:
  - validate
  - plan
  - apply

before_script:
  - cd ${TF_ROOT}
  - terraform init

validate:
  stage: validate
  script:
    - terraform validate
    - terraform fmt -check

plan:
  stage: plan
  script:
    - terraform plan -out=tfplan
  artifacts:
    paths:
      - tfplan
  only:
    - merge_requests
    - main

apply:
  stage: apply
  script:
    - terraform apply -auto-approve tfplan
  dependencies:
    - plan
  only:
    - main
  when: manual  # Require manual approval
```

---

## Part 2: Terragrunt for DRY

### What is Terragrunt?

Terragrunt is a wrapper for Terraform that helps keep your code DRY.

### Installation

```bash
brew install terragrunt
```

### Directory Structure

```
infrastructure/
├── terragrunt.hcl           # Root config
├── dev/
│   ├── us-west-2/
│   │   ├── eks/
│   │   │   └── terragrunt.hcl
│   │   └── vpc/
│   │       └── terragrunt.hcl
│   └── region.hcl
└── prod/
    ├── us-west-2/
    │   ├── eks/
    │   │   └── terragrunt.hcl
    │   └── vpc/
    │       └── terragrunt.hcl
    └── region.hcl
```

### Root Config

**File**: `terragrunt.hcl`
```hcl
remote_state {
  backend = "s3"
  config = {
    bucket         = "my-terraform-state-${get_aws_account_id()}"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = "terraform-lock"
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = var.aws_region
}
EOF
}
```

### Environment Config

**File**: `dev/us-west-2/eks/terragrunt.hcl`
```hcl
terraform {
  source = "github.com/myorg/terraform-modules//eks?ref=v1.0.0"
}

include "root" {
  path = find_in_parent_folders()
}

inputs = {
  cluster_name    = "dev-cluster"
  cluster_version = "1.28"
  node_count      = 2
  instance_type   = "t3.small"
}
```

### Commands

```bash
# Run in all modules
terragrunt run-all plan
terragrunt run-all apply

# Run dependencies first
terragrunt apply-all

# Destroy all
terragrunt run-all destroy
```

---

## Part 3: Policy as Code

### Open Policy Agent (OPA)

**Install Conftest**:
```bash
brew install conftest
```

**Policy**: Require tags on all resources

**File**: `policy/tags.rego`
```rego
package main

deny[msg] {
  resource := input.resource_changes[_]
  not resource.change.after.tags.Environment
  msg = sprintf("Resource %s missing Environment tag", [resource.address])
}

deny[msg] {
  resource := input.resource_changes[_]
  not resource.change.after.tags.ManagedBy
  msg = sprintf("Resource %s missing ManagedBy tag", [resource.address])
}
```

**Test Policy**:
```bash
# Generate plan JSON
terraform plan -out=tfplan
terraform show -json tfplan > plan.json

# Test with Conftest
conftest test plan.json

# Example output:
# FAIL - plan.json - Resource aws_eks_cluster.main missing Environment tag
```

### Sentinel (Terraform Cloud)

**File**: `sentinel.hcl`
```hcl
policy "enforce-mandatory-tags" {
  source = "./enforce-mandatory-tags.sentinel"
  enforcement_level = "hard-mandatory"
}

policy "restrict-instance-type" {
  source = "./restrict-instance-type.sentinel"
  enforcement_level = "soft-mandatory"
}
```

**File**: `restrict-instance-type.sentinel`
```
import "tfplan/v2" as tfplan

allowed_types = ["t3.small", "t3.medium"]

main = rule {
  all tfplan.resource_changes as _, rc {
    rc.type is "aws_instance" implies
      rc.change.after.instance_type in allowed_types
  }
}
```

---

## Part 4: Cost Estimation

### Infracost

**Installation**:
```bash
brew install infracost
infracost auth login
```

**Usage**:
```bash
# Generate cost estimate
infracost breakdown --path .

# Example output:
# ┌─────────────────────────────────────────────────────────────────┐
# │ Project: dev-cluster                                             │
# ├─────────────────────────────────────────────────────────────────┤
# │ aws_eks_cluster.main                          $73.00/month       │
# │ ├─ Control plane                              $73.00/month       │
# │ aws_eks_node_group.main                       $60.74/month       │
# │ ├─ EC2 instances (t3.medium × 2)              $60.74/month       │
# │ aws_nat_gateway.main                          $65.34/month       │
# │                                                                  │
# │ TOTAL                                         $199.08/month      │
# └─────────────────────────────────────────────────────────────────┘

# Compare changes
infracost diff --path . --compare-to tfplan.json

# CI Integration
infracost breakdown --path . --format json --out-file infracost.json
```

### CI Integration

**File**: `.github/workflows/infracost.yml`
```yaml
- name: Setup Infracost
  uses: infracost/actions/setup@v2
  with:
    api-key: ${{ secrets.INFRACOST_API_KEY }}

- name: Generate cost estimate
  run: |
    infracost breakdown --path . \
      --format json \
      --out-file /tmp/infracost.json

- name: Post comment
  run: |
    infracost comment github --path /tmp/infracost.json \
      --github-token ${{ secrets.GITHUB_TOKEN }} \
      --pull-request ${{ github.event.pull_request.number }} \
      --repo ${{ github.repository }}
```

---

## Part 5: Disaster Recovery

### State Recovery

**Scenario**: State file corrupted or lost

**Solution 1**: Restore from versioned S3
```bash
# List versions
aws s3api list-object-versions \
  --bucket my-terraform-state \
  --prefix eks/prod/

# Download specific version
aws s3api get-object \
  --bucket my-terraform-state \
  --key eks/prod/terraform.tfstate \
  --version-id <VERSION_ID> \
  terraform.tfstate
```

**Solution 2**: Import existing resources
```bash
# Import EKS cluster
terraform import aws_eks_cluster.main my-cluster-name

# Import node group
terraform import aws_eks_node_group.main my-cluster-name:my-node-group
```

### Backup Strategy

```hcl
# Enable S3 versioning (already in Module 04)
# Enable S3 replication for cross-region backup

resource "aws_s3_bucket_replication_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  role   = aws_iam_role.replication.arn

  rule {
    id     = "replicate-state"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.state_replica.arn
      storage_class = "STANDARD_IA"
    }
  }
}
```

---

## Part 6: Debugging and Troubleshooting

### Debug Logging

```bash
# Enable debug logs
export TF_LOG=DEBUG
export TF_LOG_PATH=terraform.log
terraform apply

# Levels: TRACE, DEBUG, INFO, WARN, ERROR
export TF_LOG=TRACE
```

### Common Issues

**Issue 1: State Lock**
```bash
# Error: Error locking state

# Solution: Force unlock (use carefully!)
terraform force-unlock <LOCK_ID>
```

**Issue 2: Resource Already Exists**
```bash
# Error: resource already exists

# Solution: Import it
terraform import aws_eks_cluster.main my-cluster
```

**Issue 3: Circular Dependency**
```bash
# Error: Cycle: resource A depends on resource B, which depends on A

# Solution: Use depends_on carefully, check for implicit cycles
```

### Drift Detection

```bash
# Detect configuration drift
terraform plan -detailed-exitcode

# Exit codes:
# 0 = no changes
# 1 = error
# 2 = changes detected

# Fix drift
terraform apply
```

---

## Part 7: Advanced Patterns

### Dynamic Blocks

```hcl
resource "aws_security_group" "dynamic" {
  name = "dynamic-sg"

  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }
}
```

### Conditional Resources

```hcl
resource "aws_instance" "optional" {
  count = var.create_instance ? 1 : 0

  # ... configuration
}
```

### For Expressions

```hcl
locals {
  instance_ids = [for instance in aws_instance.servers : instance.id]

  # With filtering
  prod_instances = [for k, v in aws_instance.servers : v.id if v.tags["env"] == "prod"]

  # Map transformation
  instance_map = {
    for instance in aws_instance.servers :
    instance.id => instance.private_ip
  }
}
```

---

## Hands-On Exercises

### Exercise 1: Full CI/CD Pipeline

Build complete pipeline:
1. Set up GitHub Actions
2. Add Infracost integration
3. Implement policy checks with OPA
4. Auto-apply on merge to main

### Exercise 2: Multi-Region Deployment

Deploy to multiple regions:
1. Use Terragrunt
2. Configure region-specific settings
3. Implement state replication

### Exercise 3: Zero-Downtime Migration

Migrate running cluster to new Terraform code:
1. Import existing resources
2. Refactor into modules
3. Apply with no disruption

---

## Validation Checklist

- [ ] Integrate Terraform with CI/CD
- [ ] Use Terragrunt for DRY config
- [ ] Implement policy as code
- [ ] Estimate infrastructure costs
- [ ] Handle disaster recovery scenarios
- [ ] Debug Terraform issues
- [ ] Use advanced Terraform features

---

## Key Takeaways

1. **Automate** Terraform with CI/CD
2. **Enforce policies** before apply
3. **Estimate costs** before deploying
4. **Backup state** for disaster recovery
5. **Use Terragrunt** for large projects
6. **Monitor drift** regularly
7. **Version everything** (modules, state, code)

---

## Production Checklist

Before going to production:

- [ ] Remote state with locking
- [ ] State backup/replication
- [ ] CI/CD pipeline
- [ ] Policy enforcement
- [ ] Cost monitoring
- [ ] Disaster recovery plan
- [ ] Team access controls
- [ ] Documentation
- [ ] Monitoring/alerting
- [ ] Change management process

---

## Additional Resources

- [Terragrunt Documentation](https://terragrunt.gruntwork.io/)
- [Infracost](https://www.infracost.io/)
- [Open Policy Agent](https://www.openpolicyagent.org/)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)

---

## Congratulations! 🎉

You've completed the Terraform track! You can now:
- Provision production EKS clusters
- Manage Kubernetes resources with Terraform
- Implement multi-environment setups
- Build CI/CD pipelines
- Apply advanced patterns

### Next Steps

1. **Build a project**: Deploy a real application end-to-end
2. **Contribute**: Share your modules with the community
3. **Deep dive**: Explore AWS EKS learning path (coming soon!)
4. **Certify**: Get HashiCorp Terraform Associate certification

---

**Stay tuned for**: Dedicated EKS learning path with CDK! 🚀
