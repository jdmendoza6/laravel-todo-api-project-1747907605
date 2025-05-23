# Laravel Todo API

This is a Laravel-based API that provides functionality for managing todo items. The application is configured for deployment to AWS using ECR, ECS, and an Application Load Balancer.

## API Endpoints

- `GET /api/todos` - Get all todos
- `POST /api/todos` - Create a new todo
- `PUT /api/todos/{id}/toggle` - Toggle todo completion status
- `DELETE /api/todos/{id}` - Delete a todo

## Local Development Setup

1. Clone this repository
2. Run `docker-compose up -d`
3. Enter the container: `docker-compose exec app bash`
4. Install dependencies: `composer install`
5. Copy the environment file: `cp .env.example .env`
6. Generate application key: `php artisan key:generate`
7. Run migrations: `php artisan migrate`

The API will be available at `http://localhost:8000/api/todos`

## AWS Deployment

This project is configured for deployment to AWS ap-southeast-1 (Singapore) region using:
- Amazon ECR (Elastic Container Registry) for storing Docker images
- Amazon ECS (Elastic Container Service) for running containers
- Application Load Balancer for routing traffic
- CloudFormation for infrastructure as code

### Deployment Process

1. Push changes to the `ecs` branch
2. GitHub Actions workflow will:
   - Build and push a Docker image to ECR
   - Deploy the CloudFormation stack for ECS service with ALB

### Required AWS Resources

- VPC with public subnets
- RDS MySQL database (can be deployed using the included CloudFormation template)
- IAM permissions for GitHub Actions

### Manual Deployment Steps

If you prefer to deploy manually:

1. **Deploy RDS Database**:
   ```bash
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

2. **Build and Push Docker Image**:
   ```bash
   aws ecr get-login-password --region ap-southeast-1 | docker login --username AWS --password-stdin ACCOUNT_ID.dkr.ecr.ap-southeast-1.amazonaws.com
   docker build -t laravel-todo-api:latest -f Dockerfile.prod .
   docker tag laravel-todo-api:latest ACCOUNT_ID.dkr.ecr.ap-southeast-1.amazonaws.com/laravel-todo-api:latest
   docker push ACCOUNT_ID.dkr.ecr.ap-southeast-1.amazonaws.com/laravel-todo-api:latest
   ```

3. **Deploy ECS Service**:
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

### Environment Variables

The following secrets need to be configured in GitHub:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `DB_HOST` - Your RDS endpoint
- `DB_DATABASE` - laravel_todo_api
- `DB_USERNAME` - admin
- `DB_PASSWORD` - Your database password

### CloudFormation Templates

- `cloudformation/ecs-service.yml` - Deploys the ECS service with ALB
- `cloudformation/rds.yml` - Deploys an RDS MySQL database

### Important Notes

1. **Security Group Configuration**: 
   - Make sure the RDS security group allows traffic from the ECS security group
   - You may need to manually add a rule to allow traffic from the ECS security group to the RDS security group

2. **Docker Entrypoint**:
   - The application uses a custom entrypoint script that starts services immediately without waiting for MySQL
   - This prevents health check failures during deployment

3. **Health Check Configuration**:
   - The ALB health check is configured to check `/api/todos` endpoint
   - A grace period of 60 seconds is set to allow the container to start properly

4. **Troubleshooting**:
   - If you encounter connection issues, check CloudWatch logs for the ECS tasks
   - Verify security group rules are correctly configured
   - Test the RDS connection from a separate EC2 instance if needed
