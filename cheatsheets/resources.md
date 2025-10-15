# Kubernetes Resource Limits Cheat Sheet

Guide to setting appropriate resource requests and limits.

## Understanding Requests vs Limits

| | Requests | Limits |
|---|----------|--------|
| **Purpose** | Guaranteed resources | Maximum resources |
| **Scheduling** | Used by scheduler to place pods | Not used for scheduling |
| **Behavior** | Always available | Throttled (CPU) or killed (memory) if exceeded |
| **Best Practice** | Set based on actual usage | Set based on maximum acceptable |

```yaml
resources:
  requests:      # Scheduler guarantees this much
    cpu: 100m
    memory: 128Mi
  limits:        # Container can't exceed this
    cpu: 200m
    memory: 256Mi
```

---

## CPU

### Units

- `1` or `1000m` = 1 CPU core
- `500m` = 0.5 CPU core (50% of one core)
- `100m` = 0.1 CPU core (10% of one core)

### Behavior

- **Throttling**: If container exceeds limit, it's throttled (slowed down)
- **Never killed**: Exceeding CPU limit doesn't kill the container

### Recommendations

| Application Type | Request | Limit | Reasoning |
|------------------|---------|-------|-----------|
| **Web API (low traffic)** | 100m | 500m | Burst capacity for spikes |
| **Web API (high traffic)** | 500m | 1000m | Higher baseline, room to burst |
| **Background worker** | 100m | 200m | Consistent load |
| **Batch job** | 500m | 2000m | Can use full core when available |
| **Database** | 1000m | 2000m | Needs consistent performance |
| **Microservice** | 100m | 300m | Small, efficient |

### Example

```yaml
# Light web service
resources:
  requests:
    cpu: 100m    # Guaranteed 10% of a core
  limits:
    cpu: 500m    # Can burst to 50% of a core

# Database
resources:
  requests:
    cpu: 1000m   # Guaranteed 1 full core
  limits:
    cpu: 2000m   # Can use up to 2 cores
```

---

## Memory

### Units

- `Mi` = Mebibytes (1024² bytes)
- `Gi` = Gibibytes (1024³ bytes)
- `M` = Megabytes (1000² bytes) - less common
- `G` = Gigabytes (1000³ bytes) - less common

**Use Mi/Gi** for predictability.

### Behavior

- **OOMKilled**: If container exceeds limit, it's killed and restarted
- **No throttling**: Unlike CPU, memory can't be throttled

### Recommendations

| Application Type | Request | Limit | Reasoning |
|------------------|---------|-------|-----------|
| **Web API (Node.js)** | 128Mi | 256Mi | Node typically lightweight |
| **Web API (Java)** | 512Mi | 1Gi | JVM overhead |
| **Web API (Go)** | 64Mi | 128Mi | Go is efficient |
| **Background worker** | 128Mi | 256Mi | Depends on task |
| **Database (PostgreSQL)** | 1Gi | 2Gi | Needs memory for cache |
| **Redis cache** | 512Mi | 1Gi | In-memory store |
| **Frontend (nginx)** | 32Mi | 64Mi | Static files |

### Example

```yaml
# Node.js API
resources:
  requests:
    memory: 128Mi
  limits:
    memory: 256Mi

# Java application
resources:
  requests:
    memory: 512Mi
  limits:
    memory: 1Gi
```

---

## Quality of Service (QoS) Classes

Kubernetes assigns QoS based on your resource settings:

### Guaranteed (Highest Priority)

**Condition**: requests = limits for all resources

```yaml
resources:
  requests:
    cpu: 500m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 256Mi
```

**When to use**:
- Critical services (databases, APIs)
- Production workloads
- When predictable performance is essential

### Burstable (Medium Priority)

**Condition**: requests < limits OR only requests specified

```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

**When to use**:
- Web services with variable load
- Most applications
- Default choice for most workloads

### BestEffort (Lowest Priority)

**Condition**: No requests or limits specified

```yaml
# No resources section
```

**When to use**:
- Non-critical batch jobs
- Development/testing
- When you don't know resource needs yet

**Eviction order**: BestEffort → Burstable → Guaranteed

---

## Sizing Guidelines

### Step 1: Measure Actual Usage

```bash
# Deploy without limits
kubectl apply -f deployment.yaml

# Monitor for 1-7 days
kubectl top pod <pod-name>

# Get detailed metrics (if Prometheus installed)
# Look at CPU and memory usage percentiles:
# - p50 (median)
# - p95 (95th percentile)
# - p99 (99th percentile)
```

### Step 2: Set Initial Values

**Formula**:
- **Request** = p95 of actual usage
- **Limit** = p99 × 1.5 (with headroom)

**Example**:
```
Observed:
- CPU: p50 = 50m, p95 = 150m, p99 = 200m
- Memory: p50 = 64Mi, p95 = 128Mi, p99 = 180Mi

Set:
  requests:
    cpu: 150m      # p95
    memory: 128Mi  # p95
  limits:
    cpu: 300m      # p99 × 1.5
    memory: 270Mi  # p99 × 1.5
```

### Step 3: Adjust Based on Behavior

Monitor for:
- **OOMKilled pods** → Increase memory limit
- **CPU throttling** → Increase CPU limit
- **Pod evictions** → Increase requests

---

## Common Patterns

### Pattern 1: Web Service (Variable Load)

```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m       # Can burst 5x
    memory: 256Mi   # Can use 2x
```

### Pattern 2: Database (Predictable)

```yaml
resources:
  requests:
    cpu: 1000m
    memory: 2Gi
  limits:
    cpu: 1000m      # Same = Guaranteed QoS
    memory: 2Gi
```

### Pattern 3: Batch Job (Can Use Excess)

```yaml
resources:
  requests:
    cpu: 100m       # Small guarantee
    memory: 256Mi
  limits:
    cpu: 4000m      # Can use 4 cores if available
    memory: 4Gi
```

### Pattern 4: Sidecar (Minimal)

```yaml
resources:
  requests:
    cpu: 10m        # Very light
    memory: 16Mi
  limits:
    cpu: 50m
    memory: 64Mi
```

---

## Namespace ResourceQuotas

Limit total resources in a namespace:

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
  namespace: development
spec:
  hard:
    requests.cpu: "10"       # 10 cores total
    requests.memory: 20Gi    # 20 GB total
    limits.cpu: "20"         # 20 cores max
    limits.memory: 40Gi      # 40 GB max
    pods: "50"               # Max 50 pods
```

Check quota usage:
```bash
kubectl describe resourcequota -n development
```

---

## LimitRange (Default Values)

Set default and max/min for namespace:

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: development
spec:
  limits:
  - default:               # Default limits
      cpu: 500m
      memory: 512Mi
    defaultRequest:        # Default requests
      cpu: 100m
      memory: 128Mi
    max:                   # Maximum allowed
      cpu: 2000m
      memory: 4Gi
    min:                   # Minimum required
      cpu: 10m
      memory: 16Mi
    type: Container
```

---

## Monitoring Resource Usage

### kubectl top

```bash
# Node usage
kubectl top nodes

# Pod usage
kubectl top pods
kubectl top pods -n production
kubectl top pods --containers  # Per-container

# Sort by CPU
kubectl top pods --sort-by=cpu

# Sort by memory
kubectl top pods --sort-by=memory
```

### Prometheus Queries

```promql
# CPU usage by pod
sum(rate(container_cpu_usage_seconds_total[5m])) by (pod)

# Memory usage by pod
sum(container_memory_working_set_bytes) by (pod)

# CPU throttling (should be low)
sum(rate(container_cpu_cfs_throttled_seconds_total[5m])) by (pod)

# Memory limit vs usage
sum(container_memory_usage_bytes) by (pod) /
sum(container_spec_memory_limit_bytes) by (pod)
```

---

## Troubleshooting

### OOMKilled Pods

**Symptom**: Pod restarted, Last State shows OOMKilled

```bash
kubectl describe pod <pod-name>
# Look for: Last State: Terminated, Reason: OOMKilled
```

**Solution**:
```yaml
# Increase memory limit
resources:
  limits:
    memory: 512Mi  # Was 256Mi
```

### CPU Throttling

**Symptom**: Application slow, high CPU throttling metric

```bash
# Check throttling (Prometheus)
sum(rate(container_cpu_cfs_throttled_seconds_total[5m])) by (pod)
```

**Solution**:
```yaml
# Increase CPU limit
resources:
  limits:
    cpu: 1000m  # Was 500m
```

### Pod Evicted

**Symptom**: Pod shows Evicted status

```bash
kubectl get pods
# STATUS: Evicted
```

**Reasons**:
1. Node out of resources
2. Pod exceeded requests
3. BestEffort/Burstable evicted first

**Solution**:
```yaml
# Set requests higher or make Guaranteed QoS
resources:
  requests:
    cpu: 200m      # Was 100m
    memory: 256Mi  # Was 128Mi
  limits:
    cpu: 200m      # Same = Guaranteed
    memory: 256Mi
```

---

## Best Practices

1. **Always set requests**: Scheduler needs them
2. **Set limits**: Prevent resource exhaustion
3. **Monitor before tuning**: Use actual data
4. **Start conservative**: It's easier to increase than decrease
5. **Use Guaranteed QoS for critical workloads**
6. **Test under load**: Stress test to find limits
7. **Set ResourceQuotas**: Prevent namespace resource hogging
8. **Use HPA**: Auto-scale instead of over-provisioning

---

## Quick Reference

### Minimal (Sidecar)
```yaml
requests: { cpu: 10m, memory: 16Mi }
limits: { cpu: 50m, memory: 64Mi }
```

### Small (Frontend/Static)
```yaml
requests: { cpu: 50m, memory: 64Mi }
limits: { cpu: 200m, memory: 128Mi }
```

### Medium (API/Service)
```yaml
requests: { cpu: 100m, memory: 128Mi }
limits: { cpu: 500m, memory: 256Mi }
```

### Large (Java/Heavy App)
```yaml
requests: { cpu: 500m, memory: 512Mi }
limits: { cpu: 1000m, memory: 1Gi }
```

### Database
```yaml
requests: { cpu: 1000m, memory: 2Gi }
limits: { cpu: 1000m, memory: 2Gi }  # Guaranteed
```

---

## Further Reading

- [Managing Resources for Containers](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- [Resource Quotas](https://kubernetes.io/docs/concepts/policy/resource-quotas/)
- [Limit Ranges](https://kubernetes.io/docs/concepts/policy/limit-range/)
- [Configure Quality of Service](https://kubernetes.io/docs/tasks/configure-pod-container/quality-service-pod/)
