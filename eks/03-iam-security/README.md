# Module 03: IAM and Security for EKS

**Duration:** 5 hours
**Level:** Intermediate to Advanced

## Learning Objectives

By the end of this module, you will:
- Understand EKS IAM architecture
- Implement IAM Roles for Service Accounts (IRSA)
- Use Pod Identity (new AWS feature)
- Integrate RBAC with IAM
- Secure secrets with AWS Secrets Manager
- Implement pod security standards

## Table of Contents

1. [IAM Architecture Overview](#iam-architecture-overview)
2. [IAM Roles for Service Accounts (IRSA)](#iam-roles-for-service-accounts-irsa)
3. [Pod Identity](#pod-identity)
4. [RBAC and IAM Integration](#rbac-and-iam-integration)
5. [Secrets Management](#secrets-management)
6. [Pod Security](#pod-security)
7. [Hands-On Labs](#hands-on-labs)

## IAM Architecture Overview

### Three Layers of Identity

**1. Cluster Authentication (IAM)**
- Who can access the Kubernetes API?
- Uses AWS IAM credentials
- Managed via aws-auth ConfigMap

**2. Kubernetes Authorization (RBAC)**
- What can users/pods do in the cluster?
- Uses Kubernetes RBAC
- Roles and RoleBindings

**3. AWS Service Access (IRSA/Pod Identity)**
- How do pods access AWS services?
- Pods assume IAM roles
- No long-lived credentials needed

### IAM Entities

**Cluster Role:**
```
arn:aws:iam::123456789:role/eks-cluster-role
Permissions: EKS control plane operations
```

**Node Role:**
```
arn:aws:iam::123456789:role/eks-node-role
Permissions: EC2, ECR, CloudWatch
```

**Pod Execution Roles (IRSA):**
```
arn:aws:iam::123456789:role/eks-pod-role
Permissions: Application-specific (S3, DynamoDB, etc.)
```

## IAM Roles for Service Accounts (IRSA)

IRSA allows pods to assume IAM roles without using long-lived credentials.

### How IRSA Works

```
1. Pod starts with ServiceAccount
2. EKS injects AWS credentials via projected volume
3. AWS SDK uses credentials to call STS
4. STS returns temporary credentials
5. Pod uses temp credentials for AWS API calls
```

### Prerequisites

**Enable OIDC Provider:**
```bash
eksctl utils associate-iam-oidc-provider \
  --cluster my-cluster \
  --approve
```

Or with AWS CLI:
```bash
# Get OIDC issuer URL
aws eks describe-cluster \
  --name my-cluster \
  --query "cluster.identity.oidc.issuer" \
  --output text

# Create OIDC provider
aws iam create-open-id-connect-provider \
  --url https://oidc.eks.us-west-2.amazonaws.com/id/XXX \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 9e99a48a9960b14926bb7f3b02e22da2b0ab7280
```

### Create IAM Role for Service Account

**Using eksctl:**
```bash
eksctl create iamserviceaccount \
  --name my-app-sa \
  --namespace default \
  --cluster my-cluster \
  --attach-policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess \
  --approve \
  --override-existing-serviceaccounts
```

**Manual creation:**

**1. Create trust policy:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::123456789:oidc-provider/oidc.eks.us-west-2.amazonaws.com/id/XXX"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.us-west-2.amazonaws.com/id/XXX:sub": "system:serviceaccount:default:my-app-sa",
          "oidc.eks.us-west-2.amazonaws.com/id/XXX:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
```

**2. Create IAM role:**
```bash
aws iam create-role \
  --role-name eks-my-app-role \
  --assume-role-policy-document file://trust-policy.json

aws iam attach-role-policy \
  --role-name eks-my-app-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess
```

**3. Create ServiceAccount:**
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app-sa
  namespace: default
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789:role/eks-my-app-role
```

**4. Use in Pod:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app
spec:
  serviceAccountName: my-app-sa
  containers:
  - name: app
    image: my-app:latest
    env:
    - name: AWS_ROLE_ARN
      value: arn:aws:iam::123456789:role/eks-my-app-role
    - name: AWS_WEB_IDENTITY_TOKEN_FILE
      value: /var/run/secrets/eks.amazonaws.com/serviceaccount/token
```

### Verify IRSA

```bash
# Check ServiceAccount annotation
kubectl describe sa my-app-sa

# Check pod environment
kubectl exec my-app -- env | grep AWS

# Test AWS access
kubectl exec my-app -- aws s3 ls

# View projected token
kubectl exec my-app -- cat /var/run/secrets/eks.amazonaws.com/serviceaccount/token
```

## Pod Identity

Pod Identity is a newer, simpler alternative to IRSA (launched 2023).

### IRSA vs Pod Identity

| Feature | IRSA | Pod Identity |
|---------|------|--------------|
| Setup Complexity | Medium | Low |
| OIDC Required | Yes | No |
| Credential Rotation | Automatic | Automatic |
| Cross-Account | Supported | Supported |
| EKS Version | 1.13+ | 1.24+ |

### Enable Pod Identity

**1. Install EKS Pod Identity Agent:**
```bash
kubectl apply -f https://raw.githubusercontent.com/aws/eks-pod-identity-agent/main/deployment/eks-pod-identity-agent.yaml
```

**2. Create IAM role:**
```bash
aws iam create-role \
  --role-name eks-pod-identity-role \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {
        "Service": "pods.eks.amazonaws.com"
      },
      "Action": [
        "sts:AssumeRole",
        "sts:TagSession"
      ]
    }]
  }'
```

**3. Create association:**
```bash
aws eks create-pod-identity-association \
  --cluster-name my-cluster \
  --namespace default \
  --service-account my-app-sa \
  --role-arn arn:aws:iam::123456789:role/eks-pod-identity-role
```

**4. Use in pod (same as IRSA):**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app
spec:
  serviceAccountName: my-app-sa
  containers:
  - name: app
    image: my-app:latest
```

## RBAC and IAM Integration

### aws-auth ConfigMap

Controls which IAM entities can access the cluster.

**View current configuration:**
```bash
kubectl get configmap aws-auth -n kube-system -o yaml
```

**Add IAM user:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapUsers: |
    - userarn: arn:aws:iam::123456789:user/alice
      username: alice
      groups:
        - system:masters
    - userarn: arn:aws:iam::123456789:user/bob
      username: bob
      groups:
        - developers
```

**Add IAM role:**
```yaml
mapRoles: |
  - rolearn: arn:aws:iam::123456789:role/DevRole
    username: dev-role
    groups:
      - developers
  - rolearn: arn:aws:iam::123456789:role/AdminRole
    username: admin-role
    groups:
      - system:masters
```

### RBAC Patterns

**Read-only access:**
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: read-only
rules:
- apiGroups: ["", "apps", "batch"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: read-only-binding
subjects:
- kind: Group
  name: developers
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: read-only
  apiGroup: rbac.authorization.k8s.io
```

**Namespace-scoped developer:**
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: development
  name: developer
rules:
- apiGroups: ["", "apps", "batch"]
  resources: ["*"]
  verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: developer-binding
  namespace: development
subjects:
- kind: User
  name: alice
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: developer
  apiGroup: rbac.authorization.k8s.io
```

## Secrets Management

### Kubernetes Secrets (Not Recommended for Production)

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-secret
type: Opaque
data:
  username: YWRtaW4=  # base64 encoded
  password: cGFzc3dvcmQ=
```

**Problems:**
- Base64 is not encryption
- Stored in etcd (readable by admins)
- No rotation
- No audit trail

### AWS Secrets Manager (Recommended)

**Install Secrets Store CSI Driver:**
```bash
helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
helm install csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver \
  --namespace kube-system

# Install AWS provider
kubectl apply -f https://raw.githubusercontent.com/aws/secrets-store-csi-driver-provider-aws/main/deployment/aws-provider-installer.yaml
```

**Create secret in AWS:**
```bash
aws secretsmanager create-secret \
  --name my-app/database \
  --secret-string '{"username":"admin","password":"secret123"}'
```

**Create SecretProviderClass:**
```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: aws-secrets
spec:
  provider: aws
  parameters:
    objects: |
      - objectName: "my-app/database"
        objectType: "secretsmanager"
        jmesPath:
          - path: username
            objectAlias: db-username
          - path: password
            objectAlias: db-password
```

**Mount in pod:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app
spec:
  serviceAccountName: my-app-sa  # Must have SecretsManager permissions
  containers:
  - name: app
    image: my-app:latest
    volumeMounts:
    - name: secrets
      mountPath: "/mnt/secrets"
      readOnly: true
    env:
    - name: DB_USERNAME
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: db-username
  volumes:
  - name: secrets
    csi:
      driver: secrets-store.csi.k8s.io
      readOnly: true
      volumeAttributes:
        secretProviderClass: "aws-secrets"
```

### AWS Systems Manager Parameter Store

Similar to Secrets Manager but free:

```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: aws-parameters
spec:
  provider: aws
  parameters:
    objects: |
      - objectName: "/my-app/database/username"
        objectType: "ssmparameter"
      - objectName: "/my-app/database/password"
        objectType: "ssmparameter"
```

## Pod Security

### Pod Security Standards

EKS supports Pod Security Standards (PSS):

- **Privileged**: Unrestricted
- **Baseline**: Minimally restrictive
- **Restricted**: Heavily restricted (production recommended)

**Enable at namespace level:**
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

### Security Context

**Pod-level:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 2000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: my-app:latest
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
```

### NetworkPolicies

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-app
spec:
  podSelector:
    matchLabels:
      app: my-app
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 8080
```

## Hands-On Labs

### Lab 1: Set Up IRSA

```bash
# 1. Enable OIDC
eksctl utils associate-iam-oidc-provider \
  --cluster my-cluster \
  --approve

# 2. Create service account with S3 access
eksctl create iamserviceaccount \
  --name s3-reader \
  --namespace default \
  --cluster my-cluster \
  --attach-policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess \
  --approve

# 3. Create test pod
kubectl run test-pod \
  --image=amazon/aws-cli \
  --serviceaccount=s3-reader \
  --command -- sleep 3600

# 4. Test S3 access
kubectl exec test-pod -- aws s3 ls
```

### Lab 2: Integrate Secrets Manager

```bash
# 1. Create secret
aws secretsmanager create-secret \
  --name demo-secret \
  --secret-string '{"api-key":"demo123"}'

# 2. Install CSI driver
helm install csi-secrets-store \
  secrets-store-csi-driver/secrets-store-csi-driver \
  --namespace kube-system

# 3. Install AWS provider
kubectl apply -f https://raw.githubusercontent.com/aws/secrets-store-csi-driver-provider-aws/main/deployment/aws-provider-installer.yaml

# 4. Create service account with SecretsManager permissions
# 5. Create SecretProviderClass
# 6. Create pod with volume mount
# 7. Verify secret is mounted
```

### Lab 3: Configure RBAC

```bash
# 1. Create developer user
aws iam create-user --user-name alice

# 2. Create access key
aws iam create-access-key --user-name alice

# 3. Update aws-auth ConfigMap
kubectl edit configmap aws-auth -n kube-system
# Add alice to developers group

# 4. Create Role and RoleBinding
kubectl apply -f developer-role.yaml

# 5. Test access
# Configure kubectl with Alice's credentials
# Try various kubectl commands
```

## Best Practices

1. **Use IRSA or Pod Identity** - Never use long-lived credentials
2. **Principle of least privilege** - Grant minimum required permissions
3. **One role per application** - Don't share IAM roles
4. **Use Secrets Manager** - Don't use K8s secrets for sensitive data
5. **Enable Pod Security** - Enforce restricted standard
6. **Audit regularly** - Review IAM policies and RBAC
7. **Rotate credentials** - Use temporary credentials everywhere
8. **Monitor access** - Enable CloudTrail and audit logs
9. **NetworkPolicies** - Implement zero-trust networking
10. **Security contexts** - Run as non-root, drop capabilities

## Troubleshooting

### IRSA Not Working

```bash
# Check OIDC provider exists
aws iam list-open-id-connect-providers

# Verify service account annotation
kubectl describe sa my-app-sa

# Check pod environment variables
kubectl exec my-pod -- env | grep AWS

# Verify IAM role trust policy
aws iam get-role --role-name eks-my-app-role

# Check AWS SDK logs
kubectl logs my-pod
```

### RBAC Access Denied

```bash
# Check current user
kubectl auth whoami

# Test permissions
kubectl auth can-i create deployments
kubectl auth can-i create deployments --as=alice

# View effective permissions
kubectl auth can-i --list

# Debug RBAC
kubectl get rolebindings,clusterrolebindings -A | grep alice
```

## Quiz

1. What does IRSA stand for?
   - [ ] IAM Roles for Service Authentication
   - [x] IAM Roles for Service Accounts
   - [ ] IAM Roles for Secure Access
   - [ ] IAM Roles for System Accounts

2. Which is more secure for storing database passwords?
   - [ ] Kubernetes Secrets
   - [x] AWS Secrets Manager
   - [ ] Environment variables
   - [ ] ConfigMaps

3. What controls WHO can access the Kubernetes API?
   - [x] IAM (via aws-auth ConfigMap)
   - [ ] RBAC
   - [ ] Network Policies
   - [ ] Security Groups

4. What controls WHAT authenticated users can do?
   - [ ] IAM
   - [x] RBAC
   - [ ] Pod Security
   - [ ] IRSA

## Next Steps

Continue to [Module 04: Managed Node Groups and Compute](../04-compute/README.md)

## Additional Resources

- [IRSA Documentation](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
- [Pod Identity](https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html)
- [EKS Security Best Practices](https://aws.github.io/aws-eks-best-practices/security/docs/)
- [Secrets Store CSI Driver](https://secrets-store-csi-driver.sigs.k8s.io/)
