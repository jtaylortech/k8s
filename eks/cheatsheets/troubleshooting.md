# EKS Troubleshooting Guide

Comprehensive guide to diagnosing and fixing common EKS issues.

## Table of Contents

1. [Cluster Access Issues](#cluster-access-issues)
2. [Node Problems](#node-problems)
3. [Pod Issues](#pod-issues)
4. [Networking Problems](#networking-problems)
5. [IAM and IRSA Issues](#iam-and-irsa-issues)
6. [Storage Problems](#storage-problems)
7. [Performance Issues](#performance-issues)
8. [Upgrade Problems](#upgrade-problems)

## Cluster Access Issues

### Can't Connect to Cluster

**Symptom:**
```
error: You must be logged in to the server (Unauthorized)
```

**Diagnosis:**
```bash
# Check AWS credentials
aws sts get-caller-identity

# Verify cluster exists
aws eks list-clusters --region us-west-2

# Check cluster status
aws eks describe-cluster --name my-cluster --region us-west-2
```

**Solutions:**

**1. Update kubeconfig:**
```bash
aws eks update-kubeconfig --region us-west-2 --name my-cluster
```

**2. Check IAM permissions:**
```bash
# Your IAM user/role needs these permissions:
# eks:DescribeCluster
# eks:ListClusters
```

**3. Verify aws-auth ConfigMap:**
```bash
kubectl get configmap aws-auth -n kube-system -o yaml
```

**4. Add your IAM user to aws-auth:**
```bash
kubectl edit configmap aws-auth -n kube-system

# Add:
mapUsers: |
  - userarn: arn:aws:iam::123456789:user/your-user
    username: your-user
    groups:
      - system:masters
```

### Context Not Set

**Symptom:**
```
The connection to the server localhost:8080 was refused
```

**Solution:**
```bash
# List contexts
kubectl config get-contexts

# Use EKS context
kubectl config use-context arn:aws:eks:us-west-2:123456789:cluster/my-cluster

# Or update kubeconfig
aws eks update-kubeconfig --name my-cluster --region us-west-2
```

### Cluster Endpoint Not Accessible

**Symptom:**
```
dial tcp: lookup <cluster-endpoint>: no such host
```

**Diagnosis:**
```bash
# Check cluster endpoint access
aws eks describe-cluster --name my-cluster \
  --query 'cluster.resourcesVpcConfig.endpointPublicAccess'

# Check your IP is allowed
aws eks describe-cluster --name my-cluster \
  --query 'cluster.resourcesVpcConfig.publicAccessCidrs'
```

**Solutions:**

**1. Enable public access:**
```bash
aws eks update-cluster-config \
  --name my-cluster \
  --resources-vpc-config endpointPublicAccess=true
```

**2. Add your IP to allowed CIDRs:**
```bash
aws eks update-cluster-config \
  --name my-cluster \
  --resources-vpc-config publicAccessCidrs="1.2.3.4/32"
```

**3. Use VPN or bastion if private-only cluster**

## Node Problems

### Nodes Not Joining Cluster

**Symptom:**
```bash
kubectl get nodes
# Shows no nodes or nodes in NotReady state
```

**Diagnosis:**
```bash
# Check node group status
aws eks describe-nodegroup \
  --cluster-name my-cluster \
  --nodegroup-name my-nodegroup

# Check EC2 instances
aws ec2 describe-instances \
  --filters "Name=tag:eks:cluster-name,Values=my-cluster"

# Check Auto Scaling Group
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names eks-xxx
```

**Common Causes:**

**1. Incorrect IAM role:**
```bash
# Verify node IAM role has these policies:
# - AmazonEKSWorkerNodePolicy
# - AmazonEKS_CNI_Policy
# - AmazonEC2ContainerRegistryReadOnly

aws iam list-attached-role-policies --role-name eks-node-role
```

**2. Security group issues:**
```bash
# Check node security group allows:
# - All traffic from cluster security group
# - TCP 443 from control plane
# - TCP 10250 from control plane

aws ec2 describe-security-groups --group-ids sg-xxx
```

**3. Subnet has no available IPs:**
```bash
aws ec2 describe-subnets --subnet-ids subnet-xxx \
  --query 'Subnets[0].AvailableIpAddressCount'
```

**4. User data script errors:**
```bash
# SSH to node (if enabled)
ssh ec2-user@<node-ip>

# Check cloud-init logs
sudo cat /var/log/cloud-init-output.log

# Check kubelet logs
sudo journalctl -u kubelet
```

### Nodes in NotReady State

**Diagnosis:**
```bash
# Describe node
kubectl describe node <node-name>

# Check node conditions
kubectl get nodes -o json | jq '.items[].status.conditions'

# Check kubelet logs (SSH to node)
sudo journalctl -u kubelet -f
```

**Common Causes:**

**1. CNI plugin issues:**
```bash
# Check aws-node pods
kubectl get pods -n kube-system -l k8s-app=aws-node

# Check CNI logs
kubectl logs -n kube-system -l k8s-app=aws-node --tail=100
```

**2. Disk pressure:**
```bash
# Check disk usage (SSH to node)
df -h
sudo docker system df

# Clean up
sudo docker system prune -af
```

**3. Memory pressure:**
```bash
# Check memory
free -h

# Check OOM kills
dmesg | grep -i oom
```

### Node Scaling Issues

**Diagnosis:**
```bash
# Check cluster autoscaler logs
kubectl logs -n kube-system deployment/cluster-autoscaler

# Check node group capacity
aws eks describe-nodegroup \
  --cluster-name my-cluster \
  --nodegroup-name my-nodegroup \
  --query 'nodegroup.scalingConfig'
```

**Solutions:**

**1. Increase max size:**
```bash
aws eks update-nodegroup-config \
  --cluster-name my-cluster \
  --nodegroup-name my-nodegroup \
  --scaling-config maxSize=10
```

**2. Check IAM permissions for autoscaler:**
```yaml
# Cluster autoscaler needs:
# - autoscaling:DescribeAutoScalingGroups
# - autoscaling:SetDesiredCapacity
# - ec2:DescribeLaunchTemplateVersions
```

## Pod Issues

### Pods Stuck in Pending

**Diagnosis:**
```bash
# Check pod events
kubectl describe pod <pod-name>

# Check scheduler logs
kubectl logs -n kube-system deployment/kube-scheduler
```

**Common Causes:**

**1. Insufficient resources:**
```bash
# Check node capacity
kubectl describe nodes | grep -A 5 Allocated

# Solutions:
# - Add more nodes
# - Reduce pod resource requests
# - Use smaller resource requests
```

**2. Pod affinity/anti-affinity rules:**
```bash
# Check pod spec for affinity rules
kubectl get pod <pod-name> -o yaml | grep -A 10 affinity
```

**3. Taints and tolerations:**
```bash
# Check node taints
kubectl describe nodes | grep Taints

# Add toleration to pod
tolerations:
- key: "spot"
  operator: "Equal"
  value: "true"
  effect: "NoSchedule"
```

**4. No available IPs:**
```bash
# Check CNI pod limits
kubectl get pods -n kube-system -l k8s-app=aws-node \
  -o jsonpath='{.items[*].status.allocatable}'
```

### Pods in CrashLoopBackOff

**Diagnosis:**
```bash
# Check logs
kubectl logs <pod-name>
kubectl logs <pod-name> --previous

# Check events
kubectl describe pod <pod-name>

# Check container exit code
kubectl get pod <pod-name> -o jsonpath='{.status.containerStatuses[*].lastState.terminated.exitCode}'
```

**Common Causes:**

**1. Application crashes:**
- Check application logs
- Review container command/args
- Check environment variables

**2. Failed health checks:**
```bash
# Review liveness/readiness probes
kubectl get pod <pod-name> -o yaml | grep -A 10 probe

# Increase initialDelaySeconds if app takes time to start
```

**3. Missing dependencies:**
- Check ConfigMaps exist
- Check Secrets exist
- Check PVCs are bound

### ImagePullBackOff

**Symptom:**
```
Failed to pull image: rpc error: code = Unknown
```

**Solutions:**

**1. Check image name:**
```bash
# Verify image exists
docker pull <image-name>

# Check ECR repository
aws ecr describe-repositories
```

**2. ECR authentication:**
```bash
# Verify node role has ECR permissions
# AmazonEC2ContainerRegistryReadOnly

# Or create ImagePullSecret
kubectl create secret docker-registry ecr-secret \
  --docker-server=123456789.dkr.ecr.us-west-2.amazonaws.com \
  --docker-username=AWS \
  --docker-password=$(aws ecr get-login-password --region us-west-2)
```

**3. Private registry:**
```bash
# Create secret
kubectl create secret docker-registry regcred \
  --docker-server=<registry> \
  --docker-username=<username> \
  --docker-password=<password>

# Reference in pod
imagePullSecrets:
- name: regcred
```

## Networking Problems

### Pod Can't Reach Internet

**Diagnosis:**
```bash
# Test from pod
kubectl exec <pod-name> -- ping -c 3 8.8.8.8
kubectl exec <pod-name> -- nslookup google.com

# Check pod IP
kubectl get pod <pod-name> -o wide

# Check routes (SSH to node)
ip route
```

**Solutions:**

**1. Check NAT Gateway:**
```bash
# Verify NAT Gateway exists
aws ec2 describe-nat-gateways

# Check route table
aws ec2 describe-route-tables
```

**2. Check security groups:**
```bash
# Node security group must allow egress
aws ec2 describe-security-groups --group-ids sg-xxx
```

**3. External SNAT disabled:**
```bash
# If using custom networking, enable external SNAT
kubectl set env daemonset aws-node \
  -n kube-system \
  AWS_VPC_K8S_CNI_EXTERNALSNAT=true
```

### Service Not Accessible

**Diagnosis:**
```bash
# Check service
kubectl get svc <service-name>

# Check endpoints
kubectl get endpoints <service-name>

# Test from another pod
kubectl run test --image=busybox --rm -it -- wget -O- <service-name>
```

**Solutions:**

**1. No endpoints:**
```bash
# Check pod selector matches
kubectl get svc <service-name> -o yaml | grep selector
kubectl get pods -l <selector>

# Check pod is ready
kubectl get pods -l <selector>
```

**2. Wrong port:**
```bash
# Verify service ports
kubectl describe svc <service-name>

# Check container ports
kubectl get pod <pod-name> -o jsonpath='{.spec.containers[*].ports}'
```

### LoadBalancer Stuck in Pending

**Diagnosis:**
```bash
# Check service
kubectl describe svc <service-name>

# Check AWS Load Balancer Controller
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

**Solutions:**

**1. Install AWS Load Balancer Controller:**
```bash
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=my-cluster
```

**2. Check subnet tags:**
```bash
# Public subnets need:
# kubernetes.io/role/elb = 1

# Private subnets need:
# kubernetes.io/role/internal-elb = 1
```

**3. Check service annotations:**
```yaml
annotations:
  service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
  service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
```

### DNS Resolution Fails

**Diagnosis:**
```bash
# Test DNS
kubectl exec <pod-name> -- nslookup kubernetes.default

# Check CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Check CoreDNS logs
kubectl logs -n kube-system -l k8s-app=kube-dns
```

**Solutions:**

**1. CoreDNS not running:**
```bash
kubectl rollout status deployment coredns -n kube-system
```

**2. DNS service ClusterIP:**
```bash
# Should be 10.100.0.10 or similar
kubectl get svc kube-dns -n kube-system
```

**3. Pod DNS policy:**
```yaml
# Check pod's dnsPolicy
dnsPolicy: ClusterFirst  # Should be this
```

## IAM and IRSA Issues

### IRSA Not Working

**Diagnosis:**
```bash
# Check OIDC provider
aws iam list-open-id-connect-providers

# Check service account
kubectl describe sa <sa-name>

# Check pod environment
kubectl exec <pod-name> -- env | grep AWS
```

**Solutions:**

**1. OIDC provider not configured:**
```bash
eksctl utils associate-iam-oidc-provider \
  --cluster my-cluster \
  --approve
```

**2. Wrong IAM role ARN:**
```bash
# Verify annotation
kubectl get sa <sa-name> -o jsonpath='{.metadata.annotations}'

# Should have:
# eks.amazonaws.com/role-arn: arn:aws:iam::xxx:role/xxx
```

**3. Trust policy incorrect:**
```bash
# Verify trust policy
aws iam get-role --role-name <role-name>

# Should include condition for ServiceAccount
```

### Access Denied Errors

**Diagnosis:**
```bash
# Test AWS access from pod
kubectl exec <pod-name> -- aws s3 ls

# Check assumed role
kubectl exec <pod-name> -- aws sts get-caller-identity
```

**Solutions:**

**1. Add IAM policy:**
```bash
aws iam attach-role-policy \
  --role-name <role-name> \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess
```

**2. Check permission boundaries**
**3. Verify trust policy conditions**

## Storage Problems

### PVC Stuck in Pending

**Diagnosis:**
```bash
# Check PVC
kubectl describe pvc <pvc-name>

# Check storage class
kubectl get storageclass

# Check CSI driver
kubectl get pods -n kube-system | grep ebs-csi
```

**Solutions:**

**1. Install EBS CSI driver:**
```bash
kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.25"
```

**2. Create IRSA for CSI driver:**
```bash
eksctl create iamserviceaccount \
  --name ebs-csi-controller-sa \
  --namespace kube-system \
  --cluster my-cluster \
  --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
  --approve
```

**3. Set default storage class:**
```bash
kubectl patch storageclass gp2 \
  -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

### Volume Mount Fails

**Diagnosis:**
```bash
# Check pod events
kubectl describe pod <pod-name>

# Check PV/PVC binding
kubectl get pv,pvc
```

**Common Causes:**
- PVC and pod in different namespaces
- Access mode mismatch (ReadWriteOnce vs ReadWriteMany)
- Volume already mounted on another node (for RWO)

## Performance Issues

### High CPU/Memory Usage

**Diagnosis:**
```bash
# Check resource usage
kubectl top nodes
kubectl top pods -A

# Check metrics-server
kubectl get deployment metrics-server -n kube-system
```

**Solutions:**

**1. Increase resource limits:**
```yaml
resources:
  requests:
    cpu: 500m
    memory: 512Mi
  limits:
    cpu: 2000m
    memory: 2Gi
```

**2. Enable HPA:**
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: my-app
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

## Upgrade Problems

### Cluster Upgrade Fails

**Best Practices:**
```bash
# 1. Check EKS version
kubectl version --short

# 2. Review changelog
# https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html

# 3. Upgrade control plane
aws eks update-cluster-version \
  --name my-cluster \
  --kubernetes-version 1.28

# 4. Wait for completion
aws eks describe-update --name my-cluster --update-id <id>

# 5. Update add-ons
kubectl apply -f <updated-addon-yaml>

# 6. Update node groups
aws eks update-nodegroup-version \
  --cluster-name my-cluster \
  --nodegroup-name my-nodegroup \
  --kubernetes-version 1.28
```

## Diagnostic Commands

```bash
# Cluster info
kubectl cluster-info
kubectl version

# Node info
kubectl get nodes -o wide
kubectl describe nodes

# Pod debugging
kubectl get events -A --sort-by='.lastTimestamp'
kubectl get pods -A
kubectl describe pod <pod>
kubectl logs <pod> --all-containers=true

# Networking
kubectl get svc,endpoints -A
kubectl describe svc <service>

# Storage
kubectl get pv,pvc -A
kubectl describe pvc <pvc>

# Check system pods
kubectl get pods -n kube-system

# Resource usage
kubectl top nodes
kubectl top pods -A
```

## Getting Help

1. **AWS Support**
   - Open case in AWS Console
   - Include cluster name and region
   - Attach relevant logs

2. **Community**
   - [EKS GitHub Discussions](https://github.com/aws/containers-roadmap/discussions)
   - [Kubernetes Slack #eks-users](https://kubernetes.slack.com)
   - [AWS re:Post](https://repost.aws/)

3. **Logs to Collect**
   - kubectl describe output
   - Pod logs
   - Control plane logs (CloudWatch)
   - Node system logs (if accessible)
