# Module 04: Workload Management

**Duration**: ~2 hours
**Prerequisites**: [Module 03: Configuration](../03-configuration/README.md)
**Next Module**: [05-Production Basics](../05-production-basics/README.md)

## Learning Objectives

By the end of this module, you will:
- ✅ Scale applications manually and automatically (HPA)
- ✅ Perform rolling updates and rollbacks
- ✅ Implement health checks (liveness, readiness, startup probes)
- ✅ Manage resource requests and limits
- ✅ Understand Quality of Service (QoS) classes
- ✅ Use DaemonSets, StatefulSets, and Jobs

---

## Part 1: Scaling Applications

### Manual Scaling

```bash
# Create deployment
kubectl create deployment web --image=nginx:1.25 --replicas=2

# Scale up
kubectl scale deployment web --replicas=5

# Scale down
kubectl scale deployment web --replicas=1

# Watch scaling
kubectl get pods -w
```

**Declarative scaling**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 10  # Just change this number
  # ... rest of spec
```

### Horizontal Pod Autoscaler (HPA)

HPA automatically scales based on metrics (CPU, memory, custom metrics).

**Prerequisites**: Metrics Server must be installed
```bash
# Install metrics server
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update
helm upgrade --install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  --set args[0]=--kubelet-insecure-tls  # For local clusters

# Verify
kubectl top nodes
kubectl top pods
```

**File**: `deployment-with-resources.yaml`
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        resources:
          requests:
            cpu: 100m      # 0.1 CPU cores
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
```

**File**: `hpa.yaml`
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50  # Scale when CPU > 50%
```

```bash
kubectl apply -f deployment-with-resources.yaml
kubectl apply -f hpa.yaml

# Watch HPA
kubectl get hpa -w

# Or imperatively
kubectl autoscale deployment web --cpu-percent=50 --min=2 --max=10

# Generate load to trigger scaling
kubectl run load-generator --rm -it --image=busybox:1.36 -- sh
# Inside pod:
while true; do wget -q -O- http://web; done
```

---

## Part 2: Rolling Updates & Rollbacks

### Update Strategies

**RollingUpdate** (default): Gradually replace old pods with new
**Recreate**: Delete all old pods, then create new (causes downtime)

**File**: `deployment-rolling-update.yaml`
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 5
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1        # Max pods above desired count during update
      maxUnavailable: 1  # Max pods unavailable during update
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
```

### Performing Updates

```bash
kubectl apply -f deployment-rolling-update.yaml

# Update image
kubectl set image deployment/web nginx=nginx:1.26

# Watch rollout
kubectl rollout status deployment/web

# See rollout in real-time
kubectl get pods -w
```

### Rollback

```bash
# View revision history
kubectl rollout history deployment/web

# Rollback to previous revision
kubectl rollout undo deployment/web

# Rollback to specific revision
kubectl rollout undo deployment/web --to-revision=1

# Pause/resume rollout
kubectl rollout pause deployment/web
kubectl rollout resume deployment/web
```

---

## Part 3: Health Checks

Kubernetes provides three types of probes to monitor application health.

### Liveness Probe

**Purpose**: Detect if application is running. If fails, Kubernetes restarts the container.

**File**: `deployment-liveness.yaml`
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 3   # Wait before first probe
          periodSeconds: 5         # Check every 5 seconds
          timeoutSeconds: 1
          failureThreshold: 3      # Restart after 3 failures
```

### Readiness Probe

**Purpose**: Detect if application is ready to serve traffic. If fails, removes pod from service endpoints.

**File**: `deployment-readiness.yaml`
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 2
          periodSeconds: 5
          failureThreshold: 1      # Remove from service immediately
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 10
```

### Startup Probe

**Purpose**: For slow-starting applications. Delays liveness/readiness checks until startup succeeds.

```yaml
startupProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 0
  periodSeconds: 10
  failureThreshold: 30  # 30 * 10 = 300s (5 min) to start
```

### Probe Types

1. **HTTP GET**: Request a HTTP endpoint
2. **TCP Socket**: Check if port is open
3. **Exec**: Run command inside container

```yaml
# TCP example
livenessProbe:
  tcpSocket:
    port: 3306
  initialDelaySeconds: 15

# Exec example
livenessProbe:
  exec:
    command:
    - cat
    - /tmp/healthy
  initialDelaySeconds: 5
```

---

## Part 4: Resource Management

### Requests vs Limits

- **Requests**: Guaranteed resources (used for scheduling)
- **Limits**: Maximum resources container can use

```yaml
resources:
  requests:
    cpu: 100m        # 0.1 CPU core
    memory: 128Mi    # 128 Mebibytes
  limits:
    cpu: 500m        # 0.5 CPU core
    memory: 512Mi
```

**CPU units**:
- `1` = 1 CPU core
- `100m` = 0.1 CPU core (100 millicores)

**Memory units**:
- `128Mi` = 128 Mebibytes (128 * 1024^2 bytes)
- `1Gi` = 1 Gibibyte

### Quality of Service (QoS) Classes

Kubernetes assigns QoS class based on requests/limits:

1. **Guaranteed**: requests = limits (highest priority)
2. **Burstable**: requests < limits
3. **BestEffort**: No requests/limits (lowest priority, first to evict)

```bash
# Check QoS class
kubectl get pod <name> -o jsonpath='{.status.qosClass}'
```

### Resource Quotas

Limit resource usage per namespace:

**File**: `resourcequota.yaml`
```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
  namespace: dev
spec:
  hard:
    requests.cpu: "10"        # Total CPU requests
    requests.memory: 20Gi     # Total memory requests
    limits.cpu: "20"
    limits.memory: 40Gi
    persistentvolumeclaims: "5"
    pods: "50"
```

```bash
kubectl create namespace dev
kubectl apply -f resourcequota.yaml
kubectl describe resourcequota -n dev
```

---

## Part 5: Other Workload Types

### DaemonSet

Runs one pod per node (e.g., log collectors, monitoring agents).

**File**: `daemonset.yaml`
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-logger
spec:
  selector:
    matchLabels:
      app: node-logger
  template:
    metadata:
      labels:
        app: node-logger
    spec:
      containers:
      - name: logger
        image: busybox:1.36
        command: ['sh', '-c', 'while true; do echo "Logging on $(hostname)"; sleep 30; done']
```

```bash
kubectl apply -f daemonset.yaml
kubectl get daemonset
kubectl get pods -l app=node-logger -o wide
# One pod per node
```

### StatefulSet

For stateful applications with stable network identities (databases, queues).

**File**: `statefulset.yaml`
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  serviceName: web  # Headless service required
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: web
spec:
  clusterIP: None  # Headless service
  selector:
    app: web
  ports:
  - port: 80
```

```bash
kubectl apply -f statefulset.yaml

# Pods have stable names
kubectl get pods
# web-0, web-1, web-2

# Ordered creation and deletion
kubectl scale statefulset web --replicas=5
# Creates web-3, then web-4

kubectl scale statefulset web --replicas=2
# Deletes web-4, then web-3
```

### Job

Runs pods to completion (batch processing, migrations).

**File**: `job.yaml`
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: batch-job
spec:
  completions: 3      # Run 3 successful completions
  parallelism: 2      # Run 2 pods in parallel
  template:
    spec:
      containers:
      - name: worker
        image: busybox:1.36
        command: ['sh', '-c', 'echo "Processing batch"; sleep 10']
      restartPolicy: Never
  backoffLimit: 4     # Retry on failure
```

```bash
kubectl apply -f job.yaml
kubectl get jobs -w
kubectl logs job/batch-job
```

### CronJob

Scheduled jobs (like cron).

**File**: `cronjob.yaml`
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: daily-backup
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: busybox:1.36
            command: ['sh', '-c', 'echo "Running backup at $(date)"']
          restartPolicy: Never
```

---

## Hands-On Exercises

### Exercise 1: HPA with Load Testing

```bash
# Deploy app with resources
kubectl apply -f deployment-with-resources.yaml

# Create HPA
kubectl autoscale deployment web --cpu-percent=30 --min=2 --max=10

# Create service
kubectl expose deployment web --port=80

# Generate load
kubectl run -it --rm load-generator --image=busybox:1.36 -- sh
while true; do wget -q -O- http://web; done

# In another terminal, watch scaling
kubectl get hpa -w
kubectl get pods -w
```

### Exercise 2: Graceful Updates

Test zero-downtime rolling update:

```bash
# Deploy v1
kubectl create deployment web --image=nginx:1.25 --replicas=5
kubectl expose deployment web --port=80

# Continuous monitoring
while true; do curl -s http://<service-ip> | grep nginx; sleep 1; done

# Update to v2 (in another terminal)
kubectl set image deployment/web nginx=nginx:1.26

# Observe: No downtime!
```

### Exercise 3: Health Check Failure

```bash
# Deploy with probes
kubectl apply -f deployment-readiness.yaml
kubectl expose deployment web --port=80

# Break the app
kubectl exec deploy/web -- rm /usr/share/nginx/html/index.html

# Watch pod become unready
kubectl get pods -w
# STATUS changes to Running but 0/1 Ready

# Service stops routing to it
kubectl get endpoints web
```

---

## Validation Checklist

- [ ] Scale deployment manually
- [ ] Configure and use HPA
- [ ] Perform rolling update
- [ ] Rollback a deployment
- [ ] Implement liveness probe
- [ ] Implement readiness probe
- [ ] Set resource requests and limits
- [ ] Create a DaemonSet
- [ ] Create a Job
- [ ] Understand QoS classes

---

## Key Takeaways

1. **HPA** enables automatic scaling based on metrics
2. **Rolling updates** provide zero-downtime deployments
3. **Liveness probes** restart unhealthy containers
4. **Readiness probes** control traffic routing
5. **Resource requests** guarantee minimum resources
6. **Resource limits** prevent resource exhaustion
7. **DaemonSets** run per-node workloads
8. **StatefulSets** manage stateful applications
9. **Jobs/CronJobs** handle batch/scheduled tasks

---

## Additional Resources

- [HPA Documentation](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [Deployments Deep Dive](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Pod Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
- [Resource Management](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)

---

## Next Steps

Ready for production? → [Module 05: Production Basics](../05-production-basics/README.md)

---

**Clean up**:
```bash
kubectl delete deployment --all
kubectl delete hpa --all
kubectl delete job --all
kubectl delete daemonset --all
kubectl delete statefulset --all
```
