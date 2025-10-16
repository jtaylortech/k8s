# Remote State Backend Configuration for Staging
# State is stored in S3 with DynamoDB locking

terraform {
  backend "s3" {
    # S3 bucket for state storage
    bucket = "k8s-learning-terraform-state"  # Change to your bucket name

    # State file path (unique per environment)
    key = "environments/staging/terraform.tfstate"

    # AWS region where bucket is located
    region = "us-west-2"

    # DynamoDB table for state locking
    dynamodb_table = "terraform-state-lock"

    # Enable encryption at rest
    encrypt = true
  }
}
