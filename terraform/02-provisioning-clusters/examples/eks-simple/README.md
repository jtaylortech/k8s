# Simple EKS Cluster Example

Complete, production-ready EKS cluster with VPC, IAM, and managed node group.

## What This Creates

- VPC with public and private subnets across 2-3 AZs
- NAT Gateways for private subnet internet access
- EKS cluster (control plane)
- Managed node group with autoscaling
- All required IAM roles and policies
- Security groups

## Prerequisites

1. **AWS CLI configured**:
   ```bash
   aws configure
   aws sts get-caller-identity
   ```

2. **Terraform installed**:
   ```bash
   terraform version  # Should be >= 1.0
   ```

3. **kubectl installed**:
   ```bash
   kubectl version --client
   ```

## Usage

### 1. Configure Variables

```bash
# Copy example tfvars
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
vi terraform.tfvars
```

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Plan (Preview Changes)

```bash
terraform plan
```

Review the plan carefully. You should see ~40+ resources to be created.

### 4. Apply (Create Cluster)

```bash
terraform apply
```

Type `yes` to confirm. **This takes 10-15 minutes**.

### 5. Configure kubectl

```bash
# Terraform output shows the command
aws eks update-kubeconfig --region us-west-2 --name dev-eks-cluster

# Verify
kubectl get nodes
kubectl get pods -A
```

### 6. Test the Cluster

```bash
# Deploy test application
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=LoadBalancer

# Wait for LoadBalancer
kubectl get svc nginx -w

# Get URL and test
export LB_URL=$(kubectl get svc nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl http://$LB_URL

# Clean up test
kubectl delete svc nginx
kubectl delete deployment nginx
```

### 7. Destroy (IMPORTANT!)

```bash
# When done, destroy to avoid costs
terraform destroy
```

Type `yes` to confirm.

## Cost Estimate

Based on default configuration (us-west-2):
- **EKS Control Plane**: ~$73/month
- **Worker Nodes** (2x t3.medium): ~$120/month
- **NAT Gateways** (2): ~$64/month
- **Total**: ~$257/month

**To minimize costs**:
- Destroy when not in use
- Use t3.small instead of t3.medium
- Use spot instances (`node_capacity_type = "SPOT"`)
- Reduce to 1 AZ for dev (`azs_count = 2`)

## Customization

### Use Smaller Instances

```hcl
# terraform.tfvars
node_instance_types = ["t3.small"]
node_desired_size   = 1
```

### Use Spot Instances

```hcl
# terraform.tfvars
node_capacity_type = "SPOT"
```

### Enable Logging

Uncomment in `eks.tf`:
```hcl
enabled_cluster_log_types = ["api", "audit"]
```

## Troubleshooting

### Cluster creation fails

Check IAM permissions:
```bash
aws sts get-caller-identity
```

### Nodes not joining

Check node group status:
```bash
aws eks describe-nodegroup \
  --cluster-name dev-eks-cluster \
  --nodegroup-name dev-eks-cluster-node-group
```

### kubectl can't connect

Update kubeconfig:
```bash
aws eks update-kubeconfig \
  --region us-west-2 \
  --name dev-eks-cluster
```

## Next Steps

1. Install add-ons (see Module 03)
2. Deploy applications with Terraform
3. Set up monitoring
4. Implement GitOps

## Files

- `providers.tf` - Terraform and AWS provider config
- `variables.tf` - Input variables
- `vpc.tf` - VPC and networking
- `eks.tf` - EKS cluster and node group
- `outputs.tf` - Useful outputs
- `terraform.tfvars.example` - Example variable values

## References

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
