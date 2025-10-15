# Kubernetes Troubleshooting Guide

Comprehensive guide to diagnosing and fixing common Kubernetes issues.

## Quick Diagnostic Commands

```bash
# Overall cluster health
kubectl get nodes
kubectl get pods --all-namespaces
kubectl get componentstatuses  # Deprecated but useful

# Check events (often shows root cause)
kubectl get events --sort-by='.lastTimestamp'
kubectl get events -n <namespace>

# Resource usage
kubectl top nodes
kubectl top pods -A
```

---

## Pod Issues

### Pod Stuck in Pending

**Symptoms**: Pod shows `Pending` status indefinitely

**Common Causes**:
1. Insufficient cluster resources
2. PersistentVolumeClaim not bound
3. Node selector doesn't match any node
4. Taints preventing scheduling

**Debug**:
```bash
# Check why pod isn't scheduled
kubectl describe pod <pod-name>
# Look at Events section at bottom

# Check node resources
kubectl top nodes
kubectl describe nodes

# Check PVC status
kubectl get pvc
```

**Solutions**:
```bash
# If insufficient resources: scale down or add nodes
kubectl scale deployment <name> --replicas=1

# If PVC issue: check PV availability
kubectl get pv

# If node selector issue: fix or remove
kubectl edit pod <pod-name>
```

### Pod Stuck in CrashLoopBackOff

**Symptoms**: Pod continuously crashes and restarts

**Common Causes**:
1. Application error
2. Missing dependencies (ConfigMap, Secret)
3. Liveness probe too aggressive
4. Insufficient resources

**Debug**:
```bash
# Check logs
kubectl logs <pod-name>
kubectl logs <pod-name> --previous  # Before last crash

# Describe pod
kubectl describe pod <pod-name>
# Check: Restart Count, Last State, Events

# Check resource limits
kubectl get pod <pod-name> -o yaml | grep -A 5 resources
```

**Solutions**:
```bash
# Fix application code based on logs

# If missing ConfigMap/Secret:
kubectl get configmap
kubectl get secret

# If liveness probe issue, temporarily disable:
kubectl edit deployment <name>
# Comment out livenessProbe section

# If OOMKilled (out of memory):
kubectl set resources deployment/<name> --limits=memory=512Mi
```

### ImagePullBackOff / ErrImagePull

**Symptoms**: Cannot pull container image

**Common Causes**:
1. Image doesn't exist
2. Image name typo
3. Private registry auth missing
4. Network issues

**Debug**:
```bash
kubectl describe pod <pod-name>
# Look for: Failed to pull image, image not found

# Check image name
kubectl get pod <pod-name> -o jsonpath='{.spec.containers[*].image}'

# Check secrets
kubectl get secrets
```

**Solutions**:
```bash
# Fix image name
kubectl set image deployment/<name> <container>=<correct-image>

# Create pull secret for private registry
kubectl create secret docker-registry regcred \
  --docker-server=<registry> \
  --docker-username=<user> \
  --docker-password=<password>

# Use secret in pod
kubectl edit deployment <name>
# Add: spec.template.spec.imagePullSecrets: [{name: regcred}]
```

### Pod Not Ready (0/1)

**Symptoms**: Pod Running but not Ready

**Common Cause**: Readiness probe failing

**Debug**:
```bash
kubectl describe pod <pod-name>
# Check: Readiness probe failed, Events

kubectl logs <pod-name>
# Check application logs
```

**Solutions**:
```bash
# Fix application issue causing probe failure

# Adjust probe settings
kubectl edit deployment <name>
# Increase: initialDelaySeconds, periodSeconds

# Test probe manually
kubectl exec <pod-name> -- curl localhost/health
```

---

## Service / Networking Issues

### Can't Reach Service

**Symptoms**: Service not responding, connection refused

**Debug**:
```bash
# 1. Check service exists
kubectl get svc <service-name>

# 2. Check service has endpoints
kubectl get endpoints <service-name>
# If empty, selector doesn't match pods

# 3. Check pod labels
kubectl get pods --show-labels

# 4. Check pods are ready
kubectl get pods -l app=<label>

# 5. Test from another pod
kubectl run test --rm -it --image=busybox:1.36 -- sh
wget -qO- http://<service-name>
```

**Solutions**:
```bash
# Fix selector
kubectl edit service <service-name>
# Update spec.selector to match pod labels

# Check target port matches container port
kubectl describe service <service-name>
kubectl describe pod <pod-name>

# If NetworkPolicy blocks traffic:
kubectl get networkpolicy
kubectl describe networkpolicy <name>
```

### Ingress Returns 404

**Symptoms**: Ingress controller responds but returns 404

**Debug**:
```bash
# 1. Check Ingress resource
kubectl get ingress
kubectl describe ingress <name>

# 2. Check backend service exists
kubectl get svc <backend-service>

# 3. Check ingress controller logs
kubectl -n ingress-nginx logs deploy/ingress-nginx-controller

# 4. Test with curl
curl -v -H "Host: <hostname>" http://127.0.0.1/
```

**Solutions**:
```bash
# Fix Ingress rules
kubectl edit ingress <name>

# Check ingressClassName
kubectl get ingressclass

# Reinstall ingress controller if needed
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx
```

### DNS Not Resolving

**Symptoms**: Service name doesn't resolve

**Debug**:
```bash
# 1. Check CoreDNS is running
kubectl -n kube-system get pods -l k8s-app=kube-dns

# 2. Check CoreDNS logs
kubectl -n kube-system logs -l k8s-app=kube-dns

# 3. Test from pod
kubectl run test --rm -it --image=busybox:1.36 -- sh
nslookup kubernetes.default
nslookup <service-name>
```

**Solutions**:
```bash
# Restart CoreDNS
kubectl -n kube-system rollout restart deployment/coredns

# Check DNS config
kubectl -n kube-system get configmap coredns -o yaml

# Use fully qualified name
<service>.<namespace>.svc.cluster.local
```

---

## Persistent Storage Issues

### PVC Stuck in Pending

**Symptoms**: PersistentVolumeClaim never binds

**Debug**:
```bash
kubectl get pvc
kubectl describe pvc <name>
# Look for events

kubectl get pv
# Check if any available PVs match PVC requirements
```

**Solutions**:
```bash
# If no StorageClass and no matching PV:
# 1. Create PV manually (for local)
# 2. Install storage provisioner
# 3. Create StorageClass

# For dynamic provisioning (cloud):
kubectl get storageclass

# Change PVC to use existing StorageClass
kubectl edit pvc <name>
```

### Pod Can't Mount Volume

**Symptoms**: Pod can't start, volume mount errors

**Debug**:
```bash
kubectl describe pod <pod-name>
# Look for: FailedMount, unable to mount volumes

kubectl get pvc
kubectl describe pvc <pvc-name>
```

**Solutions**:
```bash
# Ensure PVC is bound
kubectl get pvc

# Check accessMode compatibility
# RWO: Single node only
# ROX: Multiple nodes, read-only
# RWX: Multiple nodes, read-write
```

---

## Resource / Performance Issues

### Pod Evicted (OOMKilled)

**Symptoms**: Pod killed due to out-of-memory

**Debug**:
```bash
kubectl describe pod <pod-name>
# Reason: OOMKilled

kubectl top pod <pod-name>
# Check memory usage

kubectl get pod <pod-name> -o yaml | grep -A 5 resources
```

**Solutions**:
```bash
# Increase memory limits
kubectl set resources deployment/<name> \
  --limits=memory=1Gi \
  --requests=memory=512Mi

# Or edit YAML
kubectl edit deployment <name>
```

### High CPU Throttling

**Symptoms**: Application slow, high CPU throttling

**Debug**:
```bash
kubectl top pods
kubectl describe pod <pod-name>
```

**Solutions**:
```bash
# Increase CPU limits
kubectl set resources deployment/<name> \
  --limits=cpu=1000m \
  --requests=cpu=500m
```

### Node Pressure (Disk/Memory)

**Symptoms**: Pods evicted, node marked NotReady

**Debug**:
```bash
kubectl get nodes
kubectl describe node <node-name>
# Look for: MemoryPressure, DiskPressure

kubectl top nodes
```

**Solutions**:
```bash
# Clean up disk space
docker system prune -a

# Add more nodes
# Scale down workloads

# Increase node resources (cloud)
```

---

## Application Issues

### ConfigMap / Secret Not Loading

**Symptoms**: Environment variables or files missing

**Debug**:
```bash
# Check ConfigMap/Secret exists
kubectl get configmap <name>
kubectl get secret <name>

# Check pod references correct name
kubectl get pod <pod-name> -o yaml | grep -A 5 configMap

# Check environment variables
kubectl exec <pod-name> -- env
```

**Solutions**:
```bash
# Create missing ConfigMap/Secret
kubectl apply -f configmap.yaml

# Fix reference in deployment
kubectl edit deployment <name>

# Restart pods to pick up changes
kubectl rollout restart deployment <name>
```

### Liveness Probe Failing

**Symptoms**: Pod keeps restarting due to failed probe

**Debug**:
```bash
kubectl describe pod <pod-name>
# Liveness probe failed: HTTP probe failed

kubectl logs <pod-name>
```

**Solutions**:
```bash
# Test probe endpoint manually
kubectl exec <pod-name> -- curl -f http://localhost:8080/health

# Adjust probe timing
kubectl edit deployment <name>
# Increase: initialDelaySeconds, timeoutSeconds
```

---

## Cluster Issues

### Node NotReady

**Symptoms**: Node shows NotReady status

**Debug**:
```bash
kubectl get nodes
kubectl describe node <node-name>
# Look for conditions: Ready=False

# SSH to node (if possible) and check:
systemctl status kubelet
journalctl -u kubelet
```

**Solutions**:
```bash
# Restart kubelet (on node)
systemctl restart kubelet

# Check node resources
kubectl describe node <node-name>

# Drain and remove problematic node
kubectl drain <node-name> --ignore-daemonsets
kubectl delete node <node-name>
```

### API Server Unreachable

**Symptoms**: kubectl commands timeout

**Debug**:
```bash
# Check kubeconfig
kubectl config view

# Check context
kubectl config current-context

# Verify API server running (for local clusters)
docker ps | grep kube-apiserver  # Docker Desktop
kind get clusters                 # kind
```

**Solutions**:
```bash
# Switch to correct context
kubectl config use-context <context>

# Restart cluster (Docker Desktop)
# Docker Desktop → Restart

# Recreate cluster (kind)
kind delete cluster
kind create cluster
```

---

## Troubleshooting Workflow

```
1. Get high-level view
   kubectl get pods
   kubectl get nodes
   kubectl get events

2. Describe resource
   kubectl describe pod <name>
   → Check Events section

3. Check logs
   kubectl logs <pod-name>
   kubectl logs <pod-name> --previous

4. Test connectivity
   kubectl run test --rm -it --image=busybox -- sh
   → wget, nslookup, curl

5. Check configs
   kubectl get configmap
   kubectl get secret
   kubectl get svc
   kubectl get endpoints

6. Resource usage
   kubectl top nodes
   kubectl top pods
```

---

## Useful Tools

### kubectl plugins

```bash
# Install krew (plugin manager)
brew install krew

# Useful plugins
kubectl krew install ctx       # Switch contexts
kubectl krew install ns        # Switch namespaces
kubectl krew install tail      # Tail logs
kubectl krew install tree      # Resource tree view
```

### k9s

Interactive terminal UI:
```bash
brew install k9s
k9s
```

### stern

Multi-pod log tailing:
```bash
brew install stern
stern <pod-pattern>
```

---

## Additional Resources

- [Official Debugging Guide](https://kubernetes.io/docs/tasks/debug/)
- [Troubleshooting Applications](https://kubernetes.io/docs/tasks/debug/debug-application/)
- [Troubleshooting Clusters](https://kubernetes.io/docs/tasks/debug/debug-cluster/)
- [Debug Running Pods](https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/)

---

## Quick Fixes

```bash
# Force delete stuck pod
kubectl delete pod <name> --grace-period=0 --force

# Restart all pods in deployment
kubectl rollout restart deployment <name>

# Scale to 0 and back
kubectl scale deployment <name> --replicas=0
kubectl scale deployment <name> --replicas=3

# Clear failed pods
kubectl delete pods --field-selector=status.phase=Failed -A

# Reset cluster (Docker Desktop)
# Settings → Kubernetes → Reset Kubernetes Cluster
```
