# Quick Start Guide

Get up and running with this repository in 5 minutes.

## 1. Setup Your Environment

### Option A: Docker Desktop (Easiest)
```bash
# Install Docker Desktop, then enable Kubernetes in settings
kubectl cluster-info
```

### Option B: kind (Lightweight)
```bash
brew install kind kubectl helm
kind create cluster
kubectl cluster-info
```

**Full setup guide**: [PREREQUISITES.md](PREREQUISITES.md)

---

## 2. Choose Your Path

### I'm New to Kubernetes
**Start**: [Beginner Module 01: Fundamentals](beginner/01-fundamentals/README.md)

```bash
cd beginner/01-fundamentals
# Follow the README step-by-step
```

**Track**: Complete modules 01 → 05 (14 hours total)

### I Know the Basics
**Test yourself**: Try these without looking:
```bash
kubectl create deployment test --image=nginx --replicas=3
kubectl expose deployment test --port=80 --type=ClusterIP
kubectl scale deployment test --replicas=5
kubectl delete deployment test
```

✅ **Easy?** Jump to [Module 05: Production Basics](beginner/05-production-basics/README.md)
❌ **Struggled?** Start at [Module 01](beginner/01-fundamentals/README.md)

### I'm Production-Ready
**Start**: [Expert Module 01: Advanced Networking](expert/01-advanced-networking/README.md)

Check: [Expert Track Overview](expert/README.md) for learning paths

---

## 3. Deploy Your First App

```bash
# Install ingress controller
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace

# Deploy example app
kubectl create namespace app
kubectl apply -f examples/multi-tier-app/database/
kubectl apply -f examples/multi-tier-app/backend/
kubectl apply -f examples/multi-tier-app/frontend/
kubectl apply -f examples/multi-tier-app/ingress.yaml

# Access it
open http://app.localtest.me
```

**Full example**: [examples/multi-tier-app/](examples/multi-tier-app/)

---

## 4. Reference Materials

While learning, keep these handy:

- **[kubectl Cheat Sheet](cheatsheets/kubectl.md)**: Common commands
- **[YAML Syntax Guide](cheatsheets/yaml-syntax.md)**: Resource templates
- **[Resource Sizing](cheatsheets/resources.md)**: CPU/memory guidelines
- **[Troubleshooting](troubleshooting/README.md)**: When things break

---

## 5. Learning Tips

### Best Practices
1. **Type commands yourself**: Don't copy-paste everything
2. **Break things**: Delete pods, mess with configs, learn to recover
3. **Validate each section**: Use the checklists before moving on
4. **Take notes**: Document what you learn
5. **Build projects**: Apply concepts to real applications

### Recommended Schedule

**Full-time learners** (40 hrs/week):
- Week 1-2: Beginner modules 01-03
- Week 3: Beginner modules 04-05
- Week 4+: Expert track + projects

**Part-time learners** (10 hrs/week):
- Month 1-2: Beginner track
- Month 3-6: Expert track
- Ongoing: Build projects

### Study Groups
Learning with others? Each module is ~2-3 hours, perfect for:
- Weekly study sessions
- Workshop format
- Pair programming

---

## 6. Common First Questions

**Q: Do I need cloud credits?**
A: No! Everything runs locally on Docker Desktop or kind.

**Q: How long until I'm job-ready?**
A: After beginner track (~14 hours) + building 2-3 projects = entry level ready.

**Q: Should I get certified?**
A: CKA/CKAD after beginner track. CKS after expert security modules.

**Q: What if I get stuck?**
A: Check [troubleshooting guide](troubleshooting/README.md), review module prerequisites, or open an issue.

**Q: Can I skip modules?**
A: Each module builds on previous ones. Use validation checklists to test if you can skip.

---

## 7. Next Steps

```bash
# Start learning
cd beginner/01-fundamentals
cat README.md

# Or jump to a specific topic
cd beginner/02-networking  # Services and Ingress
cd beginner/03-configuration  # ConfigMaps and Secrets
cd beginner/05-production-basics  # Helm and Monitoring

# Expert content
cd expert/01-advanced-networking  # CNI and Service Mesh
```

---

## Quick Commands Reference

```bash
# Cluster info
kubectl cluster-info
kubectl get nodes

# Deploy something
kubectl run nginx --image=nginx
kubectl get pods

# Expose it
kubectl expose pod nginx --port=80 --type=NodePort
kubectl get svc

# Clean up
kubectl delete pod nginx
kubectl delete svc nginx

# Use examples
kubectl apply -f beginner/01-fundamentals/deployment-nginx.yaml
kubectl get all
```

---

**Ready?** → [Start Learning](beginner/01-fundamentals/README.md) | [Setup First](PREREQUISITES.md) | [Jump to Expert](expert/README.md)
