# Kubernetes Application Stack Example

Complete example of managing Kubernetes resources with Terraform, including:
- Deployments, Services, ConfigMaps, Secrets
- Horizontal Pod Autoscaler (HPA)
- Helm chart deployment (NGINX Ingress Controller)

## What This Creates

- **Namespace**: Isolated environment for the application
- **ConfigMap**: Application configuration
- **Secret**: Sensitive data (API keys, passwords)
- **Deployment**: Replicated application with health checks
- **Service**: Network endpoint (LoadBalancer by default)
- **HPA**: Automatic scaling based on CPU usage
- **NGINX Ingress Controller**: (Optional) HTTP/HTTPS routing

## Prerequisites

1. **Existing EKS cluster** from Module 02
2. **kubectl configured** to access the cluster
3. **Terraform installed** (>= 1.0)

## Usage

### 1. Configure Variables

```bash
# Copy example tfvars
cp terraform.tfvars.example terraform.tfvars

# Edit with your cluster name
vi terraform.tfvars
```

**Important**: Set `cluster_name` to match your EKS cluster:
```hcl
cluster_name = "dev-eks-cluster"  # Your actual cluster name
```

### 2. Initialize Terraform

```bash
terraform init
```

This downloads the required providers:
- AWS provider (to get cluster info)
- Kubernetes provider (to manage K8s resources)
- Helm provider (to deploy charts)

### 3. Plan

```bash
terraform plan
```

You should see resources to be created:
- 1 namespace
- 1 config map
- 1 secret
- 1 deployment
- 1 service
- 1 HPA (if enabled)
- 1 Helm release (if NGINX Ingress enabled)

### 4. Apply

```bash
terraform apply
```

Type `yes` to confirm. **This takes 3-5 minutes**.

### 5. Verify Deployment

```bash
# View all resources in the namespace
kubectl get all -n demo

# Check pods are running
kubectl get pods -n demo

# Check service (wait for LoadBalancer to provision)
kubectl get svc -n demo -w

# View HPA status
kubectl get hpa -n demo
```

### 6. Test the Application

#### Option A: LoadBalancer (Default)

```bash
# Get LoadBalancer URL
export LB_URL=$(kubectl get svc demo-app -n demo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Test the application
curl http://$LB_URL/
curl http://$LB_URL/health

# Load test to trigger autoscaling (requires 'hey' tool)
hey -z 60s -c 50 http://$LB_URL/

# Watch HPA scale up
kubectl get hpa -n demo -w
```

#### Option B: ClusterIP (If you changed service_type)

```bash
# Port forward to access locally
kubectl port-forward -n demo svc/demo-app 8080:80

# In another terminal, test
curl http://localhost:8080/
curl http://localhost:8080/health
```

### 7. Test Ingress Controller (If Installed)

```bash
# Check NGINX Ingress Controller status
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx

# Get Ingress Controller LoadBalancer URL
export INGRESS_URL=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "Ingress Controller: http://$INGRESS_URL"

# Test default backend (should return 404 - no ingress routes defined yet)
curl http://$INGRESS_URL
```

### 8. View Logs

```bash
# View application logs
kubectl logs -n demo -l app=demo-app --tail=100 -f

# View specific pod logs
kubectl logs -n demo <pod-name>

# View Ingress Controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx
```

### 9. Test Autoscaling

```bash
# Generate load to trigger autoscaling
kubectl run -i --tty load-generator --rm --image=busybox --restart=Never -n demo -- /bin/sh

# Inside the pod, run:
while true; do wget -q -O- http://demo-app; done

# In another terminal, watch HPA scale
kubectl get hpa -n demo -w

# Watch pods scale up
kubectl get pods -n demo -w
```

### 10. Update the Application

```bash
# Change variables in terraform.tfvars
# For example, change app_image to a different version

# Apply changes
terraform apply

# Watch rolling update
kubectl rollout status deployment/demo-app -n demo

# View rollout history
kubectl rollout history deployment/demo-app -n demo
```

### 11. Clean Up

```bash
terraform destroy
```

Type `yes` to confirm.

## Cost Estimate

Based on default configuration (us-west-2):

- **Application Pods** (2 replicas): Free (uses EKS nodes)
- **LoadBalancer** (NLB): ~$18/month + data transfer
- **NGINX Ingress LoadBalancer** (NLB): ~$18/month + data transfer
- **Total**: ~$36/month (on top of EKS cluster costs)

**To minimize costs**:
- Use `service_type = "ClusterIP"` (no LoadBalancer)
- Set `install_ingress_nginx = false`
- Destroy when not in use

## Customization

### Use ClusterIP Instead of LoadBalancer

```hcl
# terraform.tfvars
service_type = "ClusterIP"
```

Access via port-forward:
```bash
kubectl port-forward -n demo svc/demo-app 8080:80
```

### Disable Autoscaling

```hcl
# terraform.tfvars
enable_autoscaling = false
app_replicas       = 3
```

### Change Resource Limits

```hcl
# terraform.tfvars
cpu_request    = "200m"
memory_request = "256Mi"
cpu_limit      = "1000m"
memory_limit   = "512Mi"
```

### Deploy Your Own Image

```hcl
# terraform.tfvars
app_image = "myregistry/myapp:1.0.0"
app_port  = 8080  # If your app uses different port
```

### Skip NGINX Ingress Controller

```hcl
# terraform.tfvars
install_ingress_nginx = false
```

## Troubleshooting

### Pods Not Starting

```bash
# Describe pod to see events
kubectl describe pod <pod-name> -n demo

# Check logs
kubectl logs <pod-name> -n demo

# Common issues:
# - Image pull errors (wrong image name or private registry)
# - Resource limits too low
# - Failed health checks
```

### LoadBalancer Stuck in Pending

```bash
# Check service status
kubectl describe svc demo-app -n demo

# Common issues:
# - AWS Load Balancer Controller not installed
# - Insufficient IAM permissions
# - VPC/subnet configuration issues
# - Check EKS cluster has proper tags on subnets
```

### HPA Not Scaling

```bash
# Check HPA status
kubectl get hpa -n demo
kubectl describe hpa demo-app-hpa -n demo

# Check metrics-server is installed
kubectl get deployment metrics-server -n kube-system

# If metrics-server not installed:
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Verify metrics are available
kubectl top nodes
kubectl top pods -n demo
```

### Terraform Can't Connect to Cluster

```bash
# Update kubeconfig
aws eks update-kubeconfig --region us-west-2 --name dev-eks-cluster

# Test kubectl access
kubectl get nodes

# Verify AWS credentials
aws sts get-caller-identity
```

### Helm Release Fails

```bash
# Check Helm release status
helm list -n ingress-nginx

# View Helm release details
helm status ingress-nginx -n ingress-nginx

# Check logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx

# Manually delete and let Terraform recreate
helm uninstall ingress-nginx -n ingress-nginx
terraform apply
```

## Understanding the Code

### main.tf
- **Namespace**: Logical isolation for resources
- **ConfigMap**: Non-sensitive configuration (env vars, config files)
- **Secret**: Sensitive data (passwords, API keys, tokens)
- **Deployment**: Manages replicated pods with rolling updates
- **Service**: Stable network endpoint for pods
- **HPA**: Auto-scales based on CPU/memory metrics

### helm.tf
- **NGINX Ingress Controller**: Routes HTTP/HTTPS traffic to services
- Shows how to customize Helm charts with `values`
- Demonstrates AWS-specific annotations for NLB

### providers.tf
- **Data Sources**: Fetch existing EKS cluster info
- **Provider Configuration**: Connect Terraform to K8s API
- Shows two authentication methods (token vs exec)

## Next Steps

1. **Create Ingress Resources**: Route traffic to your application
2. **Add Monitoring**: Deploy Prometheus + Grafana
3. **Implement CI/CD**: Auto-deploy on git push
4. **Use Terraform Modules**: Make this reusable (Module 04)
5. **Add Security**: NetworkPolicies, PodSecurityPolicies

## Files

- `providers.tf` - Provider configuration (AWS, K8s, Helm)
- `variables.tf` - Input variables
- `main.tf` - K8s resources (Namespace, Deployment, Service, HPA)
- `helm.tf` - Helm chart deployments (NGINX Ingress)
- `outputs.tf` - Useful outputs and commands
- `terraform.tfvars.example` - Example configuration

## References

- [Terraform Kubernetes Provider](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs)
- [Terraform Helm Provider](https://registry.terraform.io/providers/hashicorp/helm/latest/docs)
- [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
- [Horizontal Pod Autoscaler](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
