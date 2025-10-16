# Remote State Backend Configuration for Development
# State is stored in S3 with DynamoDB locking

terraform {
  backend "s3" {
    # S3 bucket for state storage
    bucket = "k8s-learning-terraform-state"  # Change to your bucket name

    # State file path (unique per environment)
    key = "environments/dev/terraform.tfstate"

    # AWS region where bucket is located
    region = "us-west-2"

    # DynamoDB table for state locking
    dynamodb_table = "terraform-state-lock"

    # Enable encryption at rest
    encrypt = true

    # Workspace (optional)
    # workspace_key_prefix = "workspaces"
  }
}

# IMPORTANT: Before using this backend configuration:
# 1. Create S3 bucket: aws s3 mb s3://k8s-learning-terraform-state
# 2. Create DynamoDB table with LockID as partition key
# 3. Or run: cd ../../shared/backend-config && ./setup-backend.sh
#
# To initialize with backend:
# terraform init
#
# To migrate from local state to remote:
# terraform init -migrate-state
