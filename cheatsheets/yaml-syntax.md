# Kubernetes YAML Syntax Guide

Quick reference for writing Kubernetes manifests.

## Basic Structure

Every Kubernetes resource has these required fields:

```yaml
apiVersion: <api-group>/<version>  # Which API to use
kind: <ResourceType>                # Type of resource
metadata:                           # Resource metadata
  name: <name>                      # Must be unique in namespace
  namespace: <namespace>            # Optional, defaults to 'default'
  labels:                           # Key-value pairs for organization
    key: value
  annotations:                      # Non-identifying metadata
    key: value
spec:                               # Desired state
  # Resource-specific fields
```

## Common Patterns

### Pod Template

Used in Deployments, Jobs, StatefulSets, etc.:

```yaml
template:
  metadata:
    labels:
      app: myapp
  spec:
    containers:
    - name: container-name
      image: image:tag
      ports:
      - containerPort: 80
      env:
      - name: ENV_VAR
        value: "value"
      resources:
        requests:
          cpu: 100m
          memory: 128Mi
        limits:
          cpu: 200m
          memory: 256Mi
```

### Labels and Selectors

**Labels** identify resources:
```yaml
metadata:
  labels:
    app: frontend
    tier: web
    environment: production
    version: v1.2.0
```

**Selectors** match labels:
```yaml
selector:
  matchLabels:
    app: frontend
    tier: web
  # Or more complex:
  matchExpressions:
  - key: environment
    operator: In
    values: [production, staging]
```

## Complete Examples

### Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
  labels:
    app: nginx
spec:
  containers:
  - name: nginx
    image: nginx:1.25
    ports:
    - containerPort: 80
      name: http
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
        port: 80
      initialDelaySeconds: 3
      periodSeconds: 5
    readinessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 2
      periodSeconds: 5
```

### Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-deployment
  labels:
    app: web
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
  template:
    metadata:
      labels:
        app: web
        version: v1.0.0
    spec:
      containers:
      - name: web
        image: nginx:1.25
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
```

### Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-service
spec:
  type: ClusterIP  # or NodePort, LoadBalancer
  selector:
    app: web
  ports:
  - name: http
    port: 80        # Service port
    targetPort: 80  # Container port
    protocol: TCP
```

### Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-service
            port:
              number: 80
  tls:
  - hosts:
    - example.com
    secretName: tls-secret
```

### ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  # Simple key-value
  APP_ENV: production
  LOG_LEVEL: info

  # File-like keys
  app.properties: |
    database.url=postgres://db:5432/mydb
    database.pool.size=10
    cache.enabled=true

  nginx.conf: |
    server {
      listen 80;
      location / {
        return 200 'OK';
      }
    }
```

### Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
type: Opaque
# Option 1: base64-encoded (data)
data:
  username: YWRtaW4=        # echo -n 'admin' | base64
  password: cGFzc3dvcmQ=    # echo -n 'password' | base64

# Option 2: plain text (stringData) - K8s encodes it
stringData:
  api-key: "secret-api-key-12345"
  db-url: "postgres://user:pass@host:5432/db"
```

### PersistentVolumeClaim

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data-pvc
spec:
  accessModes:
  - ReadWriteOnce  # RWO, ROX, or RWX
  resources:
    requests:
      storage: 10Gi
  storageClassName: standard  # Optional
```

### HorizontalPodAutoscaler

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web-deployment
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

### NetworkPolicy

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-network-policy
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    - namespaceSelector:
        matchLabels:
          name: production
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: database
    ports:
    - protocol: TCP
      port: 5432
```

## Environment Variables

### From literals

```yaml
env:
- name: ENV_VAR
  value: "literal-value"
- name: POD_NAME
  valueFrom:
    fieldRef:
      fieldPath: metadata.name
- name: POD_IP
  valueFrom:
    fieldRef:
      fieldPath: status.podIP
```

### From ConfigMap

```yaml
env:
# Single key
- name: APP_ENV
  valueFrom:
    configMapKeyRef:
      name: app-config
      key: APP_ENV

# All keys
envFrom:
- configMapRef:
    name: app-config
```

### From Secret

```yaml
env:
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: db-secrets
      key: password

envFrom:
- secretRef:
    name: db-secrets
```

## Volumes

### emptyDir (temporary)

```yaml
volumes:
- name: cache
  emptyDir: {}

volumeMounts:
- name: cache
  mountPath: /cache
```

### ConfigMap as volume

```yaml
volumes:
- name: config
  configMap:
    name: app-config

volumeMounts:
- name: config
  mountPath: /etc/config
```

### Secret as volume

```yaml
volumes:
- name: secrets
  secret:
    secretName: app-secrets

volumeMounts:
- name: secrets
  mountPath: /etc/secrets
  readOnly: true
```

### PersistentVolumeClaim

```yaml
volumes:
- name: data
  persistentVolumeClaim:
    claimName: data-pvc

volumeMounts:
- name: data
  mountPath: /data
```

## Resource Units

### CPU

- `1` = 1 CPU core
- `1000m` = 1 CPU core (1000 millicores)
- `500m` = 0.5 CPU core
- `100m` = 0.1 CPU core

### Memory

- `128Mi` = 128 Mebibytes (128 × 1024² bytes)
- `1Gi` = 1 Gibibyte (1024 MiB)
- `1G` = 1 Gigabyte (1000 MB) - less common

## Probes

### HTTP probe

```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
    httpHeaders:
    - name: Custom-Header
      value: value
  initialDelaySeconds: 3
  periodSeconds: 10
  timeoutSeconds: 1
  successThreshold: 1
  failureThreshold: 3
```

### TCP probe

```yaml
livenessProbe:
  tcpSocket:
    port: 3306
  initialDelaySeconds: 15
  periodSeconds: 10
```

### Exec probe

```yaml
livenessProbe:
  exec:
    command:
    - cat
    - /tmp/healthy
  initialDelaySeconds: 5
  periodSeconds: 5
```

## Multi-Document YAML

Separate multiple resources with `---`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: config
data:
  key: value
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
spec:
  replicas: 3
  # ...
---
apiVersion: v1
kind: Service
metadata:
  name: app
spec:
  # ...
```

## Common Annotations

```yaml
annotations:
  # Ingress
  nginx.ingress.kubernetes.io/rewrite-target: /
  cert-manager.io/cluster-issuer: letsencrypt-prod

  # Prometheus
  prometheus.io/scrape: "true"
  prometheus.io/port: "9090"
  prometheus.io/path: "/metrics"

  # Description
  description: "User-facing API service"

  # Linkerd
  linkerd.io/inject: enabled

  # Istio
  sidecar.istio.io/inject: "true"
```

## Tips

1. **Indentation**: Use 2 spaces (not tabs)
2. **Strings**: Quote special characters: `"true"`, `"123"`
3. **Multi-line**: Use `|` to preserve newlines, `>` to fold
4. **Comments**: Use `#`
5. **Validation**: `kubectl apply --dry-run=client -f file.yaml`
6. **Generate**: `kubectl create ... --dry-run=client -o yaml`

## YAML Gotchas

```yaml
# ❌ Wrong: tabs instead of spaces
	image: nginx

# ✅ Correct: 2 spaces
  image: nginx

# ❌ Wrong: value looks like number but needs to be string
version: 1.2

# ✅ Correct: quote it
version: "1.2"

# ❌ Wrong: unquoted special values
enabled: true    # Becomes boolean
port: "8080"     # String, not number!

# ✅ Correct understanding:
enabled: true    # Boolean
enabled: "true"  # String
port: 8080       # Number
port: "8080"     # String
```

## Useful kubectl for YAML

```bash
# Generate YAML
kubectl create deployment nginx --image=nginx --dry-run=client -o yaml

# Get resource as YAML
kubectl get pod nginx -o yaml

# Explain resource fields
kubectl explain pod.spec
kubectl explain deployment.spec.template.spec.containers

# Validate without applying
kubectl apply --dry-run=client -f file.yaml

# Apply with diff
kubectl diff -f file.yaml
kubectl apply -f file.yaml
```

---

For more: [Kubernetes API Reference](https://kubernetes.io/docs/reference/kubernetes-api/)
