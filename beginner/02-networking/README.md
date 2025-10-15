# Module 02: Kubernetes Networking

**Duration**: ~3 hours
**Prerequisites**: [Module 01: Fundamentals](../01-fundamentals/README.md)
**Next Module**: [03-Configuration](../03-configuration/README.md)

## Learning Objectives

By the end of this module, you will:
- ✅ Understand Kubernetes networking model
- ✅ Create and use Services (ClusterIP, NodePort, LoadBalancer)
- ✅ Deploy and configure Ingress controllers
- ✅ Implement host-based routing with Ingress
- ✅ Understand DNS and service discovery
- ✅ Troubleshoot networking issues

---

## Part 1: The Kubernetes Networking Model

### The Challenge

Pods are ephemeral:
- They get random IPs
- They die and restart with new IPs
- Multiple replicas have different IPs

**Question**: How do clients reliably reach pods?
**Answer**: Services

### Networking Fundamentals

Every Pod gets its own IP address:
```bash
# Create a deployment
kubectl create deployment web --image=nginx:1.25 --replicas=3

# Get pod IPs
kubectl get pods -o wide

# Expected:
# NAME                   READY   STATUS    IP           NODE
# web-5d4f8c5b4d-abc12   1/1     Running   10.1.0.5     node1
# web-5d4f8c5b4d-def34   1/1     Running   10.1.0.6     node1
# web-5d4f8c5b4d-ghi56   1/1     Running   10.1.0.7     node2
```

**Key insight**: These IPs are internal to the cluster and change when pods restart.

---

## Part 2: Services - Stable Networking

A **Service** is a stable network endpoint that load-balances across a set of pods.

### Service Types

1. **ClusterIP** (default): Internal cluster IP, accessible only within cluster
2. **NodePort**: Exposes service on each node's IP at a static port
3. **LoadBalancer**: Cloud provider load balancer (AWS ELB, GCP GLB, etc.)
4. **ExternalName**: DNS CNAME alias

### ClusterIP Service

**Most common type** - used for internal pod-to-pod communication.

**File**: `service-clusterip.yaml`
```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-service
spec:
  type: ClusterIP  # Default, can omit
  selector:
    app: web  # Targets pods with this label
  ports:
  - port: 80        # Service port
    targetPort: 80  # Container port
    protocol: TCP
```

```bash
# Create deployment (if not exists)
kubectl create deployment web --image=nginx:1.25 --replicas=3

# Create service
kubectl apply -f service-clusterip.yaml

# View service
kubectl get service web-service
kubectl get svc web-service  # shorthand

# Expected:
# NAME          TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
# web-service   ClusterIP   10.96.100.123   <none>        80/TCP    10s

# Check endpoints (pod IPs backing the service)
kubectl get endpoints web-service

# Test from within cluster
kubectl run test-pod --rm -it --image=busybox:1.36 -- sh
# Inside the pod:
wget -qO- http://web-service
exit
```

**How it works**:
1. Service gets a stable ClusterIP (e.g., 10.96.100.123)
2. Service selector matches pods with label `app=web`
3. Requests to ClusterIP are load-balanced to matching pods
4. DNS resolves `web-service` → ClusterIP

### NodePort Service

Exposes service on every node's IP at a specific port (30000-32767).

**File**: `service-nodeport.yaml`
```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-nodeport
spec:
  type: NodePort
  selector:
    app: web
  ports:
  - port: 80        # Service port
    targetPort: 80  # Container port
    nodePort: 30080 # Accessible on <NodeIP>:30080
```

```bash
kubectl apply -f service-nodeport.yaml

# View service
kubectl get svc web-nodeport

# Expected:
# NAME           TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
# web-nodeport   NodePort   10.96.200.50    <none>        80:30080/TCP   5s

# Access via localhost (Docker Desktop / kind)
curl http://localhost:30080

# Or via node IP
kubectl get nodes -o wide  # Get node IP
curl http://<NODE-IP>:30080
```

**Use case**: Development, or when you don't have a LoadBalancer.

### LoadBalancer Service

Cloud providers provision an external load balancer.

**File**: `service-loadbalancer.yaml`
```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-lb
spec:
  type: LoadBalancer
  selector:
    app: web
  ports:
  - port: 80
    targetPort: 80
```

```bash
kubectl apply -f service-loadbalancer.yaml

# View service
kubectl get svc web-lb

# On Docker Desktop / kind: EXTERNAL-IP shows localhost or pending
# On cloud (EKS/GKE/AKS): EXTERNAL-IP shows actual LB address

# Expected (Docker Desktop):
# NAME     TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
# web-lb   LoadBalancer   10.96.300.100   localhost     80:31234/TCP   30s

# Access
curl http://localhost
```

**Use case**: Production cloud deployments.

---

## Part 3: Ingress - HTTP Routing

**Problem**: LoadBalancers are expensive (one per service). For HTTP apps, we want:
- Host-based routing: `api.example.com` → api service
- Path-based routing: `/app1` → app1 service, `/app2` → app2 service
- TLS termination

**Solution**: Ingress

### Architecture

```
                   ┌──────────────┐
Internet ────────> │   Ingress    │ (L7 Load Balancer)
                   │  Controller  │
                   └───────┬──────┘
                           │
           ┌───────────────┼───────────────┐
           │               │               │
           v               v               v
    ┌──────────┐    ┌──────────┐    ┌──────────┐
    │ Service  │    │ Service  │    │ Service  │
    │   web    │    │   api    │    │   admin  │
    └────┬─────┘    └────┬─────┘    └────┬─────┘
         │               │               │
         v               v               v
       Pods            Pods            Pods
```

### Step 1: Install Ingress Controller

An Ingress object is just configuration—you need a **controller** to implement it.

We'll use **ingress-nginx** (most popular):

```bash
# Add Helm repo
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install ingress-nginx controller
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace

# Verify it's running
kubectl -n ingress-nginx get pods,svc

# Expected:
# Pod: ingress-nginx-controller-xxxxx   Running
# Service: ingress-nginx-controller     LoadBalancer   localhost
```

### Step 2: Deploy an Application

Use Helm to deploy a real application (Bitnami NGINX chart):

```bash
# Add Bitnami repo
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Create values file (already in repo root)
cat > values-nginx.yaml <<'EOF'
service:
  type: ClusterIP  # Ingress will route to this
ingress:
  enabled: true
  hostname: hello.localtest.me  # Resolves to 127.0.0.1
  ingressClassName: nginx
  path: /
EOF

# Deploy
helm upgrade --install web bitnami/nginx -f values-nginx.yaml

# Check resources
kubectl get deploy,svc,ingress
```

**What's `localtest.me`?**
It's a magic domain that resolves to 127.0.0.1—no `/etc/hosts` edits needed!

### Step 3: Access via Ingress

```bash
# Browser: http://hello.localtest.me

# Or curl
curl -i http://hello.localtest.me

# Should see NGINX welcome page
```

**What just happened?**
1. Browser sends request to `hello.localtest.me` (resolves to 127.0.0.1)
2. Ingress controller receives request on port 80
3. Matches `Host: hello.localtest.me` header to Ingress rule
4. Routes to `web-nginx` Service
5. Service load-balances to backend Pods

### Ingress Manifest Deep Dive

**File**: `ingress-basic.yaml`
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx  # Which controller handles this
  rules:
  - host: hello.localtest.me  # Host-based routing
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-service
            port:
              number: 80
```

```bash
kubectl apply -f ingress-basic.yaml

# Describe to see routing rules
kubectl describe ingress web-ingress
```

### Path-Based Routing

Route different paths to different services:

**File**: `ingress-paths.yaml`
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: multi-path-ingress
spec:
  ingressClassName: nginx
  rules:
  - host: app.localtest.me
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 8080
      - path: /web
        pathType: Prefix
        backend:
          service:
            name: web-service
            port:
              number: 80
```

Requests:
- `http://app.localtest.me/api/users` → api-service
- `http://app.localtest.me/web/index.html` → web-service

---

## Part 4: DNS and Service Discovery

Kubernetes has built-in DNS (CoreDNS).

### DNS Resolution

Services are automatically resolvable:

```bash
# Create a service
kubectl create deployment nginx --image=nginx:1.25
kubectl expose deployment nginx --port=80

# From another pod, resolve by name
kubectl run test --rm -it --image=busybox:1.36 -- sh
# Inside pod:
nslookup nginx
# Returns: nginx.default.svc.cluster.local → 10.96.x.x

wget -qO- http://nginx
# Works!

exit
```

**DNS Format**:
```
<service-name>.<namespace>.svc.cluster.local
```

**Short forms**:
- Same namespace: `service-name`
- Different namespace: `service-name.namespace`

### Cross-Namespace Communication

```bash
# Create service in another namespace
kubectl create namespace staging
kubectl -n staging create deployment api --image=nginx:1.25
kubectl -n staging expose deployment api --port=80

# From default namespace
kubectl run test --rm -it --image=busybox:1.36 -- sh
wget -qO- http://api.staging
# Works! Resolves to api.staging.svc.cluster.local
exit
```

---

## Hands-On Exercises

### Exercise 1: Multi-Service Application

Deploy a frontend and backend, expose via services.

```bash
# Backend
kubectl create deployment backend --image=nginx:1.25
kubectl expose deployment backend --port=80

# Frontend
kubectl create deployment frontend --image=nginx:1.25
kubectl expose deployment frontend --port=80 --type=NodePort

# Test frontend can reach backend
kubectl exec -it deploy/frontend -- sh
# Inside:
curl http://backend
exit
```

### Exercise 2: Multi-Host Ingress

**File**: `ingress-multi-host.yaml`
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: multi-host-ingress
spec:
  ingressClassName: nginx
  rules:
  - host: web.localtest.me
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend
            port:
              number: 80
  - host: api.localtest.me
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: backend
            port:
              number: 80
```

```bash
kubectl apply -f ingress-multi-host.yaml

# Test
curl http://web.localtest.me
curl http://api.localtest.me
```

### Exercise 3: Service Discovery

Create a multi-tier app where frontend calls backend via DNS:

```bash
# Backend
kubectl create deployment api --image=hashicorp/http-echo:latest -- -text="Backend API"
kubectl expose deployment api --port=5678

# Frontend (using busybox to simulate)
kubectl run frontend --image=busybox:1.36 -- sh -c "while true; do wget -qO- http://api:5678; sleep 5; done"

# Check frontend logs
kubectl logs frontend
# Should see "Backend API" every 5 seconds
```

---

## Troubleshooting Guide

### Issue: Can't reach service from outside cluster

**Symptoms**: `curl: (7) Failed to connect`

**Debug**:
```bash
# 1. Check service exists
kubectl get svc

# 2. Check endpoints are populated
kubectl get endpoints <service-name>
# If empty, selector doesn't match any pods

# 3. Check pod labels
kubectl get pods --show-labels

# 4. Fix selector
kubectl edit service <service-name>
# Update spec.selector to match pod labels
```

### Issue: Ingress returns 404

**Symptoms**: Ingress controller responds, but 404 Not Found

**Debug**:
```bash
# 1. Check ingress rules
kubectl describe ingress <name>

# 2. Verify backend service exists
kubectl get svc <backend-service>

# 3. Check ingress controller logs
kubectl -n ingress-nginx logs deploy/ingress-nginx-controller

# 4. Verify Host header matches
curl -v -H "Host: hello.localtest.me" http://127.0.0.1/
```

### Issue: DNS not resolving

**Symptoms**: `wget: bad address 'service-name'`

**Debug**:
```bash
# 1. Check CoreDNS is running
kubectl -n kube-system get pods -l k8s-app=kube-dns

# 2. Test DNS from pod
kubectl run test --rm -it --image=busybox:1.36 -- sh
nslookup kubernetes.default
# Should resolve
exit

# 3. Check service exists in correct namespace
kubectl get svc -A | grep <service-name>
```

### Issue: Ingress controller not running

**Debug**:
```bash
# Check controller pod
kubectl -n ingress-nginx get pods

# If CrashLooping, check logs
kubectl -n ingress-nginx logs deploy/ingress-nginx-controller

# Common fix: Reinstall
helm uninstall ingress-nginx -n ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx --create-namespace
```

---

## Validation Checklist

Before moving to the next module, ensure you can:

- [ ] Create a ClusterIP service and access it from within cluster
- [ ] Create a NodePort service and access it from localhost
- [ ] Install ingress-nginx controller
- [ ] Create an Ingress resource with host-based routing
- [ ] Access application via Ingress
- [ ] Resolve service names via DNS from pods
- [ ] Troubleshoot service connectivity issues
- [ ] Understand the difference between Service types

**Self-Test**:
```bash
# Can you do this without looking?
kubectl create deployment test --image=nginx:1.25
kubectl expose deployment test --port=80
kubectl run busybox --rm -it --image=busybox:1.36 -- wget -qO- http://test
```

---

## Key Takeaways

1. **Services** provide stable network endpoints for ephemeral pods
2. **ClusterIP** for internal communication (most common)
3. **NodePort** for development/testing access
4. **LoadBalancer** for production cloud deployments
5. **Ingress** provides L7 routing for HTTP/HTTPS
6. **DNS** automatically resolves service names
7. **Ingress controllers** must be installed separately

---

## Additional Resources

- [Kubernetes Services](https://kubernetes.io/docs/concepts/services-networking/service/)
- [Ingress Documentation](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [ingress-nginx Controller](https://kubernetes.github.io/ingress-nginx/)
- [DNS for Services](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)

---

## Next Steps

Ready to configure your applications? → [Module 03: Configuration](../03-configuration/README.md)

---

**Clean up**:
```bash
helm uninstall web
kubectl delete deployment --all
kubectl delete service --all
kubectl delete ingress --all
```
