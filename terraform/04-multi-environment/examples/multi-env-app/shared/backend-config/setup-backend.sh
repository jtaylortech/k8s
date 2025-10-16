#!/bin/bash
# Setup Script for Terraform Remote State Backend
# Creates S3 bucket and DynamoDB table for state management

set -e  # Exit on error

# =============================================================================
# Configuration - CHANGE THESE VALUES
# =============================================================================

BUCKET_NAME="k8s-learning-terraform-state"
DYNAMODB_TABLE="terraform-state-lock"
AWS_REGION="us-west-2"
PROJECT_NAME="k8s-learning"

# =============================================================================
# Colors for output
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# =============================================================================
# Functions
# =============================================================================

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}→ $1${NC}"
}

# =============================================================================
# Pre-flight Checks
# =============================================================================

print_info "Checking prerequisites..."

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check if AWS credentials are configured
if ! aws sts get-caller-identity &> /dev/null; then
    print_error "AWS credentials not configured. Run 'aws configure' first."
    exit 1
fi

print_success "Prerequisites OK"

# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
print_info "AWS Account: $AWS_ACCOUNT_ID"
print_info "Region: $AWS_REGION"

# =============================================================================
# Create S3 Bucket
# =============================================================================

print_info "Creating S3 bucket: $BUCKET_NAME"

# Check if bucket already exists
if aws s3 ls "s3://${BUCKET_NAME}" 2>&1 | grep -q 'NoSuchBucket'; then
    # Create bucket
    if [ "$AWS_REGION" = "us-east-1" ]; then
        # us-east-1 doesn't need LocationConstraint
        aws s3api create-bucket \
            --bucket "$BUCKET_NAME" \
            --region "$AWS_REGION"
    else
        aws s3api create-bucket \
            --bucket "$BUCKET_NAME" \
            --region "$AWS_REGION" \
            --create-bucket-configuration LocationConstraint="$AWS_REGION"
    fi
    print_success "S3 bucket created"
else
    print_info "S3 bucket already exists"
fi

# =============================================================================
# Configure S3 Bucket
# =============================================================================

print_info "Configuring S3 bucket..."

# Enable versioning
aws s3api put-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --versioning-configuration Status=Enabled
print_success "Versioning enabled"

# Enable encryption
aws s3api put-bucket-encryption \
    --bucket "$BUCKET_NAME" \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            },
            "BucketKeyEnabled": true
        }]
    }'
print_success "Encryption enabled"

# Block public access
aws s3api put-public-access-block \
    --bucket "$BUCKET_NAME" \
    --public-access-block-configuration \
        BlockPublicAcls=true,\
IgnorePublicAcls=true,\
BlockPublicPolicy=true,\
RestrictPublicBuckets=true
print_success "Public access blocked"

# Add lifecycle policy to clean up old versions
aws s3api put-bucket-lifecycle-configuration \
    --bucket "$BUCKET_NAME" \
    --lifecycle-configuration '{
        "Rules": [{
            "Id": "DeleteOldVersions",
            "Status": "Enabled",
            "NoncurrentVersionExpiration": {
                "NoncurrentDays": 90
            },
            "AbortIncompleteMultipartUpload": {
                "DaysAfterInitiation": 7
            }
        }]
    }'
print_success "Lifecycle policy configured"

# Add tags
aws s3api put-bucket-tagging \
    --bucket "$BUCKET_NAME" \
    --tagging "TagSet=[
        {Key=Project,Value=$PROJECT_NAME},
        {Key=ManagedBy,Value=Terraform},
        {Key=Purpose,Value=TerraformState}
    ]"
print_success "Tags added"

# =============================================================================
# Create DynamoDB Table for Locking
# =============================================================================

print_info "Creating DynamoDB table: $DYNAMODB_TABLE"

# Check if table already exists
if ! aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --region "$AWS_REGION" &> /dev/null; then
    # Create table
    aws dynamodb create-table \
        --table-name "$DYNAMODB_TABLE" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "$AWS_REGION" \
        --tags Key=Project,Value="$PROJECT_NAME" Key=ManagedBy,Value=Terraform Key=Purpose,Value=StateLocking

    print_success "DynamoDB table created"

    # Wait for table to be active
    print_info "Waiting for table to become active..."
    aws dynamodb wait table-exists --table-name "$DYNAMODB_TABLE" --region "$AWS_REGION"
    print_success "Table is active"
else
    print_info "DynamoDB table already exists"
fi

# Enable point-in-time recovery
aws dynamodb update-continuous-backups \
    --table-name "$DYNAMODB_TABLE" \
    --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true \
    --region "$AWS_REGION"
print_success "Point-in-time recovery enabled"

# =============================================================================
# Summary
# =============================================================================

echo ""
echo "========================================="
echo "Backend Setup Complete!"
echo "========================================="
echo ""
echo "S3 Bucket:       $BUCKET_NAME"
echo "DynamoDB Table:  $DYNAMODB_TABLE"
echo "Region:          $AWS_REGION"
echo ""
echo "Features enabled:"
echo "  ✓ S3 versioning"
echo "  ✓ S3 encryption (AES256)"
echo "  ✓ Public access blocked"
echo "  ✓ Lifecycle policy (90-day old version cleanup)"
echo "  ✓ DynamoDB state locking"
echo "  ✓ Point-in-time recovery"
echo ""
echo "Update your backend.tf files with:"
echo ""
echo "terraform {"
echo "  backend \"s3\" {"
echo "    bucket         = \"$BUCKET_NAME\""
echo "    key            = \"path/to/terraform.tfstate\""
echo "    region         = \"$AWS_REGION\""
echo "    dynamodb_table = \"$DYNAMODB_TABLE\""
echo "    encrypt        = true"
echo "  }"
echo "}"
echo ""
echo "Then run: terraform init"
echo ""

# =============================================================================
# Cost Estimate
# =============================================================================

print_info "Estimated monthly cost:"
echo "  S3 Standard Storage:    ~\$0.023/GB"
echo "  S3 Requests:            ~\$0.005/1000 PUT, ~\$0.0004/1000 GET"
echo "  DynamoDB (on-demand):   ~\$0.25/GB stored + requests"
echo ""
echo "Typical cost for small team: \$1-5/month"
echo ""
