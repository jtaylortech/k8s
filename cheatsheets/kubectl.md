# kubectl Command Cheat Sheet

Quick reference for common kubectl commands.

## Cluster Info

```bash
# Cluster information
kubectl cluster-info

# Node information
kubectl get nodes
kubectl describe node <node-name>
kubectl top nodes                    # Requires metrics-server

# API resources
kubectl api-resources
kubectl api-versions
```

## Context & Configuration

```bash
# View contexts
kubectl config get-contexts
kubectl config current-context

# Switch context
kubectl config use-context <context-name>

# Set namespace
kubectl config set-context --current --namespace=<namespace>

# View kubeconfig
kubectl config view
```

## Namespaces

```bash
# List namespaces
kubectl get namespaces
kubectl get ns                       # Short form

# Create namespace
kubectl create namespace dev

# Delete namespace
kubectl delete namespace dev

# Get resources in all namespaces
kubectl get pods --all-namespaces
kubectl get pods -A                  # Short form
```

## Pods

```bash
# List pods
kubectl get pods
kubectl get pods -o wide             # More info (IP, node)
kubectl get pods --show-labels       # Show labels
kubectl get pods -w                  # Watch for changes

# Create pod
kubectl run nginx --image=nginx:1.25

# Describe pod
kubectl describe pod <pod-name>

# Get pod YAML
kubectl get pod <pod-name> -o yaml

# Delete pod
kubectl delete pod <pod-name>

# Execute command
kubectl exec <pod-name> -- <command>
kubectl exec -it <pod-name> -- /bin/bash

# Port forward
kubectl port-forward <pod-name> 8080:80

# Logs
kubectl logs <pod-name>
kubectl logs <pod-name> -f           # Follow
kubectl logs <pod-name> --tail=100   # Last 100 lines
kubectl logs <pod-name> --previous   # Previous container
kubectl logs <pod-name> -c <container>  # Specific container

# Copy files
kubectl cp <pod-name>:/path/to/file ./local-file
kubectl cp ./local-file <pod-name>:/path/to/file
```

## Deployments

```bash
# List deployments
kubectl get deployments
kubectl get deploy                   # Short form

# Create deployment
kubectl create deployment nginx --image=nginx:1.25 --replicas=3

# Describe deployment
kubectl describe deployment <name>

# Scale deployment
kubectl scale deployment <name> --replicas=5

# Update image
kubectl set image deployment/<name> <container>=<new-image>

# Rollout status
kubectl rollout status deployment/<name>

# Rollout history
kubectl rollout history deployment/<name>

# Rollback
kubectl rollout undo deployment/<name>
kubectl rollout undo deployment/<name> --to-revision=2

# Pause/resume rollout
kubectl rollout pause deployment/<name>
kubectl rollout resume deployment/<name>

# Delete deployment
kubectl delete deployment <name>
```

## Services

```bash
# List services
kubectl get services
kubectl get svc                      # Short form

# Create service
kubectl expose deployment <name> --port=80 --type=ClusterIP

# Describe service
kubectl describe service <name>

# Get endpoints
kubectl get endpoints <service-name>

# Delete service
kubectl delete service <name>
```

## ConfigMaps & Secrets

```bash
# ConfigMaps
kubectl create configmap <name> --from-literal=key=value
kubectl create configmap <name> --from-file=<file>
kubectl get configmaps
kubectl describe configmap <name>
kubectl delete configmap <name>

# Secrets
kubectl create secret generic <name> --from-literal=password=secret
kubectl create secret docker-registry <name> --docker-server=<server> --docker-username=<user> --docker-password=<pass>
kubectl get secrets
kubectl describe secret <name>
kubectl get secret <name> -o yaml    # View base64-encoded
kubectl delete secret <name>
```

## Labels & Selectors

```bash
# Show labels
kubectl get pods --show-labels

# Filter by label
kubectl get pods -l app=nginx
kubectl get pods -l 'app in (nginx,web)'
kubectl get pods -l app=nginx,env=prod

# Add label
kubectl label pod <name> env=prod

# Remove label
kubectl label pod <name> env-

# Update label
kubectl label pod <name> env=staging --overwrite
```

## Apply & Manage Resources

```bash
# Apply from file
kubectl apply -f <file>.yaml
kubectl apply -f <directory>/       # All files in directory

# Create from file
kubectl create -f <file>.yaml

# Delete from file
kubectl delete -f <file>.yaml

# Replace (recreate)
kubectl replace -f <file>.yaml

# Diff before apply
kubectl diff -f <file>.yaml

# Dry run
kubectl apply -f <file>.yaml --dry-run=client
kubectl create deployment test --image=nginx --dry-run=client -o yaml
```

## Editing Resources

```bash
# Edit resource in editor
kubectl edit deployment <name>

# Patch resource
kubectl patch deployment <name> -p '{"spec":{"replicas":5}}'

# Set environment variable
kubectl set env deployment/<name> KEY=value

# Set resources
kubectl set resources deployment/<name> --limits=cpu=200m,memory=512Mi
```

## Debugging

```bash
# Describe for events
kubectl describe pod <name>

# Check logs
kubectl logs <pod-name>
kubectl logs -f <pod-name>           # Follow
kubectl logs <pod-name> --previous   # After crash

# Run debug pod
kubectl run debug --rm -it --image=busybox:1.36 -- sh

# Debug in existing pod
kubectl exec -it <pod-name> -- /bin/bash

# Check resource usage
kubectl top nodes
kubectl top pods

# Get events
kubectl get events
kubectl get events --sort-by='.lastTimestamp'

# Check API server
kubectl get --raw /healthz
kubectl get --raw /metrics
```

## Advanced Queries

```bash
# JSONPath
kubectl get pods -o jsonpath='{.items[*].metadata.name}'
kubectl get pods -o jsonpath='{.items[*].spec.containers[*].image}'

# Custom columns
kubectl get pods -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image

# Sort
kubectl get pods --sort-by=.metadata.creationTimestamp

# Field selector
kubectl get pods --field-selector=status.phase=Running
kubectl get pods --field-selector=spec.nodeName=node-1
```

## Useful One-Liners

```bash
# Get all resource types
kubectl get all

# Delete all pods
kubectl delete pods --all

# Get non-running pods
kubectl get pods --field-selector=status.phase!=Running

# Get pod IPs
kubectl get pods -o wide | awk '{print $1, $6}'

# Count pods by node
kubectl get pods -o wide --all-namespaces | awk '{print $8}' | sort | uniq -c

# Get resource requests/limits
kubectl get pods -o custom-columns=NAME:.metadata.name,CPU_REQ:.spec.containers[*].resources.requests.cpu,MEM_REQ:.spec.containers[*].resources.requests.memory

# Force delete pod
kubectl delete pod <name> --grace-period=0 --force

# Get pod YAML without cluster-specific fields
kubectl get pod <name> -o yaml --export
```

## Helm (Package Manager)

```bash
# Add repo
helm repo add <name> <url>
helm repo update

# Search charts
helm search repo <keyword>

# Install chart
helm install <release-name> <chart>
helm install <release-name> <chart> -f values.yaml

# List releases
helm list
helm list -A                         # All namespaces

# Upgrade release
helm upgrade <release-name> <chart>

# Rollback
helm rollback <release-name> <revision>

# History
helm history <release-name>

# Uninstall
helm uninstall <release-name>

# Get values
helm get values <release-name>
helm show values <chart>

# Package chart
helm package <chart-directory>
```

## Shortcuts

| Full Command | Short | Description |
|--------------|-------|-------------|
| `kubectl` | `k` | Main command (alias) |
| `--namespace` | `-n` | Specify namespace |
| `--all-namespaces` | `-A` | All namespaces |
| `pods` | `po` | Pods |
| `services` | `svc` | Services |
| `deployments` | `deploy` | Deployments |
| `replicasets` | `rs` | ReplicaSets |
| `namespaces` | `ns` | Namespaces |
| `configmaps` | `cm` | ConfigMaps |
| `persistentvolumes` | `pv` | PersistentVolumes |
| `persistentvolumeclaims` | `pvc` | PersistentVolumeClaims |

## Bash Aliases

Add to `~/.bashrc` or `~/.zshrc`:

```bash
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kgd='kubectl get deploy'
alias kaf='kubectl apply -f'
alias kdf='kubectl delete -f'
alias kd='kubectl describe'
alias kl='kubectl logs'
alias ke='kubectl exec -it'
alias kpf='kubectl port-forward'

# Get pod names
kgpw() { kubectl get pods -o wide; }

# Quick logs
klf() { kubectl logs -f $1; }
```

## Pro Tips

1. **Enable autocompletion**:
   ```bash
   # Bash
   source <(kubectl completion bash)
   echo "source <(kubectl completion bash)" >> ~/.bashrc

   # Zsh
   source <(kubectl completion zsh)
   echo "source <(kubectl completion zsh)" >> ~/.zshrc
   ```

2. **Use k9s** for interactive terminal UI:
   ```bash
   brew install k9s
   k9s
   ```

3. **Use stern** for multi-pod logs:
   ```bash
   brew install stern
   stern <pod-pattern>
   ```

4. **Set default namespace**:
   ```bash
   kubectl config set-context --current --namespace=<namespace>
   ```

5. **Quick YAML generation**:
   ```bash
   kubectl create deployment nginx --image=nginx --dry-run=client -o yaml > deployment.yaml
   ```

---

For more: [Official kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
