# Remote State Backend Configuration for Production
# State is stored in S3 with DynamoDB locking

terraform {
  backend "s3" {
    # S3 bucket for state storage
    bucket = "k8s-learning-terraform-state"  # Change to your bucket name

    # State file path (unique per environment)
    key = "environments/prod/terraform.tfstate"

    # AWS region where bucket is located
    region = "us-west-2"

    # DynamoDB table for state locking
    dynamodb_table = "terraform-state-lock"

    # Enable encryption at rest
    encrypt = true
  }
}

# IMPORTANT: Production state should have extra protection
# Consider:
# 1. S3 bucket versioning enabled
# 2. MFA delete enabled on bucket
# 3. Restricted IAM permissions (read-only for most users)
# 4. Regular backups of state files
# 5. Separate AWS account for production
