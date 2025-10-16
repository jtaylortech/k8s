# Module 08: Infrastructure as Code for EKS

**Duration:** 4 hours
**Level:** Intermediate

## Overview

Learn to manage EKS infrastructure using code with both Terraform and AWS CDK approaches.

## Learning Objectives

- Understand IaC benefits for EKS
- Use Terraform to provision EKS clusters
- Use AWS CDK to provision EKS clusters
- Compare eksctl, Terraform, and CDK
- Implement CI/CD for infrastructure
- Manage multi-environment deployments

## Tools Covered

- **eksctl**: Quick cluster creation
- **Terraform**: Mature, cloud-agnostic IaC
- **AWS CDK**: AWS-native, programming language-based IaC
- **Pulumi**: Alternative programming-based IaC (bonus)

## Directory Structure

```
08-iac/
├── README.md
├── terraform/
│   ├── README.md
│   ├── basic-cluster/
│   ├── production-cluster/
│   └── modules/
├── cdk/
│   ├── README.md
│   ├── typescript/
│   │   ├── basic-cluster/
│   │   ├── production-cluster/
│   │   └── advanced-patterns/
│   └── python/
│       ├── basic-cluster/
│       ├── production-cluster/
│       └── advanced-patterns/
└── comparison.md
```

## Tool Comparison

| Feature | eksctl | Terraform | AWS CDK |
|---------|--------|-----------|---------|
| **Language** | YAML | HCL | TypeScript/Python/Java/Go |
| **Learning Curve** | Easy | Medium | Medium-High |
| **EKS-Specific** | Yes | No | No |
| **Cloud Support** | AWS only | Multi-cloud | AWS only |
| **State Management** | CloudFormation | Terraform state | CloudFormation |
| **IDE Support** | Limited | Good | Excellent |
| **Type Safety** | No | Limited | Yes (TypeScript) |
| **Abstraction Level** | High | Medium | Variable |
| **Testing** | Limited | terraform test | Full unit/integration tests |
| **Community** | Large | Very Large | Growing |

### When to Use Each

**eksctl:**
- Quick development clusters
- Learning EKS
- Simple requirements
- Fast iteration

**Terraform:**
- Multi-cloud environments
- Existing Terraform infrastructure
- Mature tooling needs
- State management preferences

**AWS CDK:**
- AWS-only infrastructure
- Complex logic/conditions
- Type safety requirements
- Developer-friendly approach
- Integration with application code

## Getting Started

### Install Tools

```bash
# Terraform
brew install terraform

# AWS CDK
npm install -g aws-cdk

# Verify
terraform version
cdk --version
```

### Choose Your Path

1. [Terraform Examples](./terraform/README.md)
2. [CDK Examples - TypeScript](./cdk/typescript/README.md)
3. [CDK Examples - Python](./cdk/python/README.md)

## Quick Start

### Terraform

```bash
cd terraform/basic-cluster
terraform init
terraform plan
terraform apply
```

### CDK (TypeScript)

```bash
cd cdk/typescript/basic-cluster
npm install
cdk bootstrap  # First time only
cdk deploy
```

### CDK (Python)

```bash
cd cdk/python/basic-cluster
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cdk bootstrap  # First time only
cdk deploy
```

## Key Concepts

### Infrastructure as Code Benefits

**Version Control:**
- Track all infrastructure changes
- Code review for infrastructure
- Easy rollback

**Reproducibility:**
- Consistent environments
- Disaster recovery
- Multiple regions/accounts

**Automation:**
- CI/CD integration
- Automated testing
- Scheduled updates

**Documentation:**
- Code is documentation
- Self-documenting architecture
- Easier onboarding

### Best Practices

**1. Use Modules/Constructs**
```typescript
// Reusable CDK construct
const cluster = new eks.Cluster(this, 'MyCluster', {
  version: eks.KubernetesVersion.V1_28,
  defaultCapacity: 0,
});
```

**2. Separate Environments**
```
terraform/
├── environments/
│   ├── dev/
│   ├── staging/
│   └── prod/
```

**3. Use Remote State**
```hcl
terraform {
  backend "s3" {
    bucket = "my-terraform-state"
    key    = "eks/terraform.tfstate"
  }
}
```

**4. Implement Testing**
```typescript
test('cluster has correct version', () => {
  const template = Template.fromStack(stack);
  template.hasResourceProperties('AWS::EKS::Cluster', {
    Version: '1.28'
  });
});
```

## Advanced Patterns

### Multi-Environment

**CDK with context:**
```typescript
const env = this.node.tryGetContext('environment') || 'dev';
const config = {
  dev: { instanceType: 't3.medium', nodes: 2 },
  prod: { instanceType: 't3.large', nodes: 5 }
};
```

**Terraform with workspaces:**
```bash
terraform workspace new prod
terraform workspace select prod
terraform apply -var-file=prod.tfvars
```

### GitOps Integration

**Flux with CDK:**
```typescript
const fluxAddon = new FluxAddon({
  gitRepository: 'https://github.com/myorg/manifests',
  path: './clusters/production',
  syncInterval: Duration.minutes(5),
});

cluster.addManifest('FluxSystem', fluxAddon);
```

### Blue-Green Deployments

**Create parallel clusters:**
```typescript
const blueCluster = new eks.Cluster(this, 'Blue', { ... });
const greenCluster = new eks.Cluster(this, 'Green', { ... });

// Switch traffic via Route53
const distribution = new WeightedRecord(this, 'Distribution', {
  blue: { weight: 90 },
  green: { weight: 10 },
});
```

## Cost Optimization

### Terraform

```hcl
# Spot instances
resource "aws_eks_node_group" "spot" {
  capacity_type = "SPOT"
  instance_types = ["t3.medium", "t3a.medium"]
}

# Autoscaling
resource "aws_autoscaling_policy" "scale_down" {
  scaling_adjustment = -1
  adjustment_type = "ChangeInCapacity"
}
```

### CDK

```typescript
// Spot instances
cluster.addNodegroupCapacity('spot', {
  capacityType: eks.CapacityType.SPOT,
  instanceTypes: [
    new ec2.InstanceType('t3.medium'),
    new ec2.InstanceType('t3a.medium'),
  ],
});

// Karpenter for advanced autoscaling
new KarpenterAddon(cluster, {
  version: 'v0.32.0',
});
```

## CI/CD Integration

### GitHub Actions with Terraform

```yaml
name: Terraform
on:
  push:
    branches: [main]

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: hashicorp/setup-terraform@v2
      - run: terraform init
      - run: terraform plan
      - run: terraform apply -auto-approve
```

### GitHub Actions with CDK

```yaml
name: CDK Deploy
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
      - run: npm install
      - run: npm test
      - run: cdk deploy --require-approval never
```

## Cleanup

```bash
# Terraform
terraform destroy

# CDK
cdk destroy

# eksctl
eksctl delete cluster --name my-cluster
```

## Next Steps

1. Choose your IaC tool (Terraform or CDK)
2. Complete the examples in your chosen tool
3. Implement CI/CD pipeline
4. Add testing and validation
5. Deploy to production

## Additional Resources

- [Terraform AWS Provider - EKS](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_cluster)
- [AWS CDK EKS Module](https://docs.aws.amazon.com/cdk/api/v2/docs/aws-cdk-lib.aws_eks-readme.html)
- [EKS Blueprints (CDK)](https://aws.github.io/cdk-eks-blueprints/)
- [Terraform EKS Blueprints](https://github.com/aws-ia/terraform-aws-eks-blueprints)
