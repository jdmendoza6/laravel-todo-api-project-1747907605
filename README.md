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

This project is configured for deployment to AWS using:
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

### Environment Variables

The following secrets need to be configured in GitHub:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `DB_HOST`
- `DB_DATABASE`
- `DB_USERNAME`
- `DB_PASSWORD`

### CloudFormation Templates

- `cloudformation/ecs-service.yml` - Deploys the ECS service with ALB
- `cloudformation/rds.yml` - Deploys an RDS MySQL database (optional)