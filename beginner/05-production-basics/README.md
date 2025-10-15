# Module 05: Production Basics

**Duration**: ~4 hours
**Prerequisites**: [Module 04: Workload Management](../04-workload-management/README.md)
**Next**: [Expert Track](../../expert/README.md) or Real-world Projects

## Learning Objectives

By the end of this module, you will:
- ✅ Package and deploy applications with Helm
- ✅ Set up monitoring with Prometheus & Grafana
- ✅ Implement basic logging patterns
- ✅ Apply security best practices
- ✅ Understand production readiness checklist
- ✅ Deploy a complete production-like stack

---

## Part 1: Helm - Package Manager for Kubernetes

**Helm** manages Kubernetes applications as "charts"—packaged, versioned, configurable templates.

### Why Helm?

Without Helm:
- Manage dozens of YAML files
- Hard-code values for each environment
- Manual dependency management

With Helm:
- Single chart packages everything
- Values files for different environments
- Dependency management built-in
- Versioned releases with rollback

### Installing Helm

```bash
# macOS
brew install helm

# Linux
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify
helm version
```

### Using Helm Charts

```bash
# Add repository
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Search charts
helm search repo nginx

# Install chart
helm install my-nginx bitnami/nginx

# List releases
helm list

# Get release info
helm status my-nginx

# Uninstall
helm uninstall my-nginx
```

### Customizing with Values

**View default values**:
```bash
helm show values bitnami/nginx > values.yaml
```

**File**: `values-custom.yaml`
```yaml
replicaCount: 3

service:
  type: ClusterIP

ingress:
  enabled: true
  hostname: app.localtest.me
  ingressClassName: nginx

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 200m
    memory: 256Mi
```

```bash
# Install with custom values
helm install my-nginx bitnami/nginx -f values-custom.yaml

# Override individual values
helm install my-nginx bitnami/nginx \
  --set replicaCount=5 \
  --set service.type=LoadBalancer
```

### Upgrade and Rollback

```bash
# Upgrade release
helm upgrade my-nginx bitnami/nginx -f values-custom.yaml

# View history
helm history my-nginx

# Rollback
helm rollback my-nginx 1  # Rollback to revision 1
```

### Creating Your Own Chart

```bash
# Create chart scaffold
helm create my-app

# Directory structure:
# my-app/
# ├── Chart.yaml          # Chart metadata
# ├── values.yaml         # Default values
# ├── templates/          # Kubernetes manifests (templates)
# │   ├── deployment.yaml
# │   ├── service.yaml
# │   └── ingress.yaml
# └── charts/             # Dependencies

# Install your chart
helm install test ./my-app

# Package chart
helm package my-app
# Creates: my-app-0.1.0.tgz
```

---

## Part 2: Observability - Monitoring & Logging

### Installing Prometheus & Grafana

**kube-prometheus-stack** includes:
- Prometheus (metrics collection)
- Grafana (visualization)
- Alertmanager (alerting)
- Pre-configured dashboards

```bash
# Add repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install stack
helm upgrade --install kps prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false

# Verify
kubectl -n monitoring get pods

# Access Grafana
kubectl -n monitoring port-forward svc/kps-grafana 3000:80
# Open: http://localhost:3000
# Default: admin / prom-operator
```

### Monitoring Your Applications

Add ServiceMonitor to scrape your app metrics:

**File**: `servicemonitor.yaml`
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-app
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: my-app
  endpoints:
  - port: metrics
    interval: 30s
```

### Monitoring Ingress Controller

```bash
# Reinstall ingress-nginx with metrics
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --set controller.metrics.enabled=true \
  --set controller.metrics.serviceMonitor.enabled=true \
  --set controller.metrics.serviceMonitor.additionalLabels.release=kps

# Verify metrics
kubectl -n ingress-nginx get servicemonitor
```

**Grafana dashboards**:
1. Go to http://localhost:3000
2. Dashboards → Browse
3. Find: NGINX Ingress Controller, Kubernetes cluster monitoring

### Logging Basics

**View pod logs**:
```bash
# Single pod
kubectl logs pod-name

# All pods in deployment
kubectl logs deployment/my-app

# Follow logs
kubectl logs -f pod-name

# Previous container (after crash)
kubectl logs pod-name --previous

# Specific container in pod
kubectl logs pod-name -c container-name

# Tail last 100 lines
kubectl logs pod-name --tail=100

# Since timestamp
kubectl logs pod-name --since=1h
```

**Stern - Multi-pod log tailing**:
```bash
# Install
brew install stern

# Tail all pods matching pattern
stern my-app

# Tail specific namespace
stern my-app -n production

# Multiple containers
stern . -c nginx,sidecar
```

**Production logging** (covered in expert track):
- Centralized logging (ELK, Loki)
- Structured logging (JSON)
- Log aggregation
- Log retention policies

---

## Part 3: Security Basics

### Principle of Least Privilege

**SecurityContext** restricts what containers can do:

**File**: `deployment-secure.yaml`
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: secure-app
  template:
    metadata:
      labels:
        app: secure-app
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        fsGroup: 10001
      containers:
      - name: app
        image: nginx:1.25
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
        volumeMounts:
        - name: cache
          mountPath: /var/cache/nginx
        - name: run
          mountPath: /var/run
      volumes:
      - name: cache
        emptyDir: {}
      - name: run
        emptyDir: {}
```

### NetworkPolicy

Restrict network traffic to/from pods:

**File**: `networkpolicy.yaml`
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: web-allow-ingress
  namespace: default
spec:
  podSelector:
    matchLabels:
      app: web
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: ingress-nginx
    ports:
    - protocol: TCP
      port: 80
```

**Apply policy**:
```bash
kubectl apply -f networkpolicy.yaml

# Test: Only ingress controller can reach web pods
```

### Pod Security Standards

Kubernetes defines three policies:
1. **Privileged**: Unrestricted (default)
2. **Baseline**: Minimally restrictive (blocks known privilege escalations)
3. **Restricted**: Heavily restricted (best practice)

**Enforce at namespace level**:
```bash
kubectl label namespace default pod-security.kubernetes.io/enforce=baseline
kubectl label namespace default pod-security.kubernetes.io/warn=restricted
```

### RBAC Basics

**Role-Based Access Control** limits who can do what in your cluster.

**File**: `rbac-readonly.yaml`
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: default
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods
  namespace: default
subjects:
- kind: User
  name: jane
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

---

## Part 4: Production Readiness Checklist

### Before Going to Production

**Application**:
- [ ] Health checks configured (liveness, readiness)
- [ ] Resource requests and limits set
- [ ] Graceful shutdown handling
- [ ] Proper logging (structured, to stdout/stderr)
- [ ] Metrics endpoint exposed

**Deployment**:
- [ ] Multiple replicas (HA)
- [ ] Rolling update strategy configured
- [ ] PodDisruptionBudget defined
- [ ] Anti-affinity rules (spread across nodes)

**Security**:
- [ ] Run as non-root
- [ ] Read-only root filesystem
- [ ] Drop all capabilities
- [ ] NetworkPolicies defined
- [ ] Secrets not in Git
- [ ] Image scanning enabled

**Monitoring**:
- [ ] Prometheus metrics exposed
- [ ] Grafana dashboards created
- [ ] Alerts configured
- [ ] Log aggregation set up

**Backup & DR**:
- [ ] Backup strategy defined
- [ ] Disaster recovery tested
- [ ] RTO/RPO documented

---

## Hands-On Exercise: Complete Stack

Deploy a production-like application with all pieces:

### 1. Deploy Ingress Controller

```bash
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.metrics.enabled=true \
  --set controller.metrics.serviceMonitor.enabled=true \
  --set controller.metrics.serviceMonitor.additionalLabels.release=kps
```

### 2. Deploy Monitoring Stack

```bash
helm upgrade --install kps prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false
```

### 3. Deploy Application

**File**: `values-production.yaml`
```yaml
replicaCount: 3

image:
  repository: nginx
  tag: 1.25

service:
  type: ClusterIP
  port: 80

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: app.localtest.me
      paths:
        - path: /
          pathType: Prefix

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 200m
    memory: 256Mi

livenessProbe:
  httpGet:
    path: /
    port: http

readinessProbe:
  httpGet:
    path: /
    port: http

podSecurityContext:
  runAsNonRoot: true
  runAsUser: 10001

securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
    - ALL

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
```

```bash
helm install my-app bitnami/nginx -f values-production.yaml
```

### 4. Verify Everything

```bash
# Check app
curl http://app.localtest.me

# Check metrics
kubectl -n monitoring port-forward svc/kps-grafana 3000:80
# Open: http://localhost:3000

# Check autoscaling
kubectl get hpa

# Check security
kubectl get pod -o jsonpath='{.items[0].spec.securityContext}'
```

---

## Validation Checklist

- [ ] Install and use Helm charts
- [ ] Customize charts with values files
- [ ] Upgrade and rollback Helm releases
- [ ] Deploy Prometheus & Grafana
- [ ] View metrics in Grafana
- [ ] Configure ServiceMonitor
- [ ] Apply SecurityContext to pods
- [ ] Create NetworkPolicy
- [ ] Understand RBAC basics
- [ ] Deploy production-ready application

---

## Key Takeaways

1. **Helm** simplifies application packaging and deployment
2. **Prometheus & Grafana** provide observability
3. **SecurityContext** enforces container security
4. **NetworkPolicies** control pod-to-pod traffic
5. **RBAC** limits cluster access
6. **Production readiness** requires multiple layers

---

## Migrating to Cloud (AWS/GCP/Azure)

**What changes in cloud?**

| Component | Local | AWS | GCP | Azure |
|-----------|-------|-----|-----|-------|
| **Cluster** | Docker Desktop / kind | EKS | GKE | AKS |
| **LoadBalancer** | localhost | ELB/ALB | Cloud Load Balancer | Azure LB |
| **Storage** | hostPath | EBS | Persistent Disk | Azure Disk |
| **Ingress** | ingress-nginx | AWS Load Balancer Controller | GKE Ingress | Application Gateway |
| **DNS** | localtest.me | Route 53 + ExternalDNS | Cloud DNS + ExternalDNS | Azure DNS |
| **TLS** | Self-signed | ACM + cert-manager | Google-managed certs | Key Vault |
| **Monitoring** | kube-prom-stack | CloudWatch, Prometheus | Cloud Monitoring | Azure Monitor |

**Example: EKS deployment**:
```bash
# Create cluster
eksctl create cluster --name prod --region us-west-2

# Install AWS Load Balancer Controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=prod

# Deploy app (same Helm charts!)
helm install my-app bitnami/nginx -f values-production.yaml
```

**Key changes**:
- Ingress creates real ALB/ELB
- PVCs provision EBS volumes
- LoadBalancer services get real IPs
- Add IAM roles for pods (IRSA)

---

## Additional Resources

- [Helm Documentation](https://helm.sh/docs/)
- [Prometheus Operator](https://prometheus-operator.dev/)
- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/)
- [Production Best Practices](https://learnk8s.io/production-best-practices)

---

## Congratulations!

You've completed the beginner track! You can now:
- Deploy, scale, and manage applications
- Configure networking and storage
- Monitor and secure workloads
- Use Helm for package management
- Apply production best practices

### Next Steps

**Option 1**: Build a real project
- Deploy a multi-tier application
- Add CI/CD pipeline
- Implement GitOps

**Option 2**: Expert Track
- [Advanced Networking](../../expert/01-advanced-networking/README.md)
- [Advanced Security](../../expert/02-advanced-security/README.md)
- [Operators & CRDs](../../expert/03-operators-crds/README.md)

**Option 3**: Certification
- Practice for CKA or CKAD
- Set up cloud K8s cluster (EKS/GKE/AKS)

---

**Clean up**:
```bash
helm uninstall my-app
helm uninstall kps -n monitoring
helm uninstall ingress-nginx -n ingress-nginx
kubectl delete namespace monitoring ingress-nginx
```
