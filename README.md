# Kubernetes Learning Path: Zero to Expert

A comprehensive, hands-on guide to mastering Kubernetes—from your first pod to production-ready clusters.

## Who This Is For

- **Beginners**: New to Kubernetes or containers, looking for a structured learning path
- **Cloud/DevOps Engineers**: Need practical K8s skills for daily work
- **Experts-in-Training**: Want to master advanced topics like operators, security, and performance optimization

## Repository Structure

```
k8s/
├── README.md                          # You are here
├── PREREQUISITES.md                   # Setup instructions
├── beginner/                          # Learning Track (0-6 months)
│   ├── 01-fundamentals/              # Containers, Pods, Deployments
│   ├── 02-networking/                # Services, Ingress, DNS
│   ├── 03-configuration/             # ConfigMaps, Secrets, Volumes
│   ├── 04-workload-management/       # Scaling, Updates, Health Checks
│   └── 05-production-basics/         # Helm, Observability, Basic Security
├── expert/                            # Advanced Track (6+ months)
│   ├── 01-advanced-networking/       # CNI, Network Policies, Service Mesh
│   ├── 02-advanced-security/         # RBAC, PSA, OPA, Supply Chain
│   ├── 03-operators-crds/            # Custom Controllers, Operators
│   ├── 04-scheduling-performance/    # Advanced Scheduling, Tuning
│   ├── 05-production-operations/     # GitOps, Multi-cluster, DR
│   └── 06-observability-advanced/    # Distributed Tracing, APM
├── examples/                          # Practical application manifests
├── cheatsheets/                       # Quick reference guides
└── troubleshooting/                   # Common issues and solutions
```

## Learning Paths

### 🌱 Beginner Track (Recommended: 2-3 hours per module)

**Goal**: Deploy and manage applications on Kubernetes with confidence

1. **[01-Fundamentals](beginner/01-fundamentals/README.md)** (Start here!)
   - What is Kubernetes and why use it?
   - Containers, Pods, and Deployments
   - Your first application
   - ⏱️ ~3 hours

2. **[02-Networking](beginner/02-networking/README.md)**
   - Services (ClusterIP, NodePort, LoadBalancer)
   - Ingress controllers and routing
   - DNS and service discovery
   - ⏱️ ~3 hours

3. **[03-Configuration](beginner/03-configuration/README.md)**
   - ConfigMaps and Secrets
   - Environment variables
   - Volumes and persistent storage
   - ⏱️ ~2 hours

4. **[04-Workload Management](beginner/04-workload-management/README.md)**
   - Scaling (manual and HPA)
   - Rolling updates and rollbacks
   - Health checks (liveness, readiness)
   - ⏱️ ~2 hours

5. **[05-Production Basics](beginner/05-production-basics/README.md)**
   - Helm package manager
   - Monitoring with Prometheus & Grafana
   - Logging fundamentals
   - Security basics
   - ⏱️ ~4 hours

**By the end**: You can deploy, expose, configure, and monitor real applications on Kubernetes.

---

### 🚀 Expert Track (Recommended: 4-6 hours per module)

**Goal**: Design, secure, and operate production-grade Kubernetes platforms

1. **[01-Advanced Networking](expert/01-advanced-networking/README.md)**
   - CNI deep dive (Calico, Cilium)
   - Advanced NetworkPolicies
   - Service meshes (Istio/Linkerd)
   - eBPF and observability

2. **[02-Advanced Security](expert/02-advanced-security/README.md)**
   - RBAC patterns and least privilege
   - Pod Security Admission
   - Policy engines (OPA, Kyverno)
   - Supply chain security (Sigstore, SBOM)

3. **[03-Operators & CRDs](expert/03-operators-crds/README.md)**
   - Custom Resource Definitions
   - Building operators (Kubebuilder, Operator SDK)
   - State management patterns
   - Production operator design

4. **[04-Scheduling & Performance](expert/04-scheduling-performance/README.md)**
   - Advanced scheduling (affinity, taints, topology)
   - Resource management and QoS
   - Cluster autoscaling (Karpenter)
   - Performance tuning

5. **[05-Production Operations](expert/05-production-operations/README.md)**
   - GitOps (ArgoCD, Flux)
   - Multi-cluster management
   - Disaster recovery and backups
   - Upgrade strategies

6. **[06-Advanced Observability](expert/06-observability-advanced/README.md)**
   - Distributed tracing (Jaeger, Tempo)
   - APM and profiling
   - Cost monitoring
   - Capacity planning

**By the end**: You can architect, secure, and operate Kubernetes at scale in production.

---

## Quick Start

### 1. Prerequisites
```bash
# Install required tools
brew install kubectl helm k9s

# Set up local cluster (choose one)
# Option A: Docker Desktop (easiest)
# Enable Kubernetes in Docker Desktop settings

# Option B: kind (lightweight, CI-friendly)
brew install kind
kind create cluster

# Verify
kubectl cluster-info
kubectl get nodes
```

📖 Detailed setup: [PREREQUISITES.md](PREREQUISITES.md)

### 2. Start Learning

```bash
# Beginner: Start here
cd beginner/01-fundamentals
cat README.md

# Expert: Jump to advanced topics
cd expert/01-advanced-networking
cat README.md
```

### 3. Validate Your Knowledge

Each module includes:
- ✅ Hands-on exercises
- 🎯 Validation commands to verify your work
- 🐛 Common mistakes and how to fix them
- 📚 Additional resources

---

## How to Use This Repository

### For Self-Learners
1. Start with the beginner track, even if you have some K8s experience
2. Complete exercises in order—each builds on the previous
3. Don't skip validation steps
4. Use troubleshooting guides when stuck
5. Move to expert track after completing beginner modules

### For Instructors/Teams
- Each module is self-contained with objectives and outcomes
- Estimated times help with planning
- Exercises can be done individually or in groups
- Cheatsheets provide quick reference for workshops

### For Interview Prep
- Beginner track covers most interview fundamentals
- Expert track covers advanced/architect-level questions
- Troubleshooting guides mirror real-world scenarios

---

## Cheat Sheets

Quick reference for common tasks:

- [kubectl Command Reference](cheatsheets/kubectl.md)
- [YAML Syntax Guide](cheatsheets/yaml-syntax.md)
- [Resource Limits Cheat Sheet](cheatsheets/resources.md)
- [Troubleshooting Flowcharts](cheatsheets/troubleshooting.md)

---

## Philosophy

This repository is built on these principles:

1. **Hands-on First**: You learn by doing, not just reading
2. **Progressive Complexity**: Start simple, build up systematically
3. **Production-Focused**: Examples mirror real-world scenarios
4. **Validation at Every Step**: Verify you understand before moving on
5. **No Magic**: Every concept is explained, no "just copy this"

---

## Additional Resources

### Official Documentation
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Kubernetes API Reference](https://kubernetes.io/docs/reference/kubernetes-api/)

### Community
- [Kubernetes Slack](https://slack.k8s.io/)
- [r/kubernetes](https://reddit.com/r/kubernetes)
- [CNCF Webinars](https://www.cncf.io/webinars/)

### Certifications
- **CKA** (Certified Kubernetes Administrator): After beginner track
- **CKAD** (Certified Kubernetes Application Developer): After beginner track
- **CKS** (Certified Kubernetes Security Specialist): After expert security modules

---

## Contributing

Found an error? Have a suggestion? Open an issue or PR!

Guidelines:
- Keep examples simple and focused
- Test all commands before submitting
- Follow the existing structure
- Add validation steps for exercises

---

## Quick Navigation

**I'm new to K8s** → Start: [Prerequisites](PREREQUISITES.md) → [Fundamentals](beginner/01-fundamentals/README.md)

**I know the basics** → Test yourself: [Fundamentals Validation](beginner/01-fundamentals/validation.md)

**I'm production-ready** → Jump to: [Expert Track](expert/README.md)

**I'm stuck** → Check: [Troubleshooting](troubleshooting/README.md)

---

## License

MIT License - feel free to use this for learning, teaching, or training.

---

**Ready to start?** → [Prerequisites Setup](PREREQUISITES.md) → [Module 01: Fundamentals](beginner/01-fundamentals/README.md)
