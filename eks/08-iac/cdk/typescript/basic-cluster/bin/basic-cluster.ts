#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { BasicClusterStack } from '../lib/basic-cluster-stack';

// Create CDK app
const app = new cdk.App();

// Create the EKS cluster stack
new BasicClusterStack(app, 'BasicClusterStack', {
  // Specify environment (account and region)
  // Uses environment variables if not specified
  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT,
    region: process.env.CDK_DEFAULT_REGION || 'us-west-2',
  },

  // Stack description
  description: 'Basic EKS cluster with managed node group',

  // Tags applied to all resources
  tags: {
    'Environment': 'Development',
    'Project': 'EKS-Learning',
    'ManagedBy': 'CDK',
  },
});
