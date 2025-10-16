import * as cdk from 'aws-cdk-lib';
import * as eks from 'aws-cdk-lib/aws-eks';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as iam from 'aws-cdk-lib/aws-iam';
import { Construct } from 'constructs';

export class BasicClusterStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // =========================================================================
    // VPC
    // =========================================================================

    // Create VPC for the EKS cluster
    // This creates public and private subnets across 3 AZs
    const vpc = new ec2.Vpc(this, 'EksVpc', {
      // Maximum number of Availability Zones
      maxAzs: 3,

      // NAT Gateways (use 1 for dev to save costs, 3 for prod HA)
      natGateways: 1,

      // Subnet configuration
      subnetConfiguration: [
        {
          // Public subnets for load balancers
          name: 'Public',
          subnetType: ec2.SubnetType.PUBLIC,
          cidrMask: 24,
        },
        {
          // Private subnets for EKS nodes
          name: 'Private',
          subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS,
          cidrMask: 24,
        },
      ],
    });

    // Tag subnets for EKS (required for LoadBalancer discovery)
    // Public subnets: for external load balancers
    vpc.publicSubnets.forEach((subnet, index) => {
      cdk.Tags.of(subnet).add(
        'kubernetes.io/role/elb',
        '1',
      );
    });

    // Private subnets: for internal load balancers
    vpc.privateSubnets.forEach((subnet, index) => {
      cdk.Tags.of(subnet).add(
        'kubernetes.io/role/internal-elb',
        '1',
      );
    });

    // =========================================================================
    // EKS Cluster
    // =========================================================================

    // Create EKS cluster
    const cluster = new eks.Cluster(this, 'Cluster', {
      // Cluster name
      clusterName: 'BasicEksCluster',

      // Kubernetes version
      version: eks.KubernetesVersion.V1_28,

      // VPC to deploy cluster into
      vpc,

      // VPC subnets for control plane ENIs
      vpcSubnets: [{ subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS }],

      // Default capacity (creates managed node group)
      defaultCapacity: 2,

      // Instance type for default node group
      defaultCapacityInstance: ec2.InstanceType.of(
        ec2.InstanceClass.T3,
        ec2.InstanceSize.MEDIUM,
      ),

      // Cluster endpoint access
      // PUBLIC_AND_PRIVATE: API accessible from internet and VPC
      // PRIVATE: API accessible only from VPC (more secure)
      endpointAccess: eks.EndpointAccess.PUBLIC_AND_PRIVATE,

      // Control plane logging
      // Sends logs to CloudWatch (additional cost)
      clusterLogging: [
        eks.ClusterLoggingTypes.API,
        eks.ClusterLoggingTypes.AUDIT,
        eks.ClusterLoggingTypes.AUTHENTICATOR,
      ],

      // Security group for cluster control plane
      // Automatically created if not specified
    });

    // =========================================================================
    // IAM Role for Service Account (IRSA) Example
    // =========================================================================

    // Create a service account with IAM role
    // This allows pods to assume AWS IAM roles
    const appServiceAccount = cluster.addServiceAccount('AppServiceAccount', {
      name: 'my-app',
      namespace: 'default',
    });

    // Grant S3 read-only access to this service account
    appServiceAccount.role.addManagedPolicy(
      iam.ManagedPolicy.fromAwsManagedPolicyName('AmazonS3ReadOnlyAccess'),
    );

    // =========================================================================
    // Install Essential Add-ons (Optional)
    // =========================================================================

    // Deploy metrics-server for kubectl top and HPA
    cluster.addHelmChart('MetricsServer', {
      chart: 'metrics-server',
      repository: 'https://kubernetes-sigs.github.io/metrics-server/',
      namespace: 'kube-system',
      values: {
        args: [
          '--kubelet-preferred-address-types=InternalIP',
        ],
      },
    });

    // =========================================================================
    // Outputs
    // =========================================================================

    // Output cluster name
    new cdk.CfnOutput(this, 'ClusterName', {
      value: cluster.clusterName,
      description: 'EKS Cluster Name',
      exportName: 'EksClusterName',
    });

    // Output kubectl config command
    new cdk.CfnOutput(this, 'ConfigCommand', {
      value: `aws eks update-kubeconfig --region ${this.region} --name ${cluster.clusterName}`,
      description: 'Command to configure kubectl',
    });

    // Output cluster endpoint
    new cdk.CfnOutput(this, 'ClusterEndpoint', {
      value: cluster.clusterEndpoint,
      description: 'EKS Cluster Endpoint URL',
    });

    // Output OIDC provider ARN (useful for IRSA)
    new cdk.CfnOutput(this, 'OIDCProviderArn', {
      value: cluster.openIdConnectProvider.openIdConnectProviderArn,
      description: 'OIDC Provider ARN for IRSA',
    });

    // Output VPC ID
    new cdk.CfnOutput(this, 'VpcId', {
      value: vpc.vpcId,
      description: 'VPC ID where cluster is deployed',
    });
  }
}
