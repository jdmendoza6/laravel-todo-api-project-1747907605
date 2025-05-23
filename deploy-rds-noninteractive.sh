#!/bin/bash
set -e

# Configuration
AWS_REGION="ap-southeast-1"
STACK_NAME="laravel-todo-api-rds"

# Get the default VPC ID
echo "Getting default VPC..."
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --query "Vpcs[0].VpcId" --output text --region $AWS_REGION)

if [ -z "$VPC_ID" ]; then
  echo "Error: No default VPC found"
  exit 1
fi

echo "Using VPC ID: $VPC_ID"

# Get subnet IDs in the VPC
echo "Getting subnet IDs in VPC $VPC_ID..."
SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query "Subnets[*].SubnetId" --output text --region $AWS_REGION)

# Convert to comma-separated list
SUBNET_LIST=""
for subnet in $SUBNET_IDS; do
  if [ -z "$SUBNET_LIST" ]; then
    SUBNET_LIST="$subnet"
  else
    SUBNET_LIST="$SUBNET_LIST,$subnet"
  fi
done

if [ -z "$SUBNET_LIST" ]; then
  echo "Error: No subnets found in VPC $VPC_ID"
  exit 1
fi

echo "Using subnet IDs: $SUBNET_LIST"

# Create a temporary CloudFormation template file
TMP_TEMPLATE=$(mktemp)
cat > $TMP_TEMPLATE << EOF
AWSTemplateFormatVersion: '2010-09-09'
Description: 'CloudFormation template for RDS MySQL database for Laravel Todo API in ap-southeast-1'

Parameters:
  VpcId:
    Type: String
    Description: The VPC ID

  SubnetIds:
    Type: String
    Description: The comma-separated list of subnet IDs for the DB subnet group

  DBName:
    Type: String
    Description: The database name
    Default: laravel_todo_api
    MinLength: 1
    MaxLength: 64
    AllowedPattern: '[a-zA-Z][a-zA-Z0-9_]*'

  DBUsername:
    Type: String
    Description: The database admin username
    Default: admin
    MinLength: 1
    MaxLength: 16
    AllowedPattern: '[a-zA-Z][a-zA-Z0-9]*'

  DBPassword:
    Type: String
    Description: The database admin password
    NoEcho: true
    MinLength: 8
    MaxLength: 41
    AllowedPattern: '[a-zA-Z0-9]*'

  DBInstanceClass:
    Type: String
    Description: The database instance type
    Default: db.t3.micro
    AllowedValues:
      - db.t3.micro
      - db.t3.small
      - db.t3.medium

Resources:
  # DB Subnet Group
  DBSubnetGroup:
    Type: AWS::RDS::DBSubnetGroup
    Properties:
      DBSubnetGroupDescription: Subnet group for RDS database
      SubnetIds: !Split [",", !Ref SubnetIds]

  # Security Group for RDS
  DBSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: Security group for RDS database
      VpcId: !Ref VpcId
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 3306
          ToPort: 3306
          Description: Allow MySQL access from anywhere within VPC
          CidrIp: 0.0.0.0/0

  # RDS Instance
  DBInstance:
    Type: AWS::RDS::DBInstance
    Properties:
      DBName: !Ref DBName
      Engine: mysql
      EngineVersion: 8.0
      MasterUsername: !Ref DBUsername
      MasterUserPassword: !Ref DBPassword
      DBInstanceClass: !Ref DBInstanceClass
      AllocatedStorage: 20
      StorageType: gp2
      MultiAZ: false
      PubliclyAccessible: true
      DBSubnetGroupName: !Ref DBSubnetGroup
      VPCSecurityGroups:
        - !GetAtt DBSecurityGroup.GroupId
      Tags:
        - Key: Name
          Value: Laravel Todo API Database
        - Key: Environment
          Value: Development

Outputs:
  DBEndpoint:
    Description: The connection endpoint for the database
    Value: !GetAtt DBInstance.Endpoint.Address
  DBPort:
    Description: The port for the database
    Value: !GetAtt DBInstance.Endpoint.Port
EOF

# Create RDS database
echo "Creating RDS database..."
aws cloudformation create-stack \
  --stack-name $STACK_NAME \
  --template-body file://$TMP_TEMPLATE \
  --parameters \
    ParameterKey=VpcId,ParameterValue=$VPC_ID \
    ParameterKey=SubnetIds,ParameterValue=$SUBNET_LIST \
    ParameterKey=DBName,ParameterValue=laravel_todo_api \
    ParameterKey=DBUsername,ParameterValue=admin \
    ParameterKey=DBPassword,ParameterValue=Password123 \
    ParameterKey=DBInstanceClass,ParameterValue=db.t3.small \
  --region $AWS_REGION

# Clean up temporary file
rm $TMP_TEMPLATE

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
