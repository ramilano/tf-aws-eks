#!/bin/bash

# Exit on any error
set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
BUCKET_NAME=""
DYNAMODB_TABLE="${BUCKET_NAME}-ft-lock"
REGION=""

echo -e "${YELLOW}AWS Terraform Infrastructure Initialization Script${NC}"
echo "=================================================="

# Source AWS credentials from vars.sh
echo -e "\n${YELLOW}Setting up AWS credentials...${NC}"
if [ -f "vars.sh" ]; then
    source vars.sh
    echo -e "${GREEN}✓ AWS credentials loaded from vars.sh${NC}"
else
    echo -e "${RED}✗ vars.sh not found${NC}"
    echo "Please create vars.sh with your AWS credentials"
    exit 1
fi

# Verify AWS credentials
echo -e "\n${YELLOW}Verifying AWS credentials...${NC}"
if aws sts get-caller-identity > /dev/null 2>&1; then
    echo -e "${GREEN}✓ AWS credentials are valid${NC}"
    aws sts get-caller-identity
else
    echo -e "${RED}✗ AWS credentials are invalid or not set${NC}"
    echo "Please update the AWS credentials in this script before running."
    exit 1
fi

# Check if S3 bucket exists
echo -e "\n${YELLOW}Checking S3 bucket: ${BUCKET_NAME}${NC}"
if aws s3api head-bucket --bucket "${BUCKET_NAME}" 2>/dev/null; then
    echo -e "${GREEN}✓ S3 bucket already exists${NC}"
else
    echo -e "${YELLOW}Creating S3 bucket: ${BUCKET_NAME}${NC}"
    
    # Create bucket with proper location constraint for non-us-east-1 regions
    if [ "${REGION}" = "us-east-1" ]; then
        aws s3api create-bucket \
            --bucket "${BUCKET_NAME}" \
            --region "${REGION}"
    else
        aws s3api create-bucket \
            --bucket "${BUCKET_NAME}" \
            --region "${REGION}" \
            --create-bucket-configuration LocationConstraint="${REGION}"
    fi
    
    # Enable versioning
    aws s3api put-bucket-versioning \
        --bucket "${BUCKET_NAME}" \
        --versioning-configuration Status=Enabled
    
    # Enable encryption
    aws s3api put-bucket-encryption \
        --bucket "${BUCKET_NAME}" \
        --server-side-encryption-configuration '{
            "Rules": [{
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                }
            }]
        }'
    
    # Block public access
    aws s3api put-public-access-block \
        --bucket "${BUCKET_NAME}" \
        --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
    
    echo -e "${GREEN}✓ S3 bucket created successfully${NC}"
fi

# Check if DynamoDB table exists
echo -e "\n${YELLOW}Checking DynamoDB table: ${DYNAMODB_TABLE}${NC}"
if aws dynamodb describe-table --table-name "${DYNAMODB_TABLE}" --region "${REGION}" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ DynamoDB table already exists${NC}"
else
    echo -e "${YELLOW}Creating DynamoDB table: ${DYNAMODB_TABLE}${NC}"
    
    aws dynamodb create-table \
        --table-name "${DYNAMODB_TABLE}" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
        --region "${REGION}" \
        --tags Key=Name,Value="Terraform State Lock" Key=ManagedBy,Value=Terraform
    
    # Wait for table to be active
    echo "Waiting for DynamoDB table to be active..."
    aws dynamodb wait table-exists --table-name "${DYNAMODB_TABLE}" --region "${REGION}"
    
    echo -e "${GREEN}✓ DynamoDB table created successfully${NC}"
fi

# Create root terragrunt.hcl if it doesn't exist
if [ ! -f "terragrunt.hcl" ]; then
    echo -e "\n${YELLOW}Creating root terragrunt.hcl configuration...${NC}"
    cat > terragrunt.hcl << 'EOF'
# Root terragrunt configuration for remote state management

locals {
  # Parse the current working directory to extract environment and region
  path_components = split("/", get_terragrunt_dir())
  region = length(local.path_components) >= 2 ? local.path_components[length(local.path_components) - 2] : "eu-west-1"
  env = length(local.path_components) >= 1 ? local.path_components[length(local.path_components) - 1] : "default"
}

# Configure Terragrunt to automatically store tfstate files in S3
remote_state {
  backend = "s3"
  
  config = {
    bucket         = ""
    key            = "${local.region}/${local.env}/${path_relative_to_include()}/terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
    dynamodb_table = "-lock"
    
    s3_bucket_tags = {
      Name        = "Terraform State Storage"
      Environment = local.env
      ManagedBy   = "Terragrunt"
    }
    
    dynamodb_table_tags = {
      Name        = "Terraform State Lock"
      Environment = local.env
      ManagedBy   = "Terragrunt"
    }
  }
  
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

# Generate provider configuration
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  
  contents = <<-PROVIDER
provider "aws" {
  region = "\${local.region}"
  
  default_tags {
    tags = {
      ManagedBy   = "Terraform"
      Environment = "\${local.env}"
    }
  }
}
PROVIDER
}
EOF
    echo -e "${GREEN}✓ Root terragrunt.hcl created${NC}"
else
    echo -e "${GREEN}✓ Root terragrunt.hcl already exists${NC}"
fi

echo -e "\n${GREEN}✅ Initialization complete!${NC}"
echo -e "\n${YELLOW}Next steps:${NC}"
echo "1. Navigate to your environment: cd eu-west-1/prod"
echo "2. Run: terragrunt init"
echo "3. Run: terragrunt plan"
echo "4. Run: terragrunt apply"

echo -e "\n${YELLOW}Current AWS Identity:${NC}"
aws sts get-caller-identity