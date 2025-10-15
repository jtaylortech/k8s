# Multi-Tier Application Example

Complete example of a production-ready multi-tier application with frontend, backend, and database.

## Architecture

```
Internet → Ingress → Frontend (nginx) → Backend (API) → Database (PostgreSQL)
```

## Features

- Separate tiers with proper NetworkPolicies
- ConfigMaps for configuration
- Secrets for sensitive data
- Resource requests and limits
- Health checks (liveness, readiness)
- HPA for autoscaling
- PersistentVolume for database
- Production security settings

## Deployment

```bash
# Create namespace
kubectl create namespace app

# Deploy database first
kubectl apply -f database/

# Deploy backend
kubectl apply -f backend/

# Deploy frontend
kubectl apply -f frontend/

# Deploy ingress
kubectl apply -f ingress.yaml

# Verify
kubectl get all -n app
kubectl get ingress -n app

# Access
open http://app.localtest.me
```

## Components

- **database/**: PostgreSQL StatefulSet with PVC
- **backend/**: REST API deployment
- **frontend/**: NGINX serving static files
- **networkpolicies/**: Secure network policies
- **ingress.yaml**: External access configuration

## Testing

```bash
# Test frontend → backend connectivity
kubectl exec -it -n app deploy/frontend -- curl http://backend:8080/health

# Test backend → database connectivity
kubectl exec -it -n app deploy/backend -- psql -h database -U app -d appdb -c "SELECT 1"

# Load test (generate traffic for HPA)
kubectl run load -it --rm -n app --image=busybox:1.36 -- sh
while true; do wget -q -O- http://frontend; done
```

## Cleanup

```bash
kubectl delete namespace app
```
