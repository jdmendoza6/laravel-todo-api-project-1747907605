# Manual Deployment Instructions

This document provides instructions for manually deploying the Laravel Todo API to AWS using ECR, ECS, and an Application Load Balancer.

## Prerequisites

- AWS CLI configured with appropriate permissions
- Docker installed and running
- Access to the Laravel Todo API codebase

## Step 1: Build and Push Docker Image

1. Navigate to the project directory:
   ```bash
   cd /path/to/laravel-todo-api
   ```

2. Run the build and push script:
   ```bash
   ./build-and-push.sh
   ```

   This script will:
   - Log in to Amazon ECR
   - Build the Docker image
   - Tag the image
   - Push the image to ECR

## Step 2: Deploy the CloudFormation Stack

1. After successfully pushing the Docker image, deploy the CloudFormation stack:
   ```bash
   ./deploy-stack.sh
   ```

   This script will:
   - Deploy the CloudFormation stack with all necessary resources
   - Output the URL of the Application Load Balancer when deployment is complete

## Step 3: Verify the Deployment

1. Access your API at the URL provided by the deployment script
2. Test the API endpoints:
   - `GET /api/todos` - Get all todos
   - `POST /api/todos` - Create a new todo
   - `PUT /api/todos/{id}/toggle` - Toggle todo completion status
   - `DELETE /api/todos/{id}` - Delete a todo

## Troubleshooting

If you encounter issues during deployment:

1. Check the CloudFormation events:
   ```bash
   aws cloudformation describe-stack-events --stack-name laravel-todo-api-ecs --region ap-southeast-1
   ```

2. Check the ECS service logs:
   ```bash
   aws ecs describe-services --cluster laravel-todo-api-cluster --services laravel-todo-api-service --region ap-southeast-1
   ```

3. Check the ECR repository to ensure the image was pushed correctly:
   ```bash
   aws ecr describe-images --repository-name laravel-todo-api --region ap-southeast-1
   ```
