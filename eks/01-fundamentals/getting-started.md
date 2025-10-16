# Getting Started with EKS

Quick reference guide for creating your first EKS cluster.

## Quick Start with eksctl

### Create Cluster

```bash
eksctl create cluster \
  --name dev-cluster \
  --region us-west-2 \
  --nodegroup-name workers \
  --node-type t3.medium \
  --nodes 2 \
  --managed
```

### Verify

```bash
kubectl get nodes
kubectl get pods -A
```

### Deploy Test App

```bash
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=LoadBalancer
kubectl get svc nginx -w
```

### Clean Up

```bash
kubectl delete svc nginx
kubectl delete deployment nginx
eksctl delete cluster --name dev-cluster
```

## Detailed Configuration

### With Configuration File

Create `cluster.yaml`:

```yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: my-cluster
  region: us-west-2
  version: "1.28"

managedNodeGroups:
  - name: ng-1
    instanceType: t3.medium
    desiredCapacity: 2
    minSize: 1
    maxSize: 4
    volumeSize: 20
    ssh:
      allow: false
    labels:
      role: worker
    tags:
      environment: dev
```

Create cluster:

```bash
eksctl create cluster -f cluster.yaml
```

## Common Commands

```bash
# List clusters
eksctl get cluster

# Get cluster info
kubectl cluster-info

# View nodes
kubectl get nodes -o wide

# View namespaces
kubectl get ns

# View all resources
kubectl get all -A

# Update kubeconfig
aws eks update-kubeconfig --region us-west-2 --name my-cluster

# Delete cluster
eksctl delete cluster --name my-cluster --region us-west-2
```

## Troubleshooting

### Can't connect to cluster

```bash
# Update kubeconfig
aws eks update-kubeconfig --region us-west-2 --name my-cluster

# Check AWS credentials
aws sts get-caller-identity

# Check kubectl context
kubectl config current-context
```

### Nodes not showing up

```bash
# Check node group status
eksctl get nodegroup --cluster my-cluster

# Check CloudFormation stacks
aws cloudformation list-stacks --region us-west-2

# View events
kubectl get events -A --sort-by='.lastTimestamp'
```

### Pods stuck pending

```bash
# Check pod events
kubectl describe pod <pod-name>

# Check node resources
kubectl top nodes

# Check node conditions
kubectl describe nodes
```

## Cost Optimization

### Use Spot Instances

```yaml
managedNodeGroups:
  - name: spot-group
    instanceTypes: ["t3.medium", "t3a.medium"]
    spot: true
    desiredCapacity: 2
```

### Enable Autoscaling

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml
```

### Use Fargate for Bursty Workloads

```bash
eksctl create fargateprofile \
  --cluster my-cluster \
  --name my-app \
  --namespace my-app
```

## Next Steps

- [Module 02: Networking](../02-networking/README.md)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [eksctl Documentation](https://eksctl.io/)
