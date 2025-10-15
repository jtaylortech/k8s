# Module 03: Configuration & Storage

**Duration**: ~2 hours
**Prerequisites**: [Module 02: Networking](../02-networking/README.md)
**Next Module**: [04-Workload Management](../04-workload-management/README.md)

## Learning Objectives

By the end of this module, you will:
- ✅ Manage application configuration with ConfigMaps
- ✅ Store sensitive data securely with Secrets
- ✅ Use environment variables in containers
- ✅ Mount configuration as files via volumes
- ✅ Understand persistent storage with PersistentVolumes
- ✅ Use PersistentVolumeClaims for stateful applications

---

## Part 1: ConfigMaps - Application Configuration

**Problem**: Hardcoding configuration in container images is inflexible.

**Solution**: ConfigMaps store non-sensitive configuration data as key-value pairs.

### Creating ConfigMaps

**Method 1: From literals**
```bash
kubectl create configmap app-config \
  --from-literal=APP_NAME=myapp \
  --from-literal=APP_ENV=production \
  --from-literal=LOG_LEVEL=info

# View
kubectl get configmap app-config
kubectl describe configmap app-config
```

**Method 2: From file**
```bash
# Create config file
cat > app.properties <<EOF
database.url=postgres://db:5432/mydb
database.pool.size=10
cache.enabled=true
EOF

kubectl create configmap app-config --from-file=app.properties

# View
kubectl get configmap app-config -o yaml
```

**Method 3: Declarative YAML**

**File**: `configmap.yaml`
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  APP_NAME: myapp
  APP_ENV: production
  LOG_LEVEL: info
  app.properties: |
    database.url=postgres://db:5432/mydb
    database.pool.size=10
    cache.enabled=true
```

```bash
kubectl apply -f configmap.yaml
```

### Using ConfigMaps as Environment Variables

**File**: `deployment-configmap-env.yaml`
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
        env:
        # Single environment variable from ConfigMap
        - name: APP_NAME
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: APP_NAME
        # All keys from ConfigMap as env vars
        envFrom:
        - configMapRef:
            name: app-config
```

```bash
kubectl apply -f deployment-configmap-env.yaml

# Verify environment variables
kubectl exec deploy/web -- env | grep APP
```

### Mounting ConfigMaps as Files

**File**: `deployment-configmap-volume.yaml`
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
        volumeMounts:
        - name: config-volume
          mountPath: /etc/config
      volumes:
      - name: config-volume
        configMap:
          name: app-config
```

```bash
kubectl apply -f deployment-configmap-volume.yaml

# Check mounted files
kubectl exec deploy/web -- ls -la /etc/config
kubectl exec deploy/web -- cat /etc/config/app.properties
```

**Key insight**: ConfigMap updates don't automatically restart pods. Use rolling updates or configuration management tools.

---

## Part 2: Secrets - Sensitive Data

**Secrets** are similar to ConfigMaps but designed for sensitive data (passwords, tokens, keys).

**Important**: Secrets are base64-encoded, NOT encrypted by default. For production, use encryption at rest.

### Creating Secrets

**Method 1: From literals**
```bash
kubectl create secret generic db-credentials \
  --from-literal=username=admin \
  --from-literal=password=super-secret-pass

# View (data is base64-encoded)
kubectl get secret db-credentials -o yaml
```

**Method 2: Declarative**

**File**: `secret.yaml`
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
type: Opaque
data:
  # Base64-encoded values
  username: YWRtaW4=        # echo -n 'admin' | base64
  password: c3VwZXItc2VjcmV0LXBhc3M=  # echo -n 'super-secret-pass' | base64
```

**Or use stringData** (Kubernetes encodes for you):
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
type: Opaque
stringData:
  username: admin
  password: super-secret-pass
```

```bash
kubectl apply -f secret.yaml
```

### Using Secrets as Environment Variables

**File**: `deployment-secret-env.yaml`
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: app
        image: nginx:1.25
        env:
        - name: DB_USERNAME
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: username
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: password
```

```bash
kubectl apply -f deployment-secret-env.yaml

# Verify (be careful in production!)
kubectl exec deploy/app -- env | grep DB
```

### Mounting Secrets as Files

**File**: `deployment-secret-volume.yaml`
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: app
        image: nginx:1.25
        volumeMounts:
        - name: secret-volume
          mountPath: /etc/secrets
          readOnly: true
      volumes:
      - name: secret-volume
        secret:
          secretName: db-credentials
```

```bash
kubectl apply -f deployment-secret-volume.yaml

# Files are created for each key
kubectl exec deploy/app -- ls -la /etc/secrets
kubectl exec deploy/app -- cat /etc/secrets/username
```

### Secret Types

- **Opaque**: Generic key-value pairs (default)
- **kubernetes.io/dockerconfigjson**: Docker registry credentials
- **kubernetes.io/tls**: TLS certificate and key
- **kubernetes.io/service-account-token**: Service account tokens

**Docker registry example**:
```bash
kubectl create secret docker-registry my-registry \
  --docker-server=docker.io \
  --docker-username=myuser \
  --docker-password=mypass \
  --docker-email=me@example.com
```

**TLS secret example**:
```bash
kubectl create secret tls my-tls-cert \
  --cert=path/to/cert.crt \
  --key=path/to/cert.key
```

---

## Part 3: Persistent Storage

Containers are ephemeral—data is lost when they restart. For stateful apps (databases, file storage), we need persistent volumes.

### Volumes vs PersistentVolumes

- **Volume**: Ephemeral, tied to pod lifecycle
- **PersistentVolume (PV)**: Cluster-level storage resource
- **PersistentVolumeClaim (PVC)**: Request for storage by a pod

### EmptyDir - Temporary Storage

Shared between containers in a pod, but deleted when pod dies.

**File**: `pod-emptydir.yaml`
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: shared-storage
spec:
  containers:
  - name: writer
    image: busybox:1.36
    command: ['sh', '-c', 'echo "Hello from writer" > /cache/data.txt; sleep 3600']
    volumeMounts:
    - name: cache-volume
      mountPath: /cache
  - name: reader
    image: busybox:1.36
    command: ['sh', '-c', 'sleep 10; cat /cache/data.txt; sleep 3600']
    volumeMounts:
    - name: cache-volume
      mountPath: /cache
  volumes:
  - name: cache-volume
    emptyDir: {}
```

```bash
kubectl apply -f pod-emptydir.yaml

# Check reader saw writer's data
kubectl logs shared-storage -c reader
# Output: Hello from writer
```

### PersistentVolumeClaim - Persistent Storage

**File**: `pvc.yaml`
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  accessModes:
  - ReadWriteOnce  # Can be mounted read-write by single node
  resources:
    requests:
      storage: 1Gi
```

```bash
kubectl apply -f pvc.yaml

# Check status (should be Bound)
kubectl get pvc
```

**File**: `deployment-pvc.yaml`
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
        volumeMounts:
        - name: data
          mountPath: /usr/share/nginx/html
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: my-pvc
```

```bash
kubectl apply -f deployment-pvc.yaml

# Write data
kubectl exec deploy/web -- sh -c 'echo "Persistent data!" > /usr/share/nginx/html/index.html'

# Delete and recreate pod
kubectl delete pod -l app=web
# Wait for new pod
kubectl wait --for=condition=Ready pod -l app=web

# Data persists!
kubectl exec deploy/web -- cat /usr/share/nginx/html/index.html
```

### Access Modes

- **ReadWriteOnce (RWO)**: Mount by single node
- **ReadOnlyMany (ROX)**: Mount read-only by multiple nodes
- **ReadWriteMany (RWX)**: Mount read-write by multiple nodes

---

## Hands-On Exercises

### Exercise 1: ConfigMap-Driven NGINX Config

Create custom NGINX configuration via ConfigMap.

**File**: `configmap-nginx.yaml`
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
data:
  nginx.conf: |
    server {
      listen 80;
      location / {
        return 200 'Custom NGINX config from ConfigMap!\n';
        add_header Content-Type text/plain;
      }
    }
```

**File**: `deployment-nginx-custom.yaml`
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: custom-nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: custom-nginx
  template:
    metadata:
      labels:
        app: custom-nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        volumeMounts:
        - name: config
          mountPath: /etc/nginx/conf.d/default.conf
          subPath: nginx.conf
      volumes:
      - name: config
        configMap:
          name: nginx-config
```

```bash
kubectl apply -f configmap-nginx.yaml
kubectl apply -f deployment-nginx-custom.yaml

# Test
kubectl port-forward deploy/custom-nginx 8080:80
curl http://localhost:8080
```

### Exercise 2: Multi-Environment Configuration

**File**: `configmap-dev.yaml`
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config-dev
data:
  ENV: development
  DEBUG: "true"
  API_URL: http://api.dev.local
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config-prod
data:
  ENV: production
  DEBUG: "false"
  API_URL: https://api.example.com
```

Deploy with environment-specific config:
```bash
kubectl apply -f configmap-dev.yaml

# Development deployment
kubectl create deployment app-dev --image=nginx:1.25
kubectl set env deployment/app-dev --from=configmap/app-config-dev

# Production deployment
kubectl create deployment app-prod --image=nginx:1.25
kubectl set env deployment/app-prod --from=configmap/app-config-prod

# Verify
kubectl exec deploy/app-dev -- env | grep ENV
kubectl exec deploy/app-prod -- env | grep ENV
```

### Exercise 3: Stateful Application with PVC

Deploy a simple stateful app that persists data:

```bash
# Create PVC
kubectl apply -f pvc.yaml

# Deploy app
kubectl apply -f deployment-pvc.yaml

# Write data
kubectl exec deploy/web -- sh -c 'date > /usr/share/nginx/html/timestamp.txt'

# Scale to 0 and back
kubectl scale deployment web --replicas=0
kubectl scale deployment web --replicas=1
kubectl wait --for=condition=Ready pod -l app=web

# Data persists
kubectl exec deploy/web -- cat /usr/share/nginx/html/timestamp.txt
```

---

## Validation Checklist

Before moving to the next module, ensure you can:

- [ ] Create ConfigMaps from literals, files, and YAML
- [ ] Use ConfigMaps as environment variables
- [ ] Mount ConfigMaps as volumes
- [ ] Create Secrets
- [ ] Use Secrets securely in pods
- [ ] Understand when to use ConfigMaps vs Secrets
- [ ] Create and use PersistentVolumeClaims
- [ ] Understand volume lifecycle

**Self-Test**:
```bash
# Can you do this without looking?
kubectl create configmap test-config --from-literal=key=value
kubectl create secret generic test-secret --from-literal=password=secret
kubectl create deployment test --image=nginx:1.25
kubectl set env deployment/test --from=configmap/test-config
kubectl delete deployment test
```

---

## Best Practices

1. **Never commit secrets to Git** - Use external secret management
2. **Use ConfigMaps for non-sensitive data only**
3. **Enable encryption at rest** for Secrets in production
4. **Use external secret managers** (Vault, AWS Secrets Manager, etc.)
5. **Immutable ConfigMaps/Secrets** - Create new ones instead of updating
6. **Set resource requests** on PVCs to match storage needs
7. **Use separate ConfigMaps** per environment

---

## Common Pitfalls

### ConfigMap/Secret not found
**Cause**: Referenced before creation
**Fix**: Ensure ConfigMap/Secret exists before deploying pods

### Pod not updating after ConfigMap change
**Cause**: ConfigMap updates don't restart pods automatically
**Fix**: Restart pods manually or use Deployment annotations to trigger rolling update

### PVC stuck in Pending
**Cause**: No available PersistentVolume or StorageClass
**Fix**: Check `kubectl describe pvc <name>` for events

---

## Key Takeaways

1. **ConfigMaps** store non-sensitive configuration
2. **Secrets** store sensitive data (base64-encoded, not encrypted)
3. Both can be used as **environment variables** or **mounted as files**
4. **PersistentVolumeClaims** provide persistent storage
5. Use **external secret management** in production

---

## Additional Resources

- [ConfigMaps Documentation](https://kubernetes.io/docs/concepts/configuration/configmap/)
- [Secrets Documentation](https://kubernetes.io/docs/concepts/configuration/secret/)
- [Volumes Documentation](https://kubernetes.io/docs/concepts/storage/volumes/)
- [PersistentVolumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)

---

## Next Steps

Ready to manage workloads? → [Module 04: Workload Management](../04-workload-management/README.md)

---

**Clean up**:
```bash
kubectl delete deployment --all
kubectl delete configmap --all
kubectl delete secret db-credentials
kubectl delete pvc --all
```
