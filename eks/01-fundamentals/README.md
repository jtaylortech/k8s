# Module 01: EKS Fundamentals

**Duration:** 4 hours
**Level:** Beginner

## Learning Objectives

By the end of this module, you will:
- Understand EKS architecture and components
- Know when to use EKS vs self-managed Kubernetes
- Create your first EKS cluster
- Connect to the cluster with kubectl
- Deploy a basic application
- Understand EKS pricing model

## Table of Contents

1. [What is Amazon EKS?](#what-is-amazon-eks)
2. [Architecture Overview](#architecture-overview)
3. [EKS vs Self-Managed Kubernetes](#eks-vs-self-managed-kubernetes)
4. [Pricing](#pricing)
5. [Hands-On: Create Your First Cluster](#hands-on-create-your-first-cluster)
6. [Deploy Your First Application](#deploy-your-first-application)
7. [Clean Up](#clean-up)
8. [Quiz](#quiz)

## What is Amazon EKS?

Amazon Elastic Kubernetes Service (EKS) is a managed Kubernetes service that makes it easy to run Kubernetes on AWS without needing to install, operate, and maintain your own Kubernetes control plane.

### Key Benefits

**Fully Managed Control Plane:**
- AWS manages the Kubernetes control plane
- Automatic updates and patches
- Built-in high availability across multiple AZs
- No control plane management overhead

**Deep AWS Integration:**
- IAM for authentication
- VPC for networking
- ELB for load balancing
- EBS/EFS for storage
- CloudWatch for monitoring
- Secrets Manager for secrets

**Compliance and Security:**
- SOC, PCI, ISO certified
- HIPAA eligible
- Encryption at rest and in transit
- Security patches automatically applied

**Kubernetes Certified:**
- Certified Kubernetes conformant
- Run standard Kubernetes workloads
- Use standard kubectl commands
- Kubernetes versions 1.23+

## Architecture Overview

### High-Level Components

```
┌─────────────────────────────────────────────────────────────┐
│                         AWS Cloud                           │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐ │
│  │              Amazon EKS Cluster                       │ │
│  │                                                       │ │
│  │  ┌──────────────────────────────────────────────┐   │ │
│  │  │       Control Plane (Managed by AWS)         │   │ │
│  │  │                                              │   │ │
│  │  │  ┌─────────┐  ┌──────────┐  ┌───────────┐  │   │ │
│  │  │  │  API    │  │   etcd   │  │  kube-    │  │   │ │
│  │  │  │ Server  │  │          │  │ scheduler │  │   │ │
│  │  │  └─────────┘  └──────────┘  └───────────┘  │   │ │
│  │  │                                              │   │ │
│  │  │  ┌──────────────┐  ┌──────────────────────┐│   │ │
│  │  │  │ controller-  │  │ cloud-controller-    ││   │ │
│  │  │  │  manager     │  │      manager         ││   │ │
│  │  │  └──────────────┘  └──────────────────────┘│   │ │
│  │  └──────────────────────────────────────────────┘   │ │
│  │                        │                             │ │
│  │                        │ (secure channel)            │ │
│  │                        │                             │ │
│  │  ┌──────────────────────────────────────────────┐   │ │
│  │  │      Data Plane (Managed by You)             │   │ │
│  │  │                                              │   │ │
│  │  │  ┌────────────┐  ┌────────────┐            │   │ │
│  │  │  │   Node 1   │  │   Node 2   │            │   │ │
│  │  │  │            │  │            │            │   │ │
│  │  │  │  ┌──────┐  │  │  ┌──────┐  │            │   │ │
│  │  │  │  │ Pod  │  │  │  │ Pod  │  │   ...      │   │ │
│  │  │  │  └──────┘  │  │  └──────┘  │            │   │ │
│  │  │  │  ┌──────┐  │  │  ┌──────┐  │            │   │ │
│  │  │  │  │ Pod  │  │  │  │ Pod  │  │            │   │ │
│  │  │  │  └──────┘  │  │  └──────┘  │            │   │ │
│  │  │  └────────────┘  └────────────┘            │   │ │
│  │  └──────────────────────────────────────────────┘   │ │
│  └───────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Control Plane

**Managed by AWS:**
- API Server: Frontend for Kubernetes API
- etcd: Key-value store for cluster data
- kube-scheduler: Assigns pods to nodes
- kube-controller-manager: Runs controller processes
- cloud-controller-manager: AWS-specific controller

**AWS Responsibilities:**
- Provision and scale control plane
- Patch and update Kubernetes versions
- Maintain high availability (3+ replicas across AZs)
- Backup and disaster recovery
- Security and compliance

### Data Plane

**Managed by You:**
- EC2 instances (worker nodes)
- Fargate pods (serverless)
- Applications and workloads

**Your Responsibilities:**
- Choose instance types and sizes
- Configure autoscaling
- Update worker node AMIs
- Monitor node health
- Application deployment

### Networking

**VPC Integration:**
- Cluster runs in your VPC
- Nodes in public or private subnets
- Control plane communicates via ENIs

**Pod Networking:**
- VPC CNI plugin (default)
- Each pod gets VPC IP address
- Native VPC security groups

## EKS vs Self-Managed Kubernetes

| Feature | EKS | Self-Managed |
|---------|-----|--------------|
| **Control Plane Management** | AWS manages | You manage |
| **Updates & Patches** | Automatic | Manual |
| **High Availability** | Built-in (multi-AZ) | You configure |
| **Monitoring** | CloudWatch integration | You configure |
| **Cost** | $0.10/hour ($73/month) | EC2 costs only |
| **Setup Time** | 15 minutes | Hours to days |
| **Expertise Required** | AWS knowledge | Kubernetes + AWS |
| **Scalability** | Automatic | Manual |
| **Security** | AWS certified | Your responsibility |

### When to Use EKS

✅ **Use EKS when:**
- You want AWS to manage the control plane
- You need compliance certifications
- You want deep AWS integration
- You prefer managed service model
- Your team lacks Kubernetes expertise
- You need production-grade HA out of the box

❌ **Consider alternatives when:**
- You need maximum cost optimization (control plane cost)
- You require custom control plane configuration
- You're running non-AWS workloads primarily
- You have strong Kubernetes expertise in-house
- You need specific Kubernetes versions/features not yet on EKS

## Pricing

### Control Plane

**$0.10 per hour** per cluster (~$73/month)
- Includes HA across 3 AZs
- Automatic backups
- Automatic updates
- No upfront cost

### Data Plane

**EC2 Instances:**
- Standard EC2 pricing
- Example: t3.medium = ~$30/month
- Use Spot instances for 90% savings

**Fargate:**
- Pay per vCPU and memory per second
- Example: 0.25 vCPU, 0.5 GB = $0.01244/hour

### Networking

**NAT Gateway:** ~$32/month per NAT Gateway
**Load Balancers:** ~$18/month per ALB/NLB
**Data Transfer:** Standard AWS rates

### Example Monthly Costs

**Minimal Dev Setup:**
```
Control Plane:        $73
2x t3.small nodes:    $30
1x NAT Gateway:       $32
Total:               ~$135/month
```

**Production Setup:**
```
Control Plane:        $73
5x t3.medium nodes:  $300
2x NAT Gateways:      $64
2x ALB:               $36
Total:               ~$473/month
```

**Cost Optimization:**
- Use Spot instances (save 70-90%)
- Use Fargate for bursty workloads
- Single NAT for dev environments
- Enable cluster autoscaler
- Right-size your instances

## Hands-On: Create Your First Cluster

### Prerequisites Check

```bash
# Check AWS CLI
aws --version
aws sts get-caller-identity

# Check kubectl
kubectl version --client

# Check eksctl
eksctl version
```

### Method 1: Using eksctl (Fastest)

eksctl is the official CLI tool for EKS.

```bash
# Create cluster with managed node group
eksctl create cluster \
  --name my-first-cluster \
  --region us-west-2 \
  --nodegroup-name standard-workers \
  --node-type t3.medium \
  --nodes 2 \
  --nodes-min 1 \
  --nodes-max 3 \
  --managed

# This creates:
# - EKS cluster
# - VPC with public/private subnets
# - Managed node group
# - IAM roles
# - Updates kubeconfig
```

**Time:** 15-20 minutes

### Method 2: Using AWS Console

1. **Go to EKS Console:**
   - Open AWS Console
   - Navigate to EKS
   - Click "Create cluster"

2. **Configure Cluster:**
   - Name: my-first-cluster
   - Kubernetes version: 1.28 (latest)
   - Service role: Create new role

3. **Configure Networking:**
   - VPC: Create new VPC or use existing
   - Subnets: Select at least 2
   - Security groups: Create new

4. **Create Cluster** (10-15 minutes)

5. **Add Node Group:**
   - Go to cluster → Compute → Add node group
   - Name: standard-workers
   - Instance type: t3.medium
   - Desired size: 2

6. **Configure kubectl:**
   ```bash
   aws eks update-kubeconfig \
     --region us-west-2 \
     --name my-first-cluster
   ```

### Verify Cluster

```bash
# Check cluster info
kubectl cluster-info

# View nodes
kubectl get nodes

# View system pods
kubectl get pods -A

# Check EKS version
kubectl version --short
```

Expected output:
```
NAME                                          STATUS   ROLES    AGE   VERSION
ip-192-168-1-100.us-west-2.compute.internal   Ready    <none>   5m    v1.28.x
ip-192-168-2-200.us-west-2.compute.internal   Ready    <none>   5m    v1.28.x
```

## Deploy Your First Application

### 1. Create Deployment

```bash
kubectl create deployment nginx --image=nginx:alpine
```

### 2. Expose as Service

```bash
kubectl expose deployment nginx --port=80 --type=LoadBalancer
```

### 3. Wait for LoadBalancer

```bash
kubectl get svc nginx -w
```

Wait until EXTERNAL-IP shows an AWS hostname (2-3 minutes).

### 4. Test Application

```bash
# Get LoadBalancer URL
export LB_URL=$(kubectl get svc nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Test
curl http://$LB_URL
```

You should see the nginx welcome page HTML.

### 5. View Deployment Details

```bash
# View pods
kubectl get pods

# View pod details
kubectl describe pod <pod-name>

# View logs
kubectl logs <pod-name>

# View service
kubectl describe svc nginx
```

### 6. Scale the Deployment

```bash
# Scale to 3 replicas
kubectl scale deployment nginx --replicas=3

# Watch pods come up
kubectl get pods -w
```

## Clean Up

**IMPORTANT:** Delete resources to avoid charges!

```bash
# Delete the service (removes LoadBalancer)
kubectl delete svc nginx

# Delete the deployment
kubectl delete deployment nginx

# Delete the cluster (using eksctl)
eksctl delete cluster --name my-first-cluster --region us-west-2

# Or using AWS Console:
# 1. Delete node groups
# 2. Delete cluster
```

**Verify deletion:**
```bash
aws eks list-clusters --region us-west-2
```

## Key Takeaways

✅ EKS provides a managed Kubernetes control plane
✅ You manage the worker nodes (data plane)
✅ Control plane costs $73/month, plus EC2 costs
✅ eksctl is the fastest way to create clusters
✅ EKS integrates deeply with AWS services
✅ Always clean up resources to avoid charges

## Quiz

1. What does EKS manage for you?
   - [ ] Worker nodes
   - [x] Control plane
   - [ ] Applications
   - [ ] Database

2. How much does the EKS control plane cost per month?
   - [ ] Free
   - [ ] $10
   - [x] ~$73
   - [ ] $500

3. Which tool is the fastest way to create an EKS cluster?
   - [ ] AWS Console
   - [x] eksctl
   - [ ] kubectl
   - [ ] Terraform

4. What networking plugin does EKS use by default?
   - [ ] Calico
   - [ ] Flannel
   - [x] VPC CNI
   - [ ] Weave

5. Can pods in EKS get VPC IP addresses?
   - [x] Yes
   - [ ] No

## Next Steps

Continue to [Module 02: Networking Deep Dive](../02-networking/README.md)

## Additional Resources

- [EKS User Guide](https://docs.aws.amazon.com/eks/)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [eksctl Documentation](https://eksctl.io/)
- [EKS Workshop](https://www.eksworkshop.com/)
