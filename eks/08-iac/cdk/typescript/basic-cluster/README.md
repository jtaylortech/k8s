# Basic EKS Cluster with CDK (TypeScript)

Complete, working example of an EKS cluster using AWS CDK.

## What This Creates

- EKS 1.28 cluster
- VPC with public and private subnets
- Managed node group (2x t3.medium)
- IAM roles and OIDC provider
- kubectl configuration
- **Cost:** ~$135/month

## Prerequisites

```bash
node --version  # v16+
npm --version
aws configure
kubectl version --client
```

## Quick Start

### 1. Install Dependencies

```bash
npm install
```

### 2. Bootstrap CDK (First Time Only)

```bash
# Replace with your account ID and region
cdk bootstrap aws://123456789012/us-west-2
```

### 3. Review What Will Be Created

```bash
cdk synth
```

### 4. Deploy

```bash
cdk deploy
```

**Time:** 15-20 minutes

### 5. Configure kubectl

```bash
# Command will be in CDK output
aws eks update-kubeconfig --region us-west-2 --name BasicEksCluster
```

### 6. Verify

```bash
kubectl get nodes
kubectl get pods -A
```

### 7. Clean Up

```bash
cdk destroy
```

## Project Structure

```
basic-cluster/
├── README.md
├── package.json
├── tsconfig.json
├── cdk.json
├── bin/
│   └── basic-cluster.ts      # App entry point
├── lib/
│   └── basic-cluster-stack.ts # Stack definition
└── test/
    └── basic-cluster.test.ts  # Unit tests
```

## Customization

### Change Instance Type

Edit `lib/basic-cluster-stack.ts`:

```typescript
defaultCapacityInstance: ec2.InstanceType.of(
  ec2.InstanceClass.T3,
  ec2.InstanceSize.SMALL  // Change to SMALL for cost savings
),
```

### Change Number of Nodes

```typescript
defaultCapacity: 2,  // Change this number
```

### Use Different Region

Edit `bin/basic-cluster.ts`:

```typescript
env: {
  account: process.env.CDK_DEFAULT_ACCOUNT,
  region: 'us-east-1',  // Change region here
},
```

## Testing

```bash
npm test
```

## CDK Commands

```bash
# List stacks
cdk list

# Show CloudFormation template
cdk synth

# Compare deployed vs local
cdk diff

# Deploy
cdk deploy

# Destroy
cdk destroy
```

## Troubleshooting

### "Cluster creation failed"

Check CloudFormation:
```bash
aws cloudformation describe-stacks --stack-name BasicClusterStack
aws cloudformation describe-stack-events --stack-name BasicClusterStack
```

### "Can't connect with kubectl"

Update kubeconfig:
```bash
aws eks update-kubeconfig --region us-west-2 --name BasicEksCluster
kubectl config get-contexts
kubectl config use-context <context-name>
```

### "Nodes not ready"

Check node group:
```bash
aws eks describe-nodegroup \
  --cluster-name BasicEksCluster \
  --nodegroup-name <nodegroup-name>

kubectl describe nodes
```

## Next Steps

- Deploy an application: `kubectl create deployment nginx --image=nginx`
- Add more node groups
- Install add-ons (metrics-server, cluster-autoscaler)
- Check [production-cluster](../production-cluster/) for advanced patterns

## Cost Estimate

- EKS Control Plane: ~$73/month
- 2x t3.medium nodes: ~$60/month
- NAT Gateway: ~$32/month
- **Total: ~$165/month**

To reduce costs:
- Use t3.small: -$30/month
- Use single NAT gateway (dev only): -$32/month
- Use Spot instances: -70%
