# Laravel Todo API Deployment Guide

This guide provides detailed instructions for deploying the Laravel Todo API to AWS using ECS, ECR, and RDS.

## Prerequisites

1. AWS CLI installed and configured with appropriate permissions
2. Docker installed locally
3. Git repository with access to the `ecs` branch
4. MySQL client installed (for database setup)

## Deployment Steps

### 1. Deploy RDS Database

First, deploy the MySQL database using CloudFormation:

```bash
# Using the deployment script
cd scripts
./deploy-rds.sh vpc-XXXXXXXX "subnet-XXXXXXXX,subnet-YYYYYYYY" YourPassword123

# Or manually using AWS CLI
aws cloudformation deploy \
  --template-file cloudformation/rds.yml \
  --stack-name laravel-todo-api-db \
  --parameter-overrides \
    VpcId=vpc-XXXXXXXX \
    SubnetIds=subnet-XXXXXXXX,subnet-YYYYYYYY \
    DBName=laravel_todo_api \
    DBUser=admin \
    DBPassword=YourPassword123
```

Wait for the stack creation to complete and note the RDS endpoint from the stack outputs:

```bash
aws cloudformation describe-stacks \
  --stack-name laravel-todo-api-db \
  --query "Stacks[0].Outputs[?OutputKey=='DBEndpoint'].OutputValue" \
  --output text
```

### 2. Set Up Database Schema

You can set up the database schema using one of the following methods:

#### Option 1: Using the setup script

```bash
cd scripts
./setup-database.sh your-rds-endpoint.ap-southeast-1.rds.amazonaws.com admin YourPassword123 laravel_todo_api
```

#### Option 2: Using the SQL script directly

```bash
mysql -h your-rds-endpoint.ap-southeast-1.rds.amazonaws.com -u admin -pYourPassword123 < cloudformation/rds-setup.sql
```

#### Option 3: Using Laravel migrations

```bash
# Set environment variables
export DB_HOST=your-rds-endpoint.ap-southeast-1.rds.amazonaws.com
export DB_DATABASE=laravel_todo_api
export DB_USERNAME=admin
export DB_PASSWORD=YourPassword123

# Run migrations
php artisan migrate --force --env=production

# Seed the database with sample data
php artisan db:seed --force --env=production
```

### 3. Create ECR Repository

Create an ECR repository to store your Docker images:

```bash
aws ecr create-repository \
  --repository-name laravel-todo-api \
  --region ap-southeast-1
```

### 4. Build and Push Docker Image

Build the Docker image and push it to ECR:

```bash
# Get ECR login credentials
aws ecr get-login-password --region ap-southeast-1 | docker login --username AWS --password-stdin ACCOUNT_ID.dkr.ecr.ap-southeast-1.amazonaws.com

# Build the Docker image
docker build -t laravel-todo-api:latest -f Dockerfile.prod .

# Tag the image
docker tag laravel-todo-api:latest ACCOUNT_ID.dkr.ecr.ap-southeast-1.amazonaws.com/laravel-todo-api:latest

# Push the image to ECR
docker push ACCOUNT_ID.dkr.ecr.ap-southeast-1.amazonaws.com/laravel-todo-api:latest
```

### 5. Deploy ECS Service

Deploy the ECS service using CloudFormation:

```bash
aws cloudformation deploy \
  --template-file cloudformation/ecs-service.yml \
  --stack-name laravel-todo-api-ecs \
  --capabilities CAPABILITY_IAM \
  --parameter-overrides \
    VpcId=vpc-XXXXXXXX \
    SubnetIds=subnet-XXXXXXXX,subnet-YYYYYYYY \
    ImageUrl=ACCOUNT_ID.dkr.ecr.ap-southeast-1.amazonaws.com/laravel-todo-api:latest \
    DBHost=your-rds-endpoint.ap-southeast-1.rds.amazonaws.com \
    DBName=laravel_todo_api \
    DBUser=admin \
    DBPassword=YourPassword123
```

### 6. Configure Security Groups

Ensure the RDS security group allows traffic from the ECS security group:

```bash
# Get the ECS security group ID
ECS_SG=$(aws cloudformation describe-stack-resources \
  --stack-name laravel-todo-api-ecs \
  --logical-resource-id ECSSecurityGroup \
  --query "StackResources[0].PhysicalResourceId" \
  --output text)

# Get the RDS security group ID
RDS_SG=$(aws cloudformation describe-stack-resources \
  --stack-name laravel-todo-api-db \
  --logical-resource-id DBSecurityGroup \
  --query "StackResources[0].PhysicalResourceId" \
  --output text)

# Add ingress rule to allow traffic from ECS to RDS
aws ec2 authorize-security-group-ingress \
  --group-id $RDS_SG \
  --protocol tcp \
  --port 3306 \
  --source-group $ECS_SG
```

### 7. Get the Application URL

Get the ALB DNS name to access your application:

```bash
aws cloudformation describe-stacks \
  --stack-name laravel-todo-api-ecs \
  --query "Stacks[0].Outputs[?OutputKey=='LoadBalancerDNS'].OutputValue" \
  --output text
```

Your API will be available at `http://<LoadBalancerDNS>/api/todos`

### 8. Verify Deployment

Test the API endpoints to verify the deployment:

```bash
# Get all todos
curl http://<LoadBalancerDNS>/api/todos

# Create a new todo
curl -X POST http://<LoadBalancerDNS>/api/todos \
  -H "Content-Type: application/json" \
  -d '{"title":"Test from production"}'

# Toggle a todo's completion status
curl -X PUT http://<LoadBalancerDNS>/api/todos/1/toggle

# Delete a todo
curl -X DELETE http://<LoadBalancerDNS>/api/todos/1
```

## GitHub Actions Deployment

To set up automated deployments with GitHub Actions:

1. Add the following secrets to your GitHub repository:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `DB_HOST` - Your RDS endpoint
   - `DB_DATABASE` - laravel_todo_api
   - `DB_USERNAME` - admin
   - `DB_PASSWORD` - Your database password

2. Push changes to the `ecs` branch to trigger the deployment workflow.

## Database Maintenance

### Running Migrations

To run migrations on the production database:

```bash
# Set environment variables
export DB_HOST=your-rds-endpoint.ap-southeast-1.rds.amazonaws.com
export DB_DATABASE=laravel_todo_api
export DB_USERNAME=admin
export DB_PASSWORD=YourPassword123

# Run migrations
php artisan migrate --force --env=production
```

### Database Backups

To create a backup of the production database:

```bash
# Create a backup
mysqldump -h your-rds-endpoint.ap-southeast-1.rds.amazonaws.com -u admin -pYourPassword123 laravel_todo_api > backup_$(date +%Y%m%d).sql

# Restore from a backup
mysql -h your-rds-endpoint.ap-southeast-1.rds.amazonaws.com -u admin -pYourPassword123 laravel_todo_api < backup_20250523.sql
```

## Troubleshooting

### Common Issues

1. **Health Check Failures**:
   - Check CloudWatch logs for the ECS tasks
   - Verify the container is starting properly
   - Ensure the health check path `/api/todos` is accessible

2. **Database Connection Issues**:
   - Verify security group rules are correctly configured
   - Check that the database credentials are correct
   - Test the RDS connection from a separate EC2 instance

3. **Container Startup Issues**:
   - Check the Docker entrypoint script
   - Verify environment variables are correctly set
   - Check CloudWatch logs for startup errors

### Useful Commands

```bash
# View ECS service events
aws ecs describe-services --cluster laravel-todo-api-cluster --services laravel-todo-api-service

# View CloudWatch logs
aws logs get-log-events --log-group-name /ecs/laravel-todo-api-service --log-stream-name <log-stream-name>

# Force a new deployment
aws ecs update-service --cluster laravel-todo-api-cluster --service laravel-todo-api-service --force-new-deployment

# Test database connection
mysql -h your-rds-endpoint.ap-southeast-1.rds.amazonaws.com -u admin -pYourPassword123 -e "SELECT 1;"
```
