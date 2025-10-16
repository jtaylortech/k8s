# AWS CDK for EKS - TypeScript Examples

Comprehensive guide to provisioning EKS clusters using AWS CDK with TypeScript.

## Why CDK?

**Type Safety:**
- Compile-time error checking
- IDE autocomplete and IntelliSense
- Refactoring support

**Programming Language Benefits:**
- Use loops, conditions, functions
- Reusable constructs
- Unit testing with Jest
- Share code with application

**AWS Integration:**
- Native AWS constructs
- Automatic CloudFormation generation
- Built-in best practices

## Prerequisites

```bash
# Node.js 16+
node --version

# AWS CDK
npm install -g aws-cdk

# AWS CLI configured
aws sts get-caller-identity

# kubectl
kubectl version --client
```

## Getting Started

### 1. Bootstrap CDK

**First time only:**

```bash
# Bootstrap your AWS account for CDK
cdk bootstrap aws://ACCOUNT-ID/us-west-2
```

This creates:
- S3 bucket for CDK assets
- IAM roles for deployments
- CloudFormation stack

### 2. Create New Project

```bash
# Create directory
mkdir my-eks-cluster
cd my-eks-cluster

# Initialize CDK project
cdk init app --language typescript

# Install EKS module
npm install @aws-cdk/aws-eks
```

### 3. Project Structure

```
my-eks-cluster/
├── bin/
│   └── my-eks-cluster.ts      # CDK app entry point
├── lib/
│   └── my-eks-cluster-stack.ts # Stack definition
├── test/
│   └── my-eks-cluster.test.ts  # Unit tests
├── cdk.json                     # CDK configuration
├── package.json
└── tsconfig.json
```

## Examples

### Basic Cluster

See [basic-cluster/](./basic-cluster/) for a simple EKS cluster with managed node group.

**Key features:**
- Single managed node group
- Public cluster endpoint
- Basic IAM roles
- ~10 minutes to deploy

### Production Cluster

See [production-cluster/](./production-cluster/) for production-ready configuration.

**Key features:**
- Private cluster endpoint
- Multiple node groups (on-demand + spot)
- Advanced networking
- Monitoring and logging
- ~15 minutes to deploy

### Advanced Patterns

See [advanced-patterns/](./advanced-patterns/) for complex scenarios.

**Patterns included:**
- Multi-environment with context
- Custom VPC configuration
- Fargate profiles
- Add-ons (Load Balancer Controller, EBS CSI, etc.)
- GitOps with Flux/ArgoCD
- Service accounts with IRSA

## CDK Commands

```bash
# List all stacks
cdk list

# Synthesize CloudFormation
cdk synth

# Show differences
cdk diff

# Deploy stack
cdk deploy

# Deploy with auto-approval
cdk deploy --require-approval never

# Deploy specific stack
cdk deploy MyEksStack

# Destroy stack
cdk destroy

# Watch mode (hot reload)
cdk watch
```

## Common Patterns

### 1. Basic EKS Cluster

```typescript
import * as cdk from 'aws-cdk-lib';
import * as eks from 'aws-cdk-lib/aws-eks';

export class MyEksStack extends cdk.Stack {
  constructor(scope: cdk.App, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    const cluster = new eks.Cluster(this, 'Cluster', {
      version: eks.KubernetesVersion.V1_28,
      defaultCapacity: 2,
      defaultCapacityInstance: cdk.aws_ec2.InstanceType.of(
        cdk.aws_ec2.InstanceClass.T3,
        cdk.aws_ec2.InstanceSize.MEDIUM
      ),
    });
  }
}
```

### 2. Cluster with Custom VPC

```typescript
import * as ec2 from 'aws-cdk-lib/aws-ec2';

const vpc = new ec2.Vpc(this, 'Vpc', {
  maxAzs: 3,
  natGateways: 1,
});

const cluster = new eks.Cluster(this, 'Cluster', {
  version: eks.KubernetesVersion.V1_28,
  vpc,
  defaultCapacity: 0, // We'll add our own
});
```

### 3. Multiple Node Groups

```typescript
// On-demand nodes
cluster.addNodegroupCapacity('on-demand', {
  instanceTypes: [new ec2.InstanceType('t3.medium')],
  minSize: 2,
  maxSize: 4,
  desiredSize: 2,
  capacityType: eks.CapacityType.ON_DEMAND,
});

// Spot nodes
cluster.addNodegroupCapacity('spot', {
  instanceTypes: [
    new ec2.InstanceType('t3.medium'),
    new ec2.InstanceType('t3a.medium'),
  ],
  minSize: 0,
  maxSize: 10,
  desiredSize: 2,
  capacityType: eks.CapacityType.SPOT,
  labels: {
    'workload-type': 'batch',
  },
  taints: [{
    key: 'spot',
    value: 'true',
    effect: eks.TaintEffect.NO_SCHEDULE,
  }],
});
```

### 4. Fargate Profile

```typescript
cluster.addFargateProfile('MyProfile', {
  selectors: [
    { namespace: 'default' },
    { namespace: 'kube-system', labels: { 'app': 'coredns' } },
  ],
});
```

### 5. IAM Roles for Service Accounts (IRSA)

```typescript
const sa = cluster.addServiceAccount('MyServiceAccount', {
  name: 'my-app',
  namespace: 'default',
});

// Add S3 read-only access
sa.role.addManagedPolicy(
  iam.ManagedPolicy.fromAwsManagedPolicyName('AmazonS3ReadOnlyAccess')
);

// Use in pod
const deployment = cluster.addManifest('MyApp', {
  apiVersion: 'apps/v1',
  kind: 'Deployment',
  metadata: { name: 'my-app' },
  spec: {
    selector: { matchLabels: { app: 'my-app' } },
    template: {
      metadata: { labels: { app: 'my-app' } },
      spec: {
        serviceAccountName: sa.serviceAccountName,
        containers: [{
          name: 'app',
          image: 'my-app:latest',
        }],
      },
    },
  },
});
```

### 6. Install Helm Charts

```typescript
cluster.addHelmChart('NginxIngress', {
  chart: 'ingress-nginx',
  repository: 'https://kubernetes.github.io/ingress-nginx',
  namespace: 'ingress-nginx',
  createNamespace: true,
  values: {
    controller: {
      replicaCount: 2,
      service: {
        type: 'LoadBalancer',
      },
    },
  },
});
```

### 7. Apply Kubernetes Manifests

```typescript
// From file
cluster.addManifest('MyApp', ...require('./k8s/deployment.json'));

// From URL
cluster.addManifest('MetricsServer',
  ...yaml.loadAll(
    fs.readFileSync('https://github.com/.../metrics-server.yaml', 'utf8')
  )
);

// Inline
cluster.addManifest('Namespace', {
  apiVersion: 'v1',
  kind: 'Namespace',
  metadata: { name: 'production' },
});
```

### 8. AWS Load Balancer Controller

```typescript
const albController = cluster.addHelmChart('ALBController', {
  chart: 'aws-load-balancer-controller',
  repository: 'https://aws.github.io/eks-charts',
  namespace: 'kube-system',
  values: {
    clusterName: cluster.clusterName,
    serviceAccount: {
      create: true,
      name: 'aws-load-balancer-controller',
    },
  },
});

// Create service account with IAM role
const albServiceAccount = cluster.addServiceAccount('ALBController', {
  name: 'aws-load-balancer-controller',
  namespace: 'kube-system',
});

// Add required IAM policy (see AWS docs for full policy)
albServiceAccount.role.addManagedPolicy(
  iam.ManagedPolicy.fromAwsManagedPolicyName('...')
);
```

### 9. CloudWatch Logging

```typescript
const cluster = new eks.Cluster(this, 'Cluster', {
  version: eks.KubernetesVersion.V1_28,
  clusterLogging: [
    eks.ClusterLoggingTypes.API,
    eks.ClusterLoggingTypes.AUDIT,
    eks.ClusterLoggingTypes.AUTHENTICATOR,
  ],
});
```

### 10. Tags

```typescript
cdk.Tags.of(cluster).add('Environment', 'Production');
cdk.Tags.of(cluster).add('Team', 'Platform');
cdk.Tags.of(cluster).add('CostCenter', 'Engineering');
```

## Multi-Environment Pattern

### Using CDK Context

**cdk.json:**
```json
{
  "context": {
    "dev": {
      "instanceType": "t3.medium",
      "desiredSize": 2,
      "maxSize": 3
    },
    "prod": {
      "instanceType": "t3.large",
      "desiredSize": 5,
      "maxSize": 20
    }
  }
}
```

**Stack code:**
```typescript
const env = this.node.tryGetContext('environment') || 'dev';
const config = this.node.tryGetContext(env);

const cluster = new eks.Cluster(this, 'Cluster', {
  version: eks.KubernetesVersion.V1_28,
  defaultCapacity: config.desiredSize,
  defaultCapacityInstance: new ec2.InstanceType(config.instanceType),
});
```

**Deploy:**
```bash
cdk deploy -c environment=dev
cdk deploy -c environment=prod
```

## Testing

### Unit Tests with Jest

```typescript
import { Template } from 'aws-cdk-lib/assertions';
import * as cdk from 'aws-cdk-lib';
import { MyEksStack } from '../lib/my-eks-stack';

test('EKS Cluster Created', () => {
  const app = new cdk.App();
  const stack = new MyEksStack(app, 'TestStack');
  const template = Template.fromStack(stack);

  // Assert cluster exists
  template.hasResourceProperties('AWS::EKS::Cluster', {
    Version: '1.28'
  });

  // Assert node group exists
  template.resourceCountIs('AWS::EKS::Nodegroup', 1);
});

test('Cluster has OIDC provider', () => {
  const app = new cdk.App();
  const stack = new MyEksStack(app, 'TestStack');
  const template = Template.fromStack(stack);

  template.hasResourceProperties('AWS::IAM::OIDCProvider', {});
});
```

**Run tests:**
```bash
npm test
```

## Outputs

```typescript
// Cluster name
new cdk.CfnOutput(this, 'ClusterName', {
  value: cluster.clusterName,
  description: 'EKS Cluster Name',
});

// kubectl config command
new cdk.CfnOutput(this, 'ConfigCommand', {
  value: `aws eks update-kubeconfig --region ${this.region} --name ${cluster.clusterName}`,
  description: 'Command to configure kubectl',
});

// OIDC provider ARN
new cdk.CfnOutput(this, 'OIDCProviderArn', {
  value: cluster.openIdConnectProvider.openIdConnectProviderArn,
});
```

## Cost Optimization

### Spot Instances

```typescript
cluster.addNodegroupCapacity('spot', {
  capacityType: eks.CapacityType.SPOT,
  instanceTypes: [
    new ec2.InstanceType('t3.medium'),
    new ec2.InstanceType('t3a.medium'),
    new ec2.InstanceType('t2.medium'),
  ],
  minSize: 0,
  maxSize: 10,
  desiredSize: 3,
});
```

### Autoscaling

```typescript
const nodeGroup = cluster.addNodegroupCapacity('autoscaled', {
  minSize: 1,
  maxSize: 10,
  desiredSize: 2,
});

// Enable cluster autoscaler
cluster.addHelmChart('ClusterAutoscaler', {
  chart: 'cluster-autoscaler',
  repository: 'https://kubernetes.github.io/autoscaler',
  values: {
    autoDiscovery: {
      clusterName: cluster.clusterName,
    },
  },
});
```

## Troubleshooting

### CDK Deploy Fails

```bash
# Check CloudFormation stack
aws cloudformation describe-stacks --stack-name MyEksStack

# Check CloudFormation events
aws cloudformation describe-stack-events --stack-name MyEksStack

# View synth output
cdk synth

# Verbose mode
cdk deploy --verbose
```

### Cluster Created but Can't Connect

```bash
# Update kubeconfig
aws eks update-kubeconfig --name MyCluster --region us-west-2

# Check cluster status
aws eks describe-cluster --name MyCluster --region us-west-2

# Verify IAM permissions
aws sts get-caller-identity
```

### Node Group Not Joining

```bash
# Check node group status
aws eks describe-nodegroup \
  --cluster-name MyCluster \
  --nodegroup-name my-nodegroup

# Check EC2 instances
aws ec2 describe-instances \
  --filters "Name=tag:eks:cluster-name,Values=MyCluster"
```

## Cleanup

```bash
# Destroy stack
cdk destroy

# Force destroy (skip confirmations)
cdk destroy --force

# Delete all CDK assets
aws s3 rb s3://cdk-bucket --force
```

## Next Steps

1. Try [Basic Cluster Example](./basic-cluster/)
2. Explore [Production Cluster](./production-cluster/)
3. Study [Advanced Patterns](./advanced-patterns/)
4. Implement CI/CD with GitHub Actions
5. Add monitoring and alerting

## Additional Resources

- [AWS CDK EKS Documentation](https://docs.aws.amazon.com/cdk/api/v2/docs/aws-cdk-lib.aws_eks-readme.html)
- [CDK EKS Blueprints](https://aws.github.io/cdk-eks-blueprints/)
- [CDK Workshop](https://cdkworkshop.com/)
- [CDK Patterns](https://cdkpatterns.com/)
