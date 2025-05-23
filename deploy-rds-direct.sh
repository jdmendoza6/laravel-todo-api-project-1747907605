#!/bin/bash
set -e

# Configuration
AWS_REGION="ap-southeast-1"
DB_INSTANCE_IDENTIFIER="laravel-todo-api-db"
DB_NAME="laravel_todo_api"
DB_USERNAME="admin"
DB_PASSWORD="Password123"
DB_INSTANCE_CLASS="db.t3.small"

# Get the default VPC ID
echo "Getting default VPC..."
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --query "Vpcs[0].VpcId" --output text --region $AWS_REGION)

if [ -z "$VPC_ID" ]; then
  echo "Error: No default VPC found"
  exit 1
fi

echo "Using VPC ID: $VPC_ID"

# Create security group for RDS
echo "Creating security group for RDS..."
SG_NAME="laravel-todo-api-db-sg-$(date +%s)"
SG_ID=$(aws ec2 create-security-group \
  --group-name $SG_NAME \
  --description "Security group for Laravel Todo API RDS" \
  --vpc-id $VPC_ID \
  --region $AWS_REGION \
  --output text \
  --query "GroupId")

echo "Created security group: $SG_ID"

# Allow MySQL access from anywhere within the VPC
echo "Configuring security group ingress rules..."
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 3306 \
  --cidr 0.0.0.0/0 \
  --region $AWS_REGION

# Get subnet IDs in the VPC
echo "Getting subnet IDs in VPC $VPC_ID..."
SUBNET_ID1=$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query "Subnets[0].SubnetId" \
  --output text \
  --region $AWS_REGION)

SUBNET_ID2=$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query "Subnets[1].SubnetId" \
  --output text \
  --region $AWS_REGION)

echo "Using subnets: $SUBNET_ID1 and $SUBNET_ID2"

# Create DB subnet group
SUBNET_GROUP_NAME="laravel-todo-api-subnet-group-$(date +%s)"
echo "Creating DB subnet group: $SUBNET_GROUP_NAME"
aws rds create-db-subnet-group \
  --db-subnet-group-name $SUBNET_GROUP_NAME \
  --db-subnet-group-description "Subnet group for Laravel Todo API RDS" \
  --subnet-ids "$SUBNET_ID1" "$SUBNET_ID2" \
  --region $AWS_REGION

# Create RDS instance
echo "Creating RDS instance: $DB_INSTANCE_IDENTIFIER"
aws rds create-db-instance \
  --db-instance-identifier $DB_INSTANCE_IDENTIFIER \
  --db-name $DB_NAME \
  --engine mysql \
  --engine-version 8.0 \
  --db-instance-class $DB_INSTANCE_CLASS \
  --allocated-storage 20 \
  --storage-type gp2 \
  --master-username $DB_USERNAME \
  --master-user-password $DB_PASSWORD \
  --vpc-security-group-ids $SG_ID \
  --db-subnet-group-name $SUBNET_GROUP_NAME \
  --publicly-accessible \
  --region $AWS_REGION

echo "Waiting for RDS instance to be available..."
aws rds wait db-instance-available \
  --db-instance-identifier $DB_INSTANCE_IDENTIFIER \
  --region $AWS_REGION

# Get RDS endpoint
DB_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier $DB_INSTANCE_IDENTIFIER \
  --query "DBInstances[0].Endpoint.Address" \
  --output text \
  --region $AWS_REGION)

echo "RDS deployment complete!"
echo "Database endpoint: $DB_ENDPOINT"
echo "Database name: $DB_NAME"
echo "Database username: $DB_USERNAME"
echo "Database password: $DB_PASSWORD"

# Save the database information to a config file
cat > /home/ubuntu/Documents/sample-app/laravel-todo-api/k8s/db-config.env << EOF
DB_HOST=$DB_ENDPOINT
DB_PORT=3306
DB_DATABASE=$DB_NAME
DB_USERNAME=$DB_USERNAME
DB_PASSWORD=$DB_PASSWORD
EOF

echo "Database configuration saved to k8s/db-config.env"
