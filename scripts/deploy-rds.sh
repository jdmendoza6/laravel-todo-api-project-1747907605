#!/bin/bash
set -e

# Script to deploy RDS database and set up schema for Laravel Todo API

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check if required parameters are provided
if [ "$#" -lt 3 ]; then
    echo "Usage: $0 <vpc-id> <subnet-id-1,subnet-id-2> <db-password>"
    exit 1
fi

VPC_ID=$1
SUBNET_IDS=$2
DB_PASSWORD=$3
REGION=${4:-"ap-southeast-1"}
STACK_NAME=${5:-"laravel-todo-api-db"}
DB_NAME=${6:-"laravel_todo_api"}
DB_USER=${7:-"admin"}

echo "Deploying RDS database stack..."
aws cloudformation deploy \
  --template-file ../cloudformation/rds.yml \
  --stack-name $STACK_NAME \
  --region $REGION \
  --parameter-overrides \
    VpcId=$VPC_ID \
    SubnetIds=$SUBNET_IDS \
    DBName=$DB_NAME \
    DBUser=$DB_USER \
    DBPassword=$DB_PASSWORD

echo "Waiting for RDS deployment to complete..."
aws cloudformation wait stack-create-complete --stack-name $STACK_NAME --region $REGION

# Get the RDS endpoint
DB_ENDPOINT=$(aws cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --region $REGION \
  --query "Stacks[0].Outputs[?OutputKey=='DBEndpoint'].OutputValue" \
  --output text)

echo "RDS database deployed successfully!"
echo "Database Endpoint: $DB_ENDPOINT"
echo "Database Name: $DB_NAME"
echo "Database User: $DB_USER"

echo "Setting up database schema..."
# Wait for RDS to be fully available
sleep 30

# Install mysql client if not available
if ! command -v mysql &> /dev/null; then
    echo "MySQL client not found. Installing..."
    apt-get update && apt-get install -y default-mysql-client
fi

# Apply the schema
mysql -h $DB_ENDPOINT -u $DB_USER -p$DB_PASSWORD < ../cloudformation/rds-setup.sql

echo "Database schema setup complete!"
echo ""
echo "Next steps:"
echo "1. Update your .env file with the following database connection details:"
echo "   DB_HOST=$DB_ENDPOINT"
echo "   DB_DATABASE=$DB_NAME"
echo "   DB_USERNAME=$DB_USER"
echo "   DB_PASSWORD=$DB_PASSWORD"
echo ""
echo "2. Deploy the ECS service using the CloudFormation template"
