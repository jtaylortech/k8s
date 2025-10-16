# eksctl Cheat Sheet

Quick reference for eksctl commands.

## Cluster Management

### Create Cluster

```bash
# Basic cluster
eksctl create cluster

# Customized cluster
eksctl create cluster \
  --name my-cluster \
  --region us-west-2 \
  --version 1.28 \
  --nodegroup-name workers \
  --node-type t3.medium \
  --nodes 3 \
  --nodes-min 1 \
  --nodes-max 4 \
  --managed

# From config file
eksctl create cluster -f cluster.yaml

# Dry run (show what would be created)
eksctl create cluster --dry-run -f cluster.yaml
```

### List Clusters

```bash
# List all clusters
eksctl get cluster

# List clusters in specific region
eksctl get cluster --region us-west-2

# Get cluster details
eksctl get cluster --name my-cluster -o yaml
```

### Delete Cluster

```bash
# Delete cluster
eksctl delete cluster --name my-cluster

# Delete cluster in specific region
eksctl delete cluster --name my-cluster --region us-west-2

# Delete with wait (default behavior)
eksctl delete cluster --name my-cluster --wait

# Force delete (skip confirmation)
eksctl delete cluster --name my-cluster --force
```

### Update Cluster

```bash
# Update cluster endpoint access
eksctl utils update-cluster-endpoints \
  --cluster my-cluster \
  --private-access=true \
  --public-access=true

# Update Kubernetes version
eksctl upgrade cluster --name my-cluster --version 1.28

# Approve version upgrade
eksctl upgrade cluster --name my-cluster --approve
```

## Node Group Management

### Create Node Group

```bash
# Create managed node group
eksctl create nodegroup \
  --cluster my-cluster \
  --name workers \
  --node-type t3.medium \
  --nodes 3 \
  --nodes-min 1 \
  --nodes-max 4 \
  --managed

# Create node group with Spot instances
eksctl create nodegroup \
  --cluster my-cluster \
  --name spot-workers \
  --node-type t3.medium \
  --nodes 3 \
  --spot

# From config file
eksctl create nodegroup -f nodegroup.yaml
```

### List Node Groups

```bash
# List all node groups
eksctl get nodegroup --cluster my-cluster

# Get node group details
eksctl get nodegroup --cluster my-cluster --name workers -o yaml
```

### Scale Node Group

```bash
# Scale node group
eksctl scale nodegroup \
  --cluster my-cluster \
  --name workers \
  --nodes 5

# Scale to specific min/max
eksctl scale nodegroup \
  --cluster my-cluster \
  --name workers \
  --nodes 3 \
  --nodes-min 1 \
  --nodes-max 10
```

### Delete Node Group

```bash
# Delete node group
eksctl delete nodegroup \
  --cluster my-cluster \
  --name workers

# Delete with drain (recommended)
eksctl delete nodegroup \
  --cluster my-cluster \
  --name workers \
  --drain

# Force delete (skip confirmation)
eksctl delete nodegroup \
  --cluster my-cluster \
  --name workers \
  --approve
```

## Fargate

### Create Fargate Profile

```bash
# Create Fargate profile
eksctl create fargateprofile \
  --cluster my-cluster \
  --name my-app \
  --namespace my-app

# With selectors
eksctl create fargateprofile \
  --cluster my-cluster \
  --name my-app \
  --namespace my-app \
  --labels app=my-app,env=prod
```

### List Fargate Profiles

```bash
eksctl get fargateprofile --cluster my-cluster
```

### Delete Fargate Profile

```bash
eksctl delete fargateprofile \
  --cluster my-cluster \
  --name my-app
```

## IAM

### Create IAM Service Account

```bash
# Create service account with IAM role
eksctl create iamserviceaccount \
  --cluster my-cluster \
  --name my-app \
  --namespace default \
  --attach-policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess \
  --approve

# With custom policy
eksctl create iamserviceaccount \
  --cluster my-cluster \
  --name my-app \
  --namespace default \
  --attach-policy-arn arn:aws:iam::123456789:policy/MyCustomPolicy \
  --approve
```

### List IAM Service Accounts

```bash
eksctl get iamserviceaccount --cluster my-cluster
```

### Delete IAM Service Account

```bash
eksctl delete iamserviceaccount \
  --cluster my-cluster \
  --name my-app \
  --namespace default
```

### Enable OIDC Provider

```bash
eksctl utils associate-iam-oidc-provider \
  --cluster my-cluster \
  --approve
```

## Add-ons

### Install AWS Load Balancer Controller

```bash
eksctl create iamserviceaccount \
  --cluster my-cluster \
  --namespace kube-system \
  --name aws-load-balancer-controller \
  --attach-policy-arn arn:aws:iam::123456789:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=my-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

### List Add-ons

```bash
eksctl get addons --cluster my-cluster
```

## kubectl Configuration

### Update kubeconfig

```bash
# Update kubeconfig for cluster
eksctl utils write-kubeconfig --cluster my-cluster

# Update with specific context name
eksctl utils write-kubeconfig --cluster my-cluster --kubeconfig ~/.kube/config --set-kubeconfig-context=false

# Update for all clusters in region
eksctl utils write-kubeconfig --region us-west-2 --all-clusters
```

## Utilities

### Generate Config File

```bash
# Generate cluster config from existing cluster
eksctl get cluster --name my-cluster -o yaml > cluster.yaml
```

### Enable Logging

```bash
# Enable control plane logging
eksctl utils update-cluster-logging \
  --cluster my-cluster \
  --enable-types all \
  --approve

# Enable specific log types
eksctl utils update-cluster-logging \
  --cluster my-cluster \
  --enable-types api,audit,authenticator \
  --approve

# Disable logging
eksctl utils update-cluster-logging \
  --cluster my-cluster \
  --disable-types all \
  --approve
```

### Describe Stacks

```bash
# Show CloudFormation stacks
eksctl utils describe-stacks --cluster my-cluster --region us-west-2
```

### Update AWS Node (VPC CNI)

```bash
# Update VPC CNI plugin
eksctl utils update-aws-node --cluster my-cluster --approve
```

### Update CoreDNS

```bash
# Update CoreDNS
eksctl utils update-coredns --cluster my-cluster --approve
```

### Update kube-proxy

```bash
# Update kube-proxy
eksctl utils update-kube-proxy --cluster my-cluster --approve
```

## Configuration File Examples

### Basic Cluster

```yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: my-cluster
  region: us-west-2
  version: "1.28"

managedNodeGroups:
  - name: workers
    instanceType: t3.medium
    desiredCapacity: 2
    minSize: 1
    maxSize: 4
```

### Production Cluster

```yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: prod-cluster
  region: us-west-2
  version: "1.28"

vpc:
  cidr: 10.0.0.0/16
  nat:
    gateway: HighlyAvailable

iam:
  withOIDC: true

managedNodeGroups:
  - name: critical
    instanceType: t3.large
    desiredCapacity: 3
    minSize: 3
    maxSize: 10
    labels:
      role: critical
    taints:
      - key: critical
        value: "true"
        effect: NoSchedule

  - name: general
    instanceTypes: ["t3.medium", "t3a.medium"]
    spot: true
    desiredCapacity: 2
    minSize: 0
    maxSize: 20
    labels:
      role: general

cloudWatch:
  clusterLogging:
    enableTypes:
      - api
      - audit
      - authenticator
      - controllerManager
      - scheduler
```

## Common Options

### Global Flags

```bash
--region            # AWS region
--profile           # AWS profile
--verbose           # Verbose output
--color             # Enable/disable color (default: auto)
--timeout           # Operation timeout (default: 25m)
```

### Node Group Options

```bash
--nodes             # Desired number of nodes
--nodes-min         # Minimum nodes
--nodes-max         # Maximum nodes
--node-type         # EC2 instance type
--node-volume-size  # Node volume size in GB
--node-volume-type  # EBS volume type (gp2, gp3, io1)
--node-ami          # Custom AMI
--node-ami-family   # AMI family (AmazonLinux2, Ubuntu2004, Bottlerocket)
--spot              # Use Spot instances
--ssh-access        # Enable SSH access
--ssh-public-key    # SSH public key path
--managed           # Create managed node group
```

## Tips & Tricks

### Quick Dev Cluster

```bash
eksctl create cluster \
  --name dev \
  --nodes 1 \
  --node-type t3.small \
  --managed
```

### Cost-Optimized Cluster

```bash
eksctl create cluster \
  --name budget \
  --nodes 2 \
  --node-type t3.medium \
  --spot \
  --managed
```

### High-Availability Cluster

```bash
eksctl create cluster \
  --name ha \
  --nodes 3 \
  --nodes-min 3 \
  --nodes-max 10 \
  --node-type t3.large \
  --managed \
  --zones us-west-2a,us-west-2b,us-west-2c
```

## Troubleshooting

```bash
# Check eksctl version
eksctl version

# Verbose output for debugging
eksctl create cluster --name test --verbose 4

# Show CloudFormation stacks
eksctl utils describe-stacks --cluster my-cluster

# Check AWS credentials
aws sts get-caller-identity

# Validate config file
eksctl create cluster --config-file cluster.yaml --dry-run
```

## Additional Resources

- [eksctl Documentation](https://eksctl.io/)
- [GitHub Repository](https://github.com/weaveworks/eksctl)
- [Example Configurations](https://github.com/weaveworks/eksctl/tree/main/examples)
