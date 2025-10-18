# Module 02: EKS Networking Deep Dive

**Duration:** 6 hours
**Level:** Intermediate

## Learning Objectives

By the end of this module, you will:
- Understand EKS networking architecture
- Design production-ready VPCs for EKS
- Master the Amazon VPC CNI plugin
- Configure security groups and NACLs
- Manage IP address allocation
- Implement custom networking patterns

## Table of Contents

1. [VPC Design for EKS](#vpc-design-for-eks)
2. [Amazon VPC CNI Plugin](#amazon-vpc-cni-plugin)
3. [IP Address Management](#ip-address-management)
4. [Security Groups](#security-groups)
5. [Custom Networking](#custom-networking)
6. [Prefix Delegation](#prefix-delegation)
7. [Hands-On Labs](#hands-on-labs)

## VPC Design for EKS

### Architecture Patterns

**Production Pattern (Recommended):**

```
VPC: 10.0.0.0/16 (65,536 IPs)

AZ-A:
  Public Subnet:  10.0.0.0/24   (256 IPs) - Load Balancers, NAT Gateway
  Private Subnet: 10.0.32.0/19  (8,192 IPs) - EKS Nodes

AZ-B:
  Public Subnet:  10.0.1.0/24   (256 IPs) - Load Balancers, NAT Gateway
  Private Subnet: 10.0.64.0/19  (8,192 IPs) - EKS Nodes

AZ-C:
  Public Subnet:  10.0.2.0/24   (256 IPs) - Load Balancers, NAT Gateway
  Private Subnet: 10.0.96.0/19  (8,192 IPs) - EKS Nodes
```

**Why this design?**
- Private subnets have large CIDR blocks for pod IPs
- Public subnets are small (only for LBs and NAT)
- 3 AZs for high availability
- Each AZ gets its own NAT Gateway

### Subnet Requirements

**EKS Requirements:**
- Minimum 2 subnets across 2 AZs
- Subnets must be in the same VPC
- Subnets must have internet connectivity (via NAT or IGW)
- Subnets must have available IP addresses

**Subnet Tagging:**
```bash
# Public subnets (for external load balancers)
kubernetes.io/role/elb = 1

# Private subnets (for internal load balancers)
kubernetes.io/role/internal-elb = 1

# Cluster-specific tag
kubernetes.io/cluster/<cluster-name> = shared
```

### NAT Gateway Strategies

**Production (High Availability):**
```
One NAT Gateway per AZ
Cost: ~$96/month (3 × $32)
Benefit: No single point of failure
```

**Development (Cost Optimized):**
```
Single NAT Gateway
Cost: ~$32/month
Caveat: Single point of failure
```

**Cost Comparison:**
```
3 NAT Gateways: $96/month + data transfer
1 NAT Gateway:  $32/month + data transfer
Savings:        $64/month (67%)
```

## Amazon VPC CNI Plugin

### How It Works

The VPC CNI plugin assigns AWS VPC IP addresses to pods:

1. **Node launches**: ENIs attached to EC2 instance
2. **Pod scheduled**: IP from ENI assigned to pod
3. **Pod gets VPC IP**: Pod can communicate directly with VPC resources

**Benefits:**
- Pods are first-class VPC citizens
- Native VPC networking (no overlay)
- Use VPC security groups and NACLs
- Lower latency than overlay networks
- Simpler troubleshooting

**Tradeoffs:**
- Consumes VPC IP addresses
- IP address planning required
- Limited pods per node (based on instance type)

### Pod Limits by Instance Type

```
t3.small:   11 pods (3 ENIs × 4 IPs - 3 reserved)
t3.medium:  17 pods (3 ENIs × 6 IPs - 3 reserved)
t3.large:   35 pods (3 ENIs × 12 IPs - 3 reserved)
m5.large:   29 pods (3 ENIs × 10 IPs - 3 reserved)
m5.xlarge:  58 pods (4 ENIs × 15 IPs - 4 reserved)
```

Formula: `(ENIs × IPs per ENI) - Reserved IPs`

Check limits: https://github.com/aws/amazon-vpc-cni-k8s/blob/master/pkg/awsutils/vpc_ip_resource_limit.go

### CNI Configuration

**View current config:**
```bash
kubectl get daemonset aws-node -n kube-system -o yaml
```

**Key environment variables:**

```yaml
env:
  # Enable prefix delegation (more pods per node)
  - name: ENABLE_PREFIX_DELEGATION
    value: "true"

  # Warm pool of ENIs
  - name: WARM_ENI_TARGET
    value: "1"

  # Warm pool of IPs
  - name: WARM_IP_TARGET
    value: "5"

  # Minimum IPs to maintain
  - name: MINIMUM_IP_TARGET
    value: "10"

  # Enable custom networking
  - name: AWS_VPC_K8S_CNI_CUSTOM_NETWORK_CFG
    value: "true"

  # External SNAT (for pods to access internet)
  - name: AWS_VPC_K8S_CNI_EXTERNALSNAT
    value: "false"
```

## IP Address Management

### Planning Pod IPs

**Calculate required IPs:**

```
Nodes: 10
Pods per node: 30
Total pods: 300

With 20% overhead: 360 IPs required
Recommended subnet: /23 (512 IPs)
```

**Subnet sizing:**
```
/24 = 256 IPs (small clusters, 8-10 nodes)
/23 = 512 IPs (medium clusters, 15-20 nodes)
/22 = 1,024 IPs (large clusters, 30-40 nodes)
/21 = 2,048 IPs (very large clusters)
/20 = 4,096 IPs (extra large clusters)
```

### IP Address Exhaustion

**Symptoms:**
- Pods stuck in `Pending` state
- Events: `failed to assign an IP address to container`
- Node running out of ENI capacity

**Solutions:**

**1. Increase Subnet Size:**
```bash
# Create new, larger subnets
# Migrate node groups to new subnets
```

**2. Enable Prefix Delegation:**
```bash
kubectl set env daemonset aws-node \
  -n kube-system \
  ENABLE_PREFIX_DELEGATION=true
```

**3. Use Custom Networking:**
```bash
# Separate pod networking from node networking
kubectl set env daemonset aws-node \
  -n kube-system \
  AWS_VPC_K8S_CNI_CUSTOM_NETWORK_CFG=true
```

## Security Groups

### Default Security Groups

**Cluster Security Group:**
- Created automatically by EKS
- Attached to control plane ENIs
- Attached to worker nodes
- Allows communication between control plane and nodes

**Node Security Group:**
- Created by node group or launch template
- Additional security rules
- SSH access (optional)
- Application-specific ports

### Security Group Rules

**Minimum Required Rules:**

```
Ingress:
- Protocol: All, Source: Cluster SG (node-to-node communication)
- Protocol: TCP, Port: 443, Source: Control Plane SG (kubelet API)
- Protocol: TCP, Port: 10250, Source: Control Plane SG (kubelet metrics)

Egress:
- Protocol: All, Destination: 0.0.0.0/0 (internet access via NAT)
```

### Security Groups for Pods

EKS supports assigning security groups directly to pods:

**Enable:**
```bash
kubectl apply -f https://raw.githubusercontent.com/aws/amazon-vpc-cni-k8s/master/config/master/aws-k8s-cni.yaml
```

**Create SecurityGroupPolicy:**
```yaml
apiVersion: vpcresources.k8s.aws/v1beta1
kind: SecurityGroupPolicy
metadata:
  name: my-app-sg-policy
spec:
  podSelector:
    matchLabels:
      app: my-app
  securityGroups:
    groupIds:
      - sg-0123456789abcdef0
```

**Benefits:**
- Fine-grained security control
- Pod-level network policies
- RDS/EFS access without node-level rules

## Custom Networking

Custom networking separates node IPs from pod IPs.

**Use cases:**
- VPC IP address exhaustion
- Pods in different subnets than nodes
- Pods in dedicated secondary CIDR blocks

**Enable custom networking:**

**1. Create ENIConfig:**
```yaml
apiVersion: crd.k8s.amazonaws.com/v1alpha1
kind: ENIConfig
metadata:
  name: us-west-2a
spec:
  subnet: subnet-0123456789abcdef0  # Pod subnet
  securityGroups:
    - sg-0123456789abcdef0
```

**2. Enable in CNI:**
```bash
kubectl set env daemonset aws-node \
  -n kube-system \
  AWS_VPC_K8S_CNI_CUSTOM_NETWORK_CFG=true \
  ENI_CONFIG_LABEL_DEF=topology.kubernetes.io/zone
```

**3. Launch nodes:**
```bash
# Nodes will use ENIConfig based on their AZ
```

## Prefix Delegation

Prefix delegation increases pods per node by assigning /28 prefixes instead of individual IPs.

**Before:**
```
t3.medium: 17 pods (3 ENIs × 6 IPs)
```

**After (with prefix delegation):**
```
t3.medium: 110 pods (3 ENIs × 16 IPs × prefix)
```

**Enable:**
```bash
kubectl set env daemonset aws-node \
  -n kube-system \
  ENABLE_PREFIX_DELEGATION=true
```

**Benefits:**
- Significantly more pods per node
- Reduced subnet IP consumption
- Better cluster density

**Considerations:**
- Requires recent instance types
- Check instance type support
- Test before production use

## Hands-On Labs

### Lab 1: Create Production VPC

**Terraform:**
```hcl
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "eks-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-west-2a", "us-west-2b", "us-west-2c"]
  private_subnets = ["10.0.32.0/19", "10.0.64.0/19", "10.0.96.0/19"]
  public_subnets  = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]

  enable_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = {
    "kubernetes.io/cluster/my-cluster" = "shared"
  }
}
```

### Lab 2: Monitor IP Usage

```bash
# Check available IPs per subnet
aws ec2 describe-subnets \
  --subnet-ids subnet-xxx \
  --query 'Subnets[0].AvailableIpAddressCount'

# View CNI metrics
kubectl get pods -n kube-system -l k8s-app=aws-node

# Check pod IP allocations
kubectl get nodes -o json | jq '.items[] | .status.allocatable'
```

### Lab 3: Enable Prefix Delegation

```bash
# Enable prefix delegation
kubectl set env daemonset aws-node \
  -n kube-system \
  ENABLE_PREFIX_DELEGATION=true

# Verify
kubectl describe daemonset aws-node -n kube-system | grep PREFIX

# Create test deployment
kubectl create deployment nginx --image=nginx --replicas=20

# Check pod distribution
kubectl get pods -o wide
```

## Best Practices

1. **Use /19 or larger for private subnets** - Ensures enough pod IPs
2. **Enable prefix delegation** - Maximizes pod density
3. **Use custom networking** - If running low on VPC IPs
4. **Tag subnets correctly** - Required for load balancer discovery
5. **Monitor IP usage** - Set up CloudWatch alarms
6. **Plan for growth** - Over-provision IP space
7. **Use security groups for pods** - Fine-grained security
8. **3 AZs in production** - High availability
9. **Separate node and pod subnets** - Custom networking
10. **Document IP allocations** - Avoid future conflicts

## Troubleshooting

### Pods Can't Get IPs

```bash
# Check available IPs
aws ec2 describe-subnets --subnet-ids subnet-xxx

# Check CNI logs
kubectl logs -n kube-system -l k8s-app=aws-node --tail=100

# Verify ENI attachments
aws ec2 describe-network-interfaces \
  --filters "Name=attachment.instance-id,Values=i-xxx"
```

### Node Network Issues

```bash
# Check security groups
aws ec2 describe-security-groups --group-ids sg-xxx

# Verify routing
kubectl exec -it <pod> -- ip route

# Check DNS
kubectl exec -it <pod> -- nslookup kubernetes.default
```

## Quiz

1. How many NAT Gateways should production EKS clusters use?
   - [ ] 1
   - [x] 1 per AZ (3 for 3 AZs)
   - [ ] 1 per node group
   - [ ] None

2. What does the VPC CNI plugin do?
   - [ ] Creates overlay network
   - [x] Assigns VPC IPs to pods
   - [ ] Manages DNS
   - [ ] Handles load balancing

3. What increases pod density per node?
   - [ ] Larger instance types only
   - [ ] More ENIs
   - [x] Prefix delegation
   - [ ] Faster networking

4. Which subnet tag is required for external load balancers?
   - [ ] kubernetes.io/cluster
   - [x] kubernetes.io/role/elb
   - [ ] kubernetes.io/elb
   - [ ] aws/load-balancer

## Next Steps

Continue to [Module 03: IAM and Security](../03-iam-security/README.md)

## Additional Resources

- [VPC CNI Documentation](https://docs.aws.amazon.com/eks/latest/userguide/pod-networking.html)
- [EKS Networking Best Practices](https://aws.github.io/aws-eks-best-practices/networking/)
- [Prefix Delegation Guide](https://aws.amazon.com/blogs/containers/amazon-vpc-cni-increases-pods-per-node-limits/)
- [Custom Networking Tutorial](https://docs.aws.amazon.com/eks/latest/userguide/cni-custom-network.html)
