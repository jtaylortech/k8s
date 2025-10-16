import * as cdk from 'aws-cdk-lib';
import { Template } from 'aws-cdk-lib/assertions';
import { BasicClusterStack } from '../lib/basic-cluster-stack';

describe('BasicClusterStack', () => {
  let app: cdk.App;
  let stack: BasicClusterStack;
  let template: Template;

  beforeEach(() => {
    app = new cdk.App();
    stack = new BasicClusterStack(app, 'TestStack');
    template = Template.fromStack(stack);
  });

  test('EKS Cluster Created', () => {
    // Assert that an EKS cluster is created
    template.hasResourceProperties('AWS::EKS::Cluster', {
      Version: '1.28',
    });
  });

  test('Cluster has correct name', () => {
    template.hasResourceProperties('AWS::EKS::Cluster', {
      Name: 'BasicEksCluster',
    });
  });

  test('VPC is created with correct configuration', () => {
    // Check that VPC is created
    template.resourceCountIs('AWS::EC2::VPC', 1);

    // Check that we have the right number of subnets (3 AZs * 2 types = 6)
    template.resourceCountIs('AWS::EC2::Subnet', 6);

    // Check NAT Gateways (should be 1 for dev)
    template.resourceCountIs('AWS::EC2::NatGateway', 1);

    // Check Internet Gateway
    template.resourceCountIs('AWS::EC2::InternetGateway', 1);
  });

  test('Managed node group is created', () => {
    // Assert that a managed node group exists
    template.resourceCountIs('AWS::EKS::Nodegroup', 1);
  });

  test('OIDC provider is created for IRSA', () => {
    // Assert that OIDC provider exists
    template.resourceCountIs('AWS::IAM::OIDCProvider', 1);
  });

  test('Service account with IAM role is created', () => {
    // Check that IAM role for service account exists
    template.hasResourceProperties('AWS::IAM::Role', {
      AssumeRolePolicyDocument: {
        Statement: [{
          Action: 'sts:AssumeRoleWithWebIdentity',
          Effect: 'Allow',
        }],
      },
    });
  });

  test('CloudWatch logging is enabled', () => {
    // Check that logging is configured
    template.hasResourceProperties('AWS::EKS::Cluster', {
      Logging: {
        ClusterLogging: {
          EnabledTypes: [
            { Type: 'api' },
            { Type: 'audit' },
            { Type: 'authenticator' },
          ],
        },
      },
    });
  });

  test('Stack outputs are defined', () => {
    // Check that required outputs exist
    const outputs = template.findOutputs('*');

    expect(outputs).toHaveProperty('ClusterName');
    expect(outputs).toHaveProperty('ConfigCommand');
    expect(outputs).toHaveProperty('ClusterEndpoint');
    expect(outputs).toHaveProperty('OIDCProviderArn');
  });

  test('Resources are tagged correctly', () => {
    // Check that cluster has correct tags
    template.hasResourceProperties('AWS::EKS::Cluster', {
      Tags: [
        { Key: 'Environment', Value: 'Development' },
        { Key: 'Project', Value: 'EKS-Learning' },
        { Key: 'ManagedBy', Value: 'CDK' },
      ],
    });
  });
});
