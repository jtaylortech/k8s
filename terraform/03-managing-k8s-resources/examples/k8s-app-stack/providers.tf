# Terraform and Provider Configuration
# This example shows how to use Terraform to manage Kubernetes resources

terraform {
  required_version = ">= 1.0"

  required_providers {
    # AWS provider - to get EKS cluster information
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    # Kubernetes provider - to manage K8s resources declaratively
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }

    # Helm provider - to deploy Helm charts
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }

  # Optional: Configure remote state
  # backend "s3" {
  #   bucket         = "my-terraform-state"
  #   key            = "k8s-app-stack/terraform.tfstate"
  #   region         = "us-west-2"
  #   dynamodb_table = "terraform-state-lock"
  #   encrypt        = true
  # }
}

# AWS Provider - needed to fetch EKS cluster information
provider "aws" {
  region = var.aws_region
}

# Data source to get EKS cluster information
# This is how we connect to an existing EKS cluster
data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

# Data source to get EKS cluster authentication token
# Terraform needs this token to authenticate with the K8s API
data "aws_eks_cluster_auth" "cluster" {
  name = var.cluster_name
}

# Kubernetes Provider Configuration
# This tells Terraform how to connect to your K8s cluster
provider "kubernetes" {
  # EKS cluster endpoint (API server URL)
  host = data.aws_eks_cluster.cluster.endpoint

  # Cluster CA certificate for TLS verification
  cluster_ca_certificate = base64decode(
    data.aws_eks_cluster.cluster.certificate_authority[0].data
  )

  # Authentication token (automatically refreshed by AWS provider)
  token = data.aws_eks_cluster_auth.cluster.token

  # Alternative: Use exec-based authentication (AWS CLI)
  # This is what kubectl uses under the hood
  # exec {
  #   api_version = "client.authentication.k8s.io/v1beta1"
  #   command     = "aws"
  #   args = [
  #     "eks",
  #     "get-token",
  #     "--cluster-name",
  #     var.cluster_name,
  #     "--region",
  #     var.aws_region,
  #   ]
  # }
}

# Helm Provider Configuration
# Helm is a package manager for Kubernetes
provider "helm" {
  kubernetes {
    host = data.aws_eks_cluster.cluster.endpoint

    cluster_ca_certificate = base64decode(
      data.aws_eks_cluster.cluster.certificate_authority[0].data
    )

    token = data.aws_eks_cluster_auth.cluster.token

    # Alternative: Use exec-based authentication
    # exec {
    #   api_version = "client.authentication.k8s.io/v1beta1"
    #   command     = "aws"
    #   args = [
    #     "eks",
    #     "get-token",
    #     "--cluster-name",
    #     var.cluster_name,
    #     "--region",
    #     var.aws_region,
    #   ]
    # }
  }
}
