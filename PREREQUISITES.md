# Prerequisites & Setup

Before starting your Kubernetes learning journey, you'll need to set up a local development environment. This guide covers multiple approaches from easiest to most production-like.

## Required Knowledge

### Minimal Requirements
- Basic command line navigation (`cd`, `ls`, `cat`)
- Basic understanding of what containers are (Docker familiarity helpful but not required)
- Text editor experience (VS Code, vim, nano, etc.)

### Helpful (But Not Required)
- YAML syntax basics
- HTTP/networking fundamentals
- Linux/Unix command line experience

## Tool Installation

### Option 1: Docker Desktop (Recommended for Beginners)

**Best for**: First-time learners, macOS/Windows users, GUI preference

Docker Desktop includes a single-node Kubernetes cluster that's perfect for learning.

#### macOS
```bash
# Install Docker Desktop
brew install --cask docker

# Or download from https://www.docker.com/products/docker-desktop

# After installation:
# 1. Open Docker Desktop
# 2. Go to Settings → Kubernetes
# 3. Check "Enable Kubernetes"
# 4. Click "Apply & Restart"
```

#### Windows
```powershell
# Using Chocolatey
choco install docker-desktop

# Or download from https://www.docker.com/products/docker-desktop

# Enable Kubernetes in Docker Desktop settings
```

#### Linux
Docker Desktop is available for Linux, but most Linux users prefer kind or minikube.

**Verification**:
```bash
kubectl cluster-info
# Should show: Kubernetes control plane is running at https://kubernetes.docker.internal:6443
```

---

### Option 2: kind (Kubernetes in Docker)

**Best for**: CI/CD pipelines, multiple clusters, Linux users, lighter weight

kind runs Kubernetes clusters in Docker containers, making it fast and disposable.

```bash
# macOS
brew install kind

# Linux
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Windows (PowerShell as admin)
curl.exe -Lo kind-windows-amd64.exe https://kind.sigs.k8s.io/dl/v0.20.0/kind-windows-amd64
Move-Item .\kind-windows-amd64.exe c:\some-dir-in-your-PATH\kind.exe
```

**Create your first cluster**:
```bash
# Basic cluster
kind create cluster

# Named cluster with custom config
kind create cluster --name learning

# Multi-node cluster (optional, for advanced modules)
cat <<EOF | kind create cluster --name multi-node --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
EOF
```

**Verification**:
```bash
kubectl cluster-info --context kind-learning
kubectl get nodes
```

---

### Option 3: minikube

**Best for**: Driver flexibility, built-in addons, local registry

```bash
# macOS
brew install minikube

# Linux
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Windows
choco install minikube
```

**Start cluster**:
```bash
# Default driver (usually Docker)
minikube start

# Specific driver
minikube start --driver=docker
# or --driver=virtualbox, --driver=hyperkit, etc.

# With more resources
minikube start --cpus=4 --memory=8192
```

**Verification**:
```bash
kubectl get nodes
minikube status
```

---

## Essential Tools

### kubectl (Required)

The Kubernetes command-line tool.

```bash
# macOS
brew install kubectl

# Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Windows
choco install kubernetes-cli

# Verify
kubectl version --client
```

### Helm (Required for later modules)

Package manager for Kubernetes.

```bash
# macOS
brew install helm

# Linux
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Windows
choco install kubernetes-helm

# Verify
helm version
```

### k9s (Highly Recommended)

Terminal-based UI for Kubernetes - makes learning much easier.

```bash
# macOS
brew install k9s

# Linux
curl -sS https://webinstall.dev/k9s | bash

# Windows
choco install k9s

# Launch
k9s
```

**k9s Quick Tips**:
- `:pods` - view pods
- `:svc` - view services
- `:deploy` - view deployments
- `?` - help
- `/` - filter
- `l` - logs
- `d` - describe

### Optional but Useful Tools

```bash
# kubectx + kubens - switch contexts and namespaces easily
brew install kubectx

# stern - tail logs from multiple pods
brew install stern

# jq - JSON processor for kubectl output
brew install jq

# yq - YAML processor
brew install yq
```

---

## Cluster Verification

Run these commands to ensure your cluster is ready:

```bash
# Check cluster is running
kubectl cluster-info

# Verify nodes are ready
kubectl get nodes

# Check system pods
kubectl get pods -n kube-system

# Test creating a simple pod
kubectl run test-nginx --image=nginx --restart=Never
kubectl get pods
kubectl delete pod test-nginx

# Verify you can create namespaces
kubectl create namespace test
kubectl delete namespace test
```

**Expected output**:
- All system pods should be `Running` or `Completed`
- Nodes should show `Ready` status
- You should be able to create and delete resources

---

## Choosing Your Setup

| Criterion | Docker Desktop | kind | minikube |
|-----------|---------------|------|----------|
| **Ease of Setup** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| **Resource Usage** | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| **Multi-cluster** | ❌ | ✅ | ✅ |
| **Persistence** | ✅ | ⚠️ (ephemeral) | ✅ |
| **LoadBalancer** | ✅ | ⚠️ (manual) | ✅ (addon) |
| **Best For** | Beginners | Testing, CI/CD | Development |

**Recommendation**:
- **Absolute beginners**: Docker Desktop
- **Learning/experimenting**: kind
- **Daily development**: minikube or Docker Desktop

---

## Setting Up Your Workspace

Create a directory for practice:

```bash
mkdir -p ~/k8s-learning
cd ~/k8s-learning

# Create a practice namespace
kubectl create namespace learning

# Set it as default (optional)
kubectl config set-context --current --namespace=learning
```

---

## Troubleshooting Common Issues

### Docker Desktop: Kubernetes not starting
```bash
# Reset Kubernetes cluster
# Docker Desktop → Settings → Kubernetes → Reset Kubernetes Cluster

# Or reset Docker Desktop entirely
# Docker Desktop → Troubleshoot → Reset to factory defaults
```

### kind: Cluster creation fails
```bash
# Check Docker is running
docker ps

# Delete existing cluster
kind delete cluster --name learning

# Try again with more verbose output
kind create cluster --name learning -v 1
```

### kubectl: "connection refused"
```bash
# Check cluster is running
docker ps  # Should see kind/k8s containers

# Check kubeconfig
kubectl config view
kubectl config get-contexts

# Switch to correct context
kubectl config use-context docker-desktop
# or
kubectl config use-context kind-learning
```

### Resource constraints
```bash
# Check cluster resource usage
kubectl top nodes  # Requires metrics-server

# For Docker Desktop: increase resources
# Settings → Resources → Increase CPUs/Memory

# For kind/minikube: recreate with more resources
```

---

## Ready to Learn?

Once you can run these commands successfully, you're ready:

```bash
kubectl get nodes
kubectl get namespaces
kubectl run test --image=nginx --restart=Never
kubectl delete pod test
```

**Next**: [Beginner Module 01: Fundamentals](beginner/01-fundamentals/README.md)

---

## Additional Setup for Expert Track

If you're planning to complete the expert track, consider also installing:

```bash
# Container runtime tools
brew install docker-compose
brew install buildx

# Cloud CLIs (for cloud modules)
brew install awscli      # AWS
brew install azure-cli   # Azure
brew install google-cloud-sdk  # GCP

# GitOps tools
brew install argocd
brew install fluxcd/tap/flux

# Policy tools
brew install open-policy-agent/tap/opa

# Service mesh
# (Installed as Helm charts in relevant modules)
```

These aren't needed to start—install them when you reach those modules.

---

## Questions?

- **Cluster won't start**: See troubleshooting section above
- **Command not found**: Ensure tools are in your PATH
- **Permission errors**: Some commands need `sudo` on Linux

**Still stuck?** Check [troubleshooting/README.md](troubleshooting/README.md)
