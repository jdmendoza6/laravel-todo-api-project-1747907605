#!/bin/bash
set -e

# Configuration
AWS_REGION="ap-southeast-1"
STACK_NAME="laravel-todo-api-rds"

# Check if VPC ID is provided, otherwise list available VPCs
echo "Checking available VPCs..."
aws ec2 describe-vpcs --query "Vpcs[*].[VpcId,Tags[?Key=='Name'].Value|[0],CidrBlock]" --output table

# Prompt for VPC ID
read -p "Enter the VPC ID to use for RDS deployment: " VPC_ID

# Validate VPC ID
if [ -z "$VPC_ID" ]; then
  echo "Error: VPC ID cannot be empty"
  exit 1
fi

# Get subnet IDs in the VPC
echo "Getting subnet IDs in VPC $VPC_ID..."
SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query "Subnets[?MapPublicIpOnLaunch==false].SubnetId" --output text | tr '\t' ',')

if [ -z "$SUBNET_IDS" ]; then
  echo "No private subnets found. Using all subnets instead."
  SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query "Subnets[*].SubnetId" --output text | tr '\t' ',')
  
  if [ -z "$SUBNET_IDS" ]; then
    echo "Error: No subnets found in VPC $VPC_ID"
    exit 1
  fi
fi

echo "Using subnet IDs: $SUBNET_IDS"

# Create RDS database
echo "Creating RDS database..."
aws cloudformation create-stack \
  --stack-name $STACK_NAME \
  --template-body file://k8s/rds.yaml \
  --parameters \
    ParameterKey=VpcId,ParameterValue=$VPC_ID \
    ParameterKey=SubnetIds,ParameterValue=$SUBNET_IDS \
    ParameterKey=DBName,ParameterValue=laravel_todo_api \
    ParameterKey=DBUsername,ParameterValue=admin \
    ParameterKey=DBPassword,ParameterValue=Password123 \
    ParameterKey=DBInstanceClass,ParameterValue=db.t3.small \
  --region $AWS_REGION

# Wait for RDS stack to complete
echo "Waiting for RDS database to be created..."
aws cloudformation wait stack-create-complete --stack-name $STACK_NAME --region $AWS_REGION

# Get RDS endpoint
DB_HOST=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='DBEndpoint'].OutputValue" --output text --region $AWS_REGION)

echo "RDS deployment complete!"
echo "Database endpoint: $DB_HOST"
echo "Database name: laravel_todo_api"
echo "Database username: admin"
echo "Database password: Password123"
