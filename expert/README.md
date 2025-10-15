# Expert Track: Advanced Kubernetes

**Prerequisites**: Complete [Beginner Track](../beginner/README.md) or equivalent production Kubernetes experience

---

## Overview

The expert track covers advanced Kubernetes topics for platform engineers, SREs, and architects building and operating production clusters at scale.

### Who This Is For

- Platform engineers building internal K8s platforms
- SREs operating production Kubernetes
- Architects designing multi-cluster systems
- Advanced practitioners preparing for CKS (Certified Kubernetes Security Specialist)

### What You'll Learn

- **Advanced networking**: CNI internals, service meshes, eBPF
- **Security hardening**: RBAC, PSA, OPA, supply chain security
- **Custom resources**: Build operators and CRDs
- **Performance optimization**: Scheduling, autoscaling, tuning
- **GitOps & Operations**: ArgoCD, Flux, multi-cluster management
- **Advanced observability**: Distributed tracing, APM, cost management

---

## Modules

### [01 - Advanced Networking](01-advanced-networking/README.md)
**Duration**: ~6 hours

- CNI (Container Network Interface) deep dive
- Calico, Cilium, and eBPF-based networking
- Advanced NetworkPolicy patterns
- Service mesh fundamentals (Istio, Linkerd)
- Multi-cluster networking
- Network performance tuning

**Prerequisites**: Understanding of Services, Ingress, basic NetworkPolicies

---

### [02 - Advanced Security](02-advanced-security/README.md)
**Duration**: ~6 hours

- RBAC design patterns and least privilege
- Pod Security Admission (PSA) policies
- Policy engines: OPA (Open Policy Agent), Kyverno
- Image scanning and admission controllers
- Supply chain security (Sigstore, Cosign, SBOM)
- Runtime security (Falco)
- Secrets management (Vault, External Secrets Operator)

**Prerequisites**: Basic SecurityContext, Secrets understanding

---

### [03 - Operators & Custom Resources](03-operators-crds/README.md)
**Duration**: ~8 hours

- Custom Resource Definitions (CRDs)
- Controller pattern and reconciliation loops
- Building operators with Kubebuilder
- Operator SDK and best practices
- State management and idempotency
- Testing and debugging operators
- Production operator design patterns

**Prerequisites**: Strong Go/Python programming, understanding of Kubernetes API

---

### [04 - Scheduling & Performance](04-scheduling-performance/README.md)
**Duration**: ~5 hours

- Advanced scheduling (affinity, anti-affinity, topology)
- Taints, tolerations, and node selection
- Priority and preemption
- Resource quotas and LimitRanges
- Quality of Service (QoS) classes
- Cluster autoscaling (Cluster Autoscaler, Karpenter)
- Node autoprovisioning
- Performance tuning and benchmarking

**Prerequisites**: Resource management basics, HPA experience

---

### [05 - Production Operations](05-production-operations/README.md)
**Duration**: ~6 hours

- GitOps with ArgoCD and Flux
- Multi-cluster management strategies
- Disaster recovery and backups (Velero)
- Cluster upgrades and rollback strategies
- Cost optimization techniques
- Capacity planning
- Incident response and postmortems

**Prerequisites**: Helm, production Kubernetes experience

---

### [06 - Advanced Observability](06-observability-advanced/README.md)
**Duration**: ~5 hours

- Distributed tracing (Jaeger, Tempo, OpenTelemetry)
- Application Performance Monitoring (APM)
- Continuous profiling
- eBPF-based observability (Pixie, Parca)
- Cost monitoring and allocation
- SLO/SLI definition and monitoring
- Capacity planning with metrics

**Prerequisites**: Prometheus & Grafana experience

---

## Learning Path Recommendations

### Path 1: Platform Engineer
1. Advanced Networking (01)
2. Operators & CRDs (03)
3. Scheduling & Performance (04)
4. Production Operations (05)

### Path 2: Security Specialist
1. Advanced Security (02)
2. Operators & CRDs (03)
3. Production Operations (05)
4. Advanced Observability (06)

### Path 3: SRE / Operations
1. Advanced Networking (01)
2. Scheduling & Performance (04)
3. Production Operations (05)
4. Advanced Observability (06)

---

## Hands-On Projects

After completing modules, build real-world projects:

### Project 1: Multi-Tenant Platform
- Build an internal K8s platform
- Implement namespace isolation
- Self-service with GitOps
- Cost allocation and quotas

### Project 2: Service Mesh Implementation
- Deploy Istio or Linkerd
- Implement mTLS between services
- Traffic management patterns
- Observability integration

### Project 3: Custom Operator
- Build a database operator
- Implement backup/restore
- Automated failover
- Monitoring integration

### Project 4: Multi-Cluster Setup
- Deploy ArgoCD hub-spoke model
- Implement cross-cluster service discovery
- Disaster recovery setup
- Blue-green cluster deployments

---

## Certifications

### CKS (Certified Kubernetes Security Specialist)
**Covers**:
- Cluster setup and hardening
- System hardening
- Minimize microservice vulnerabilities
- Supply chain security
- Monitoring, logging, runtime security

**Preparation**: Complete modules 01, 02, and 05

### CKA/CKAD Recertification
Expert track provides depth for CKA/CKAD renewal and advanced scenarios.

---

## Prerequisites Check

Before starting, ensure you can:

- [ ] Deploy multi-tier applications with Helm
- [ ] Configure Ingress and Services
- [ ] Use ConfigMaps and Secrets
- [ ] Implement health checks and autoscaling
- [ ] Debug pod and networking issues
- [ ] Understand YAML and kubectl deeply
- [ ] Read and write basic Go or Python (for operator module)

**Not ready?** Complete [Beginner Track](../beginner/README.md) first.

---

## Time Commitment

- **Self-paced**: 3-6 months (5-10 hours/week)
- **Intensive**: 1-2 months (20+ hours/week)
- **With projects**: Add 2-4 weeks per project

---

## Community & Resources

### Staying Current
- [Kubernetes Blog](https://kubernetes.io/blog/)
- [CNCF Landscape](https://landscape.cncf.io/)
- [KubeCon recordings](https://www.youtube.com/kubecon)
- [Kubernetes Slack](https://slack.k8s.io/)

### Advanced Reading
- *Production Kubernetes* by Josh Rosso, Rich Lander
- *Kubernetes Operators* by Jason Dobies, Joshua Wood
- *Kubernetes Security* by Liz Rice, Michael Hausenblas

### Labs & Practice
- [Killer.sh](https://killer.sh) - CKS/CKA practice
- [Kubernetes The Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way)
- [KataCoda scenarios](https://katacoda.com/kubernetes)

---

## Module Status

| Module | Status | Est. Completion |
|--------|--------|-----------------|
| 01 - Advanced Networking | 🚧 In Progress | TBD |
| 02 - Advanced Security | 📝 Planned | TBD |
| 03 - Operators & CRDs | 📝 Planned | TBD |
| 04 - Scheduling & Performance | 📝 Planned | TBD |
| 05 - Production Operations | 📝 Planned | TBD |
| 06 - Advanced Observability | 📝 Planned | TBD |

---

## Getting Started

**Ready to dive deep?** Start with [Module 01: Advanced Networking](01-advanced-networking/README.md)

**Questions about path?** Check [Learning Path Recommendations](#learning-path-recommendations) above

**Want to contribute?** Each module welcomes contributions—add exercises, fix errors, or propose new content!
