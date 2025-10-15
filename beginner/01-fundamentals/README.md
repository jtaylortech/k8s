# Module 01: Kubernetes Fundamentals

**Duration**: ~3 hours
**Prerequisites**: [Setup complete](../../PREREQUISITES.md)
**Next Module**: [02-Networking](../02-networking/README.md)

## Learning Objectives

By the end of this module, you will:
- ✅ Understand what Kubernetes is and why it exists
- ✅ Know the core Kubernetes resources (Pods, Deployments, ReplicaSets)
- ✅ Deploy your first application
- ✅ Understand the declarative model
- ✅ Use `kubectl` confidently for basic operations

---

## Part 1: What is Kubernetes?

### The Problem Kubernetes Solves

Imagine you have an application running in containers. Questions arise:
- **What if the container crashes?** Who restarts it?
- **What if you need 10 copies?** How do you manage them?
- **What if the host dies?** How do containers move to another host?
- **How do containers find each other?** What about networking?
- **How do you update without downtime?** Rolling updates?

**Kubernetes** is a container orchestration platform that automates these tasks.

### Core Concepts

```
┌─────────────────────────────────────────────────────────────┐
│                         CLUSTER                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              CONTROL PLANE (Master)                   │   │
│  │  - API Server (kubectl talks to this)                │   │
│  │  - Scheduler (decides where pods run)                │   │
│  │  - Controller Manager (keeps desired state)          │   │
│  │  - etcd (database of cluster state)                  │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   NODE 1     │  │   NODE 2     │  │   NODE 3     │      │
│  │  ┌────────┐  │  │  ┌────────┐  │  │  ┌────────┐  │      │
│  │  │  Pod   │  │  │  │  Pod   │  │  │  │  Pod   │  │      │
│  │  │ nginx  │  │  │  │  app   │  │  │  │  db    │  │      │
│  │  └────────┘  │  │  └────────┘  │  │  └────────┘  │      │
│  │  ┌────────┐  │  │  ┌────────┐  │  │              │      │
│  │  │  Pod   │  │  │  │  Pod   │  │  │              │      │
│  │  └────────┘  │  │  └────────┘  │  │              │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

**Key Terms**:
- **Cluster**: A set of machines (nodes) running Kubernetes
- **Node**: A machine (physical or VM) that runs containers
- **Pod**: The smallest deployable unit—wraps one or more containers
- **Control Plane**: The brain of Kubernetes (API, scheduler, controllers)

---

## Part 2: Pods - The Atomic Unit

A **Pod** is the smallest unit in Kubernetes. It wraps one or more containers that:
- Share network namespace (same IP, can talk via localhost)
- Share storage volumes
- Are scheduled together on the same node
- Live and die together

### Why Pods, Not Just Containers?

Kubernetes manages Pods, not containers directly. This allows:
- **Sidecar patterns**: main app + logging agent in same Pod
- **Shared storage**: containers can share files
- **Co-location**: containers that must run together, do

### Your First Pod

Create a simple NGINX web server:

```bash
# Create a pod imperatively (quick way)
kubectl run my-nginx --image=nginx:1.25

# Check if it's running
kubectl get pods

# Expected output:
# NAME       READY   STATUS    RESTARTS   AGE
# my-nginx   1/1     Running   0          10s
```

**What just happened?**
1. kubectl sent request to API server
2. Scheduler assigned pod to a node
3. Kubelet on that node pulled the nginx image
4. Container started

### Inspecting Pods

```bash
# Detailed information
kubectl describe pod my-nginx

# Pod logs (STDOUT from container)
kubectl logs my-nginx

# Execute command inside pod
kubectl exec my-nginx -- nginx -v

# Interactive shell
kubectl exec -it my-nginx -- /bin/bash
# Try: curl localhost
# exit to leave

# Port-forward to access locally
kubectl port-forward my-nginx 8080:80
# Visit http://localhost:8080 in browser
# Ctrl+C to stop
```

### Declarative Pod Definition

The imperative `kubectl run` is quick, but in production we use **declarative YAML**:

**File**: `pod-nginx.yaml`
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-declarative
  labels:
    app: nginx
    env: learning
spec:
  containers:
  - name: nginx
    image: nginx:1.25
    ports:
    - containerPort: 80
```

Apply it:
```bash
# Create from file
kubectl apply -f pod-nginx.yaml

# Verify
kubectl get pods -l app=nginx

# Get YAML of running pod
kubectl get pod nginx-declarative -o yaml
```

**Delete pods**:
```bash
kubectl delete pod my-nginx
kubectl delete pod nginx-declarative
# Or: kubectl delete -f pod-nginx.yaml
```

---

## Part 3: ReplicaSets - Managing Multiple Pods

**Problem**: A single Pod dies when:
- The container crashes
- The node fails
- You delete it

A **ReplicaSet** ensures a specified number of pod replicas are running at all times.

**File**: `replicaset-nginx.yaml`
```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: nginx-rs
spec:
  replicas: 3  # Keep 3 pods running
  selector:
    matchLabels:
      app: nginx-rs
  template:
    metadata:
      labels:
        app: nginx-rs
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
```

```bash
# Create the ReplicaSet
kubectl apply -f replicaset-nginx.yaml

# Watch pods being created
kubectl get pods -w
# (Ctrl+C to stop watching)

# See the ReplicaSet
kubectl get replicaset
kubectl get rs  # shorthand

# Try deleting a pod
kubectl delete pod <pod-name>  # Use actual pod name from 'get pods'

# Watch it get recreated immediately!
kubectl get pods
```

**Key insight**: ReplicaSet watches for pods with matching labels. If count < desired, it creates more.

### Scaling

```bash
# Scale up
kubectl scale replicaset nginx-rs --replicas=5
kubectl get pods

# Scale down
kubectl scale rs nginx-rs --replicas=2
kubectl get pods
```

**Cleanup**:
```bash
kubectl delete replicaset nginx-rs
# Deleting ReplicaSet also deletes its pods
```

---

## Part 4: Deployments - Production Workload Management

**Problem**: ReplicaSets are low-level. What about:
- **Rolling updates** (update without downtime)
- **Rollbacks** (undo bad deployments)
- **Declarative updates** (change image version in YAML)

**Deployment** manages ReplicaSets for you, adding update strategies.

### Architecture

```
Deployment
  └─> ReplicaSet (v1)
        └─> Pod
        └─> Pod
        └─> Pod
```

When you update:
```
Deployment
  ├─> ReplicaSet (v1) [old, scaled down]
  └─> ReplicaSet (v2) [new, scaled up]
        └─> Pod
        └─> Pod
        └─> Pod
```

### Your First Deployment

**File**: `deployment-nginx.yaml`
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
```

```bash
# Create deployment
kubectl apply -f deployment-nginx.yaml

# Check deployment status
kubectl get deployments
kubectl get deploy  # shorthand

# See the ReplicaSet it created
kubectl get rs

# See the pods
kubectl get pods -l app=nginx

# All in one view
kubectl get deploy,rs,pods
```

### Rolling Updates

Update the image version:

```bash
# Method 1: Imperative update
kubectl set image deployment/nginx-deployment nginx=nginx:1.26

# Watch the rollout
kubectl rollout status deployment/nginx-deployment

# Method 2: Declarative (edit YAML and re-apply)
# Edit deployment-nginx.yaml: change image to nginx:1.26
kubectl apply -f deployment-nginx.yaml
```

**What happened?**
1. Deployment created new ReplicaSet with new image
2. Gradually scaled up new, scaled down old (rolling update)
3. Old ReplicaSet kept (for rollback)

```bash
# See rollout history
kubectl rollout history deployment/nginx-deployment

# Detailed revision
kubectl rollout history deployment/nginx-deployment --revision=2
```

### Rollbacks

```bash
# Oops, bad version! Rollback to previous
kubectl rollout undo deployment/nginx-deployment

# Or rollback to specific revision
kubectl rollout undo deployment/nginx-deployment --to-revision=1

# Check status
kubectl rollout status deployment/nginx-deployment
```

### Scaling Deployments

```bash
# Scale up
kubectl scale deployment nginx-deployment --replicas=5

# Or edit YAML and apply
# Change replicas: 5 in deployment-nginx.yaml
kubectl apply -f deployment-nginx.yaml
```

---

## Part 5: The Declarative Workflow

Kubernetes follows a **declarative** model:
- **Imperative**: "Create this, delete that, update this"
- **Declarative**: "Here's the desired state, make it so"

### Best Practice Workflow

```bash
# 1. Write desired state in YAML
cat > my-app.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
      - name: app
        image: nginx:1.25
EOF

# 2. Apply (create or update)
kubectl apply -f my-app.yaml

# 3. Change desired state in YAML (e.g., replicas: 4)

# 4. Re-apply
kubectl apply -f my-app.yaml

# Kubernetes reconciles current state → desired state
```

### Benefits

- **Version control**: YAML in Git
- **Reproducible**: Same YAML → same state
- **Auditable**: See what changed
- **Disaster recovery**: Re-apply YAMLs to rebuild cluster

---

## Hands-On Exercises

### Exercise 1: Multi-Container Pod

Create a pod with two containers: nginx (web server) and busybox (sidecar that curls nginx every 5 seconds).

**File**: `pod-multi-container.yaml`
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web-with-sidecar
spec:
  containers:
  - name: nginx
    image: nginx:1.25
    ports:
    - containerPort: 80
  - name: sidecar
    image: busybox:1.36
    command:
    - sh
    - -c
    - while true; do wget -qO- http://localhost; sleep 5; done
```

```bash
kubectl apply -f pod-multi-container.yaml

# Check both containers are running
kubectl get pod web-with-sidecar

# Logs from specific container
kubectl logs web-with-sidecar -c nginx
kubectl logs web-with-sidecar -c sidecar
```

**Expected**: Sidecar logs show HTML from nginx every 5 seconds.

### Exercise 2: Deployment with Labels

Create a deployment for a "frontend" app with meaningful labels.

**File**: `deployment-frontend.yaml`
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  labels:
    tier: frontend
    app: webstore
spec:
  replicas: 4
  selector:
    matchLabels:
      tier: frontend
      app: webstore
  template:
    metadata:
      labels:
        tier: frontend
        app: webstore
        version: v1.0.0
    spec:
      containers:
      - name: web
        image: nginx:1.25
```

```bash
kubectl apply -f deployment-frontend.yaml

# Filter by labels
kubectl get pods -l tier=frontend
kubectl get pods -l app=webstore,version=v1.0.0

# Show labels
kubectl get pods --show-labels
```

### Exercise 3: Update and Rollback

```bash
# 1. Deploy initial version
kubectl apply -f deployment-nginx.yaml

# 2. Update to new version
kubectl set image deployment/nginx-deployment nginx=nginx:1.26

# 3. Watch rollout
kubectl rollout status deployment/nginx-deployment

# 4. Check revision history
kubectl rollout history deployment/nginx-deployment

# 5. Rollback
kubectl rollout undo deployment/nginx-deployment

# 6. Verify old version is back
kubectl describe deployment nginx-deployment | grep Image
```

---

## Validation Checklist

Before moving to the next module, ensure you can:

- [ ] Create a pod imperatively with `kubectl run`
- [ ] Create a pod from YAML with `kubectl apply`
- [ ] View logs with `kubectl logs`
- [ ] Execute commands in pods with `kubectl exec`
- [ ] Understand labels and selectors
- [ ] Create a ReplicaSet and observe self-healing
- [ ] Create a Deployment
- [ ] Scale a deployment
- [ ] Update a deployment (rolling update)
- [ ] Rollback a deployment
- [ ] Explain the difference between Pod, ReplicaSet, and Deployment

**Self-Test**:
```bash
# Can you do this without looking?
kubectl create deployment test --image=nginx:1.25 --replicas=3
kubectl scale deployment test --replicas=5
kubectl set image deployment/test nginx=nginx:1.26
kubectl rollout undo deployment/test
kubectl delete deployment test
```

---

## Common Pitfalls

### 1. Pod Stuck in `ImagePullBackOff`
**Cause**: Image name wrong or not public
**Fix**:
```bash
kubectl describe pod <name>  # Check Events section
# Use correct image name
```

### 2. Selector Doesn't Match Labels
**Cause**: ReplicaSet/Deployment selector doesn't match pod template labels
**Fix**: Ensure `spec.selector.matchLabels` matches `spec.template.metadata.labels`

### 3. Deleting Wrong Resource
**Cause**: Deleted Deployment instead of Pod (or vice versa)
**Fix**:
```bash
# List all resources
kubectl get all

# Use labels to target
kubectl delete deployment -l app=myapp
```

---

## Key Takeaways

1. **Pods** are the smallest unit, wrap containers
2. **ReplicaSets** ensure N replicas are always running
3. **Deployments** add rolling updates, rollbacks, and revision history
4. **Declarative YAML** is the production way
5. **Labels and selectors** are how Kubernetes links resources

---

## Additional Resources

- [Kubernetes Pods Concept](https://kubernetes.io/docs/concepts/workloads/pods/)
- [Deployments Documentation](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

---

## Next Steps

Ready for networking? → [Module 02: Networking](../02-networking/README.md)

Want more practice? Try these challenges:
1. Deploy a multi-tier app (frontend + backend deployments)
2. Experiment with different update strategies
3. Create deployments with resource limits (preview of Module 03)

---

**Clean up before next module**:
```bash
kubectl delete deployment --all
kubectl delete replicaset --all
kubectl delete pod --all
```
