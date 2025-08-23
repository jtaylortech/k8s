# 0) Pre-reqs (install + why)

-   **Docker Desktop** with **Kubernetes enabled**: single-node K8s + kubeconfig, zero VM friction. Enable via Docker Desktop → Settings → Kubernetes → “Enable Kubernetes” → Apply & restart. [Docker Documentation](https://docs.docker.com/desktop/features/kubernetes/?utm_source=chatgpt.com)[Docker](https://www.docker.com/blog/how-to-set-up-a-kubernetes-cluster-on-docker-desktop/?utm_source=chatgpt.com)
    
-   **kubectl** and **Helm** CLIs installed (brew/choco/etc.). Helm manages app lifecycles declaratively.
    
-   Confirm cluster is up:
`kubectl get nodes` 

# 1) Mental model (state this upfront)

“Cluster → Controller → Workload → Service → Ingress → TLS/Obs/Security.”  
Ingress is just config; it **requires a controller**. We’ll use **ingress-nginx**. [Kubernetes+1](https://kubernetes.io/docs/concepts/services-networking/ingress/?utm_source=chatgpt.com)

# 2) Install the Ingress controller (ingress-nginx)

**Why now:** Ingress objects are inert without a controller; set edge first so apps are trivially exposable.

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace
kubectl -n ingress-nginx get pods,svc
```

Chart reference + config knobs. [Artifact Hub](https://artifacthub.io/packages/helm/ingress-nginx/ingress-nginx?utm_source=chatgpt.com)[kubernetes.github.io](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/?utm_source=chatgpt.com)[GitHub](https://github.com/kubernetes/ingress-nginx?utm_source=chatgpt.com)

# 3) Deploy a real app with Helm (Bitnami NGINX)

**What you’re deploying:** a web server (NGINX) as a Deployment + Service; optional Ingress via values. [GitHub](https://github.com/bitnami/charts/blob/master/bitnami/nginx/Chart.yaml?utm_source=chatgpt.com)  
**Why Bitnami:** well-maintained, parameterized chart—great for showing Helm upgrades/rollbacks. [Artifact Hub](https://artifacthub.io/packages/helm/bitnami/nginx?utm_source=chatgpt.com)

``` asb
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update cat > values-nginx.yaml <<'EOF' service: type: ClusterIP
ingress:
  enabled: true hostname: hello.localtest.me     # wildcard DNS -> 
  127.0.0.1 ingressClassName: nginx              # targets ingress-nginx 
  path: /
EOF

helm upgrade --install web bitnami/nginx -f values-nginx.yaml
kubectl get deploy,svc,ingress
``` 

`localtest.me` hosts resolve to 127.0.0.1—no /etc/hosts edits. [The Official Microsoft ASP.NET Site](https://weblogs.asp.net/owscott/introducing-testing-domain-localtest-me?utm_source=chatgpt.com)[Super User](https://superuser.com/questions/1280827/why-does-the-registered-domain-name-localtest-me-resolve-to-127-0-0-1?utm_source=chatgpt.com)

# 4) Verify HTTP routing (host header)

```bash
# Browser: http://hello.localtest.me 
curl -i -H "Host: hello.localtest.me" http://127.0.0.1/
```

This proves Ingress host-based routing → Service → Pods. (Ingress concept). [Kubernetes](https://kubernetes.io/docs/concepts/services-networking/ingress/?utm_source=chatgpt.com)

# 5) Operate: scale, upgrade, rollback

**Why now:** Helm release mgmt is core in prod.

```bash
# scale via values helm upgrade web bitnami/nginx -f values-nginx.yaml --set replicaCount=3
kubectl get deploy web-nginx -w # simulate bad change, then rollback helm upgrade web bitnami/nginx --set replicaCount=bad || true helm history web
helm rollback web 1
``` 
HPA comes later; this shows Helm workflows first. HPA docs when ready. [Kubernetes](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/?utm_source=chatgpt.com)

----------

# 6) Observability (minimal → robust)

## 6a) Metrics server (prereq for `kubectl top` and HPA)

```bash
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update
helm upgrade --install metrics-server metrics-server/metrics-server -n kube-system
kubectl top nodes && kubectl top pods
``` 
Metrics Server purpose + chart. [kubernetes-sigs.github.io](https://kubernetes-sigs.github.io/metrics-server/?utm_source=chatgpt.com)[Artifact Hub](https://artifacthub.io/packages/helm/metrics-server/metrics-server?utm_source=chatgpt.com)

## 6b) Prometheus + Grafana (kube-prometheus-stack)

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm upgrade --install kps prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace
kubectl -n monitoring get pods` 
```
Chart home. [GitHub](https://github.com/prometheus-community/helm-charts?utm_source=chatgpt.com)[Artifact Hub](https://artifacthub.io/packages/helm/prometheus-community/kube-prometheus-stack?utm_source=chatgpt.com)

## 6c) Scrape ingress-nginx metrics

Reinstall ingress-nginx with metrics enabled (expose a ServiceMonitor):

```bash
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  -n ingress-nginx \
  --set controller.metrics.enabled=true \
  --set controller.metrics.serviceMonitor.enabled=true` 
```
Controller metrics guidance. [kubernetes.github.io](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/?utm_source=chatgpt.com)

----------

# 7) Autoscaling (HPA)

**Why now:** after metrics are flowing. Example CPU-based HPA:

```bash
kubectl autoscale deploy web-nginx --cpu-percent=50 --min=2 --max=6
kubectl get hpa
``` 
HPA task + walkthrough. [Kubernetes+1](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/?utm_source=chatgpt.com)

(Optional) Generate load, watch scale out, then back in.

----------

# 8) Security hardening (practical minimums)

## 8a) Pod Security Standards (namespace level)

Set `baseline` or `restricted` labels on the namespace to enforce defaults. Overview. [Stack Overflow](https://stackoverflow.com/questions/13333707/localtest-me-doesnt-work-on-my-machine?utm_source=chatgpt.com)

## 8b) NetworkPolicy (default allow → narrow to Ingress only)

```bash
apiVersion:  networking.k8s.io/v1  kind:  NetworkPolicy  metadata: { name:  web-allow-ingress, namespace:  default } spec:  podSelector: { matchLabels: app.kubernetes.io/name:  nginx } policyTypes: [Ingress] ingress:  -  from:  -  namespaceSelector:  matchLabels:  kubernetes.io/metadata.name:  ingress-nginx  ports: [{ protocol:  TCP, port:  80 }]
``` 
Apply and verify traffic is only from ingress. NetworkPolicy concept. [GitHub](https://github.com/kubernetes-sigs/metrics-server?utm_source=chatgpt.com)

## 8c) SecurityContext (non-root, drop caps, read-only)

Add to Deployment (or via chart values) and redeploy:
```bash
securityContext:  runAsNonRoot:  true  runAsUser:  10001  allowPrivilegeEscalation:  false  readOnlyRootFilesystem:  true  capabilities: { drop: ["ALL"] }
``` 

SecurityContext guidance. [GitHub](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack?utm_source=chatgpt.com)

----------

# 9) Optional TLS locally

You can add **cert-manager** and issue self-signed certs; for a short local demo, HTTP is enough. If you add TLS, attach `tls:` and a cert-issuer to the Ingress. (Controller config doc for advanced options.) [kubernetes.github.io](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/?utm_source=chatgpt.com)

----------

# 10) Explain “what we deployed” in one breath

“An NGINX web app (Pods via Deployment), reachable inside the cluster via Service, and outside via an Ingress rule implemented by ingress-nginx; metrics and dashboards via kube-prometheus-stack; HPA scales on CPU; namespace policies + pod security constrain blast radius.” [Kubernetes](https://kubernetes.io/docs/concepts/services-networking/ingress/?utm_source=chatgpt.com)[Artifact Hub+1](https://artifacthub.io/packages/helm/ingress-nginx/ingress-nginx?utm_source=chatgpt.com)

----------

# 11) Alternatives

-   **Other ingress controllers**: F5 NGINX, Traefik, etc.—same Ingress API, different implementation tradeoffs. [NGINX Documentation](https://docs.nginx.com/nginx-ingress-controller/installation/installing-nic/installation-with-helm/?utm_source=chatgpt.com)[Traefik Labs Documentation](https://doc.traefik.io/traefik/providers/kubernetes-ingress/?utm_source=chatgpt.com)
    
-   **Different local clusters**: kind/minikube instead of Docker Desktop—slightly more setup, more reproducible cluster lifecycle.
    
-   **Closer-to-prod build**: kubeadm on a Linux VM (wire CRI/CNI yourself).
    

----------

# 12) “Same flow in AWS” (map local → EKS)

-   **Cluster**: EKS (create via eksctl/Terraform/CDK).
    
-   **Ingress**: install **AWS Load Balancer Controller**; your Ingress manifest spawns an **ALB**.
    
-   **DNS**: Route 53; optionally **ExternalDNS** auto-manages records from Ingress.
    
-   **TLS**: **ACM** certs on the ALB.
    
-   **Scaling**: HPA as above; node scaling via Cluster Autoscaler or Karpenter.  
    HPA on EKS doc. [AWS Documentation](https://docs.aws.amazon.com/eks/latest/userguide/horizontal-pod-autoscaler.html?utm_source=chatgpt.com)
    

----------

# 13) Cleanup

```bash
helm uninstall web
helm uninstall ingress-nginx -n ingress-nginx
helm uninstall kps -n monitoring
kubectl delete ns monitoring ingress-nginx 
# Docker Desktop: disable Kubernetes if desired
```