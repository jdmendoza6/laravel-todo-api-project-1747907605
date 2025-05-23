# Laravel Todo API

This is a Laravel-based API that provides functionality for managing todo items. The application is configured for deployment to AWS using either ECS or EKS.

## API Endpoints

- `GET /api/todos` - Get all todos
- `POST /api/todos` - Create a new todo
- `PUT /api/todos/{id}/toggle` - Toggle todo completion status
- `DELETE /api/todos/{id}` - Delete a todo
- `GET /api/health` - Health check endpoint

## Local Development Setup

### Docker Compose

1. Clone this repository
2. Run `docker-compose up -d`
3. Enter the container: `docker-compose exec app bash`
4. Install dependencies: `composer install`
5. Copy the environment file: `cp .env.example .env`
6. Generate application key: `php artisan key:generate`
7. Run migrations: `php artisan migrate`

The API will be available at `http://localhost:8000/api/todos`

### Local Kubernetes Testing

For testing with Kubernetes locally before deploying to AWS:

1. Use the provided scripts:
   - `./test-local.sh` - Sets up Minikube environment
   - `./test-local-kind.sh` - Sets up Kind environment
2. Clean up after testing:
   - `./cleanup-local.sh` - Cleans up Minikube environment
   - `./cleanup-local-kind.sh` - Cleans up Kind environment

## AWS Deployment Options

This project supports two deployment options to AWS ap-southeast-1 (Singapore) region:

### Option 1: ECS Deployment

- Amazon ECR (Elastic Container Registry) for storing Docker images
- Amazon ECS (Elastic Container Service) for running containers
- Application Load Balancer for routing traffic
- CloudFormation for infrastructure as code

#### ECS Deployment Process

1. Push changes to the `ecs` branch
2. GitHub Actions workflow will:
   - Build and push a Docker image to ECR
   - Deploy the CloudFormation stack for ECS service with ALB

#### ECS CloudFormation Templates

- `cloudformation/ecs-service.yml` - Deploys the ECS service with ALB
- `cloudformation/rds.yml` - Deploys an RDS MySQL database (optional)

### Option 2: EKS Deployment

- Amazon ECR (Elastic Container Registry) for storing Docker images
- Amazon EKS (Elastic Kubernetes Service) for running containers
- AWS Load Balancer Controller for managing ALB
- Kubernetes manifests for deployment configuration

#### EKS Deployment Process

1. Deploy RDS database: `./deploy-rds-direct.sh`
2. Deploy EKS cluster: `./deploy-eks-cluster.sh`
3. Deploy ALB controller: `./deploy-alb-controller.sh`
4. Deploy application: `./deploy-app.sh`

Or use the all-in-one script:
```bash
./deploy-all.sh
```

#### EKS Configuration Files

- `k8s/cluster.yaml` - EKS cluster configuration
- `k8s/deployment.yaml` - Kubernetes deployment configuration
- `k8s/service.yaml` - Kubernetes service configuration
- `k8s/ingress.yaml` - ALB ingress configuration
- `k8s/hpa.yaml` - Horizontal Pod Autoscaler configuration

## Required AWS Resources

- VPC with public and private subnets
- RDS MySQL database
- IAM permissions for deployment

## Environment Variables

The following environment variables are required:
- `DB_HOST` - RDS endpoint
- `DB_DATABASE` - laravel_todo_api
- `DB_USERNAME` - admin
- `DB_PASSWORD` - Password123
