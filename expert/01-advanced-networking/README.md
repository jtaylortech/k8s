# Module 01: Advanced Networking

**Duration**: ~6 hours
**Prerequisites**: Beginner track complete, experience with Services and Ingress
**Next Module**: [02-Advanced Security](../02-advanced-security/README.md)

## Learning Objectives

By the end of this module, you will:
- ✅ Understand CNI (Container Network Interface) architecture
- ✅ Deploy and configure Calico or Cilium
- ✅ Implement advanced NetworkPolicy patterns
- ✅ Understand service mesh fundamentals
- ✅ Configure cross-namespace and egress policies
- ✅ Debug network issues at a deep level
- ✅ Optimize network performance

---

## Part 1: CNI Deep Dive

### What is CNI?

CNI (Container Network Interface) is a specification for configuring network interfaces in Linux containers. When a pod is created, the CNI plugin:

1. Creates a network namespace for the pod
2. Assigns an IP address
3. Sets up routes and iptables rules
4. Configures network policies

### Popular CNI Plugins

| Plugin | Features | Best For |
|--------|----------|----------|
| **Calico** | Layer 3, BGP routing, rich NetworkPolicy | Enterprise, policy-heavy |
| **Cilium** | eBPF-based, L7 policies, service mesh | Modern, performance-critical |
| **Flannel** | Simple overlay, easy setup | Small clusters, learning |
| **Weave** | Encryption, multi-cloud | Security-focused |
| **AWS VPC CNI** | Native VPC networking | AWS EKS |

### Installing Calico

```bash
# For kind cluster with Calico
cat <<EOF | kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  disableDefaultCNI: true  # Don't install kindnet
  podSubnet: 192.168.0.0/16
nodes:
- role: control-plane
- role: worker
- role: worker
EOF

# Install Calico
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/tigera-operator.yaml

# Wait for operator
kubectl wait --for=condition=Available --timeout=300s \
  deployment/tigera-operator -n tigera-operator

# Install Calico custom resources
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/custom-resources.yaml

# Verify
kubectl get pods -n calico-system
watch kubectl get pods -n calico-system
```

### Installing Cilium (Alternative)

```bash
# Install Cilium CLI
curl -L --remote-name-all https://github.com/cilium/cilium-cli/releases/latest/download/cilium-linux-amd64.tar.gz
sudo tar xzvfC cilium-linux-amd64.tar.gz /usr/local/bin

# Create cluster
kind create cluster --config kind-config.yaml

# Install Cilium
cilium install

# Verify
cilium status
kubectl get pods -n kube-system -l k8s-app=cilium
```

---

## Part 2: Advanced NetworkPolicy Patterns

### Understanding NetworkPolicy

NetworkPolicies control traffic at Layer 3/4 (IP/Port). Without policies, all pods can communicate (default allow).

### Pattern 1: Default Deny All

**Best practice**: Start with deny-all, then allow specific traffic.

**File**: `networkpolicy-default-deny.yaml`
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}  # Applies to all pods
  policyTypes:
  - Ingress
  - Egress
```

```bash
kubectl create namespace production
kubectl apply -f networkpolicy-default-deny.yaml

# Now all ingress/egress blocked in that namespace
```

### Pattern 2: Allow Specific Ingress

Allow only Ingress controller to reach web pods:

**File**: `networkpolicy-allow-ingress.yaml`
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: web-allow-ingress
  namespace: production
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

### Pattern 3: Allow DNS

Always allow DNS queries to CoreDNS:

**File**: `networkpolicy-allow-dns.yaml`
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
    ports:
    - protocol: UDP
      port: 53
```

### Pattern 4: Multi-Tier Application

**File**: `networkpolicy-multi-tier.yaml`
```yaml
---
# Frontend can receive from ingress
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend
  namespace: production
spec:
  podSelector:
    matchLabels:
      tier: frontend
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: ingress-nginx
  egress:
  - to:
    - podSelector:
        matchLabels:
          tier: backend
    ports:
    - protocol: TCP
      port: 8080
---
# Backend can receive from frontend
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend
  namespace: production
spec:
  podSelector:
    matchLabels:
      tier: backend
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: frontend
  egress:
  - to:
    - podSelector:
        matchLabels:
          tier: database
    ports:
    - protocol: TCP
      port: 5432
---
# Database only accepts from backend
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: database
  namespace: production
spec:
  podSelector:
    matchLabels:
      tier: database
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: backend
    ports:
    - protocol: TCP
      port: 5432
```

### Pattern 5: Egress Control

Control external traffic (e.g., only allow specific external APIs):

**File**: `networkpolicy-egress.yaml`
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-external-api
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: worker
  policyTypes:
  - Egress
  egress:
  # Allow DNS
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
    ports:
    - protocol: UDP
      port: 53
  # Allow specific external CIDR
  - to:
    - ipBlock:
        cidr: 203.0.113.0/24  # External API CIDR
    ports:
    - protocol: TCP
      port: 443
```

---

## Part 3: Calico Advanced Features

### Global NetworkPolicies

Apply policies cluster-wide (Calico-specific):

**File**: `globalnetworkpolicy.yaml`
```yaml
apiVersion: projectcalico.org/v3
kind: GlobalNetworkPolicy
metadata:
  name: deny-all-external
spec:
  selector: all()
  types:
  - Egress
  egress:
  # Allow internal cluster communication
  - action: Allow
    destination:
      nets:
      - 10.0.0.0/8
      - 172.16.0.0/12
      - 192.168.0.0/16
  # Allow DNS
  - action: Allow
    protocol: UDP
    destination:
      ports:
      - 53
  # Deny everything else
  - action: Deny
```

### Layer 7 Policies (Cilium)

Cilium supports HTTP/gRPC-level policies:

**File**: `cilium-l7-policy.yaml`
```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: api-l7-policy
spec:
  endpointSelector:
    matchLabels:
      app: api
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: frontend
    toPorts:
    - ports:
      - port: "80"
        protocol: TCP
      rules:
        http:
        - method: "GET"
          path: "/api/users"
        - method: "POST"
          path: "/api/users"
```

---

## Part 4: Service Mesh Fundamentals

### Why Service Mesh?

NetworkPolicies operate at L3/4. For advanced needs:
- mTLS between services
- Retry policies, circuit breakers
- Traffic splitting (canary deployments)
- Distributed tracing
- L7 policy (HTTP method, path)

**Solution**: Service mesh (Istio, Linkerd, Cilium Service Mesh)

### Linkerd (Lightweight)

```bash
# Install Linkerd CLI
curl -sL https://run.linkerd.io/install | sh

# Install Linkerd on cluster
linkerd install | kubectl apply -f -

# Verify
linkerd check

# Inject sidecar into namespace
kubectl annotate namespace production linkerd.io/inject=enabled

# Redeploy pods to get sidecar
kubectl rollout restart deployment -n production

# View service graph
linkerd viz install | kubectl apply -f -
linkerd viz dashboard
```

### Istio (Full-featured)

```bash
# Install Istio CLI
curl -L https://istio.io/downloadIstio | sh -

# Install Istio
istioctl install --set profile=demo -y

# Label namespace for injection
kubectl label namespace production istio-injection=enabled

# Deploy app
kubectl apply -f app.yaml -n production

# Check sidecars
kubectl get pods -n production
# Should see 2/2 containers per pod
```

### Service Mesh Features

**mTLS**:
```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: production
spec:
  mtls:
    mode: STRICT
```

**Traffic splitting (Canary)**:
```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: web
spec:
  hosts:
  - web
  http:
  - match:
    - headers:
        canary:
          exact: "true"
    route:
    - destination:
        host: web
        subset: v2
  - route:
    - destination:
        host: web
        subset: v1
      weight: 90
    - destination:
        host: web
        subset: v2
      weight: 10
```

---

## Part 5: Network Debugging

### Tools

**1. calicoctl** (for Calico):
```bash
kubectl exec -it <calico-pod> -n calico-system -- calicoctl get nodes
kubectl exec -it <calico-pod> -n calico-system -- calicoctl get workloadEndpoints
```

**2. Cilium CLI**:
```bash
cilium connectivity test
cilium monitor
```

**3. tcpdump in pod**:
```bash
kubectl run tcpdump --rm -it --image=nicolaka/netshoot -- /bin/bash
tcpdump -i any -n port 80
```

### Debugging NetworkPolicy

```bash
# Check if policies exist
kubectl get networkpolicy -A

# Describe policy
kubectl describe networkpolicy <name> -n <namespace>

# Test connectivity
kubectl run test --rm -it --image=busybox:1.36 -n production -- sh
wget -qO- http://web-service

# If blocked, check:
# 1. Pod labels match policy selectors
kubectl get pods --show-labels

# 2. Policy allows traffic
kubectl describe networkpolicy <name>

# 3. Enable Calico logging (if using Calico)
kubectl exec -it <calico-pod> -n calico-system -- calicoctl node status
```

---

## Hands-On Exercise: Secure Multi-Tier App

Deploy a complete app with NetworkPolicies:

```bash
# 1. Create namespace
kubectl create namespace secure-app
kubectl label namespace secure-app environment=production

# 2. Apply default deny
kubectl apply -f networkpolicy-default-deny.yaml

# 3. Deploy tiers
kubectl apply -f frontend-deployment.yaml
kubectl apply -f backend-deployment.yaml
kubectl apply -f database-statefulset.yaml

# 4. Apply tier policies
kubectl apply -f networkpolicy-multi-tier.yaml

# 5. Test connectivity
kubectl run test -it --rm --image=busybox -n secure-app -- sh
wget -qO- http://frontend  # Should work from ingress
wget -qO- http://backend   # Should fail (not allowed)
```

---

## Performance Considerations

### eBPF vs iptables

- **iptables**: Linear performance degradation (1000s of rules = slow)
- **eBPF**: Constant time lookups, 10-100x faster

**Switch to eBPF** (if using Cilium):
```bash
cilium install --set kubeProxyReplacement=strict
```

### NetworkPolicy Best Practices

1. **Start with default deny** at namespace level
2. **Allow DNS** explicitly
3. **Use podSelector** over namespaceSelector when possible (more specific)
4. **Test policies** before applying to production
5. **Monitor denials** with Calico/Cilium logs

---

## Validation Checklist

- [ ] Understand CNI architecture
- [ ] Install and configure Calico or Cilium
- [ ] Create default deny NetworkPolicy
- [ ] Implement multi-tier NetworkPolicies
- [ ] Configure egress policies
- [ ] Debug NetworkPolicy issues
- [ ] Understand service mesh fundamentals
- [ ] Deploy Linkerd or Istio
- [ ] Configure mTLS

---

## Key Takeaways

1. **CNI plugins** handle pod networking
2. **NetworkPolicies** are firewall rules for pods
3. **Default deny** is security best practice
4. **Service meshes** add L7 capabilities and mTLS
5. **eBPF** offers superior performance over iptables
6. **Debugging** requires understanding of policy selectors and labels

---

## Additional Resources

- [Calico Documentation](https://docs.projectcalico.org/)
- [Cilium Documentation](https://docs.cilium.io/)
- [Istio Documentation](https://istio.io/latest/docs/)
- [Linkerd Documentation](https://linkerd.io/2/overview/)
- [NetworkPolicy Recipes](https://github.com/ahmetb/kubernetes-network-policy-recipes)

---

## Next Steps

Ready for security? → [Module 02: Advanced Security](../02-advanced-security/README.md)

Want to practice?
- Implement zero-trust networking in your cluster
- Deploy a service mesh and observe traffic
- Create custom GlobalNetworkPolicies
