#!/bin/bash
set -e

# Configuration
AWS_REGION="ap-southeast-1"
ECR_REPO_NAME="laravel-todo-api"
APP_NAME="laravel-todo-api"

# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)

# Create ECR repository if it doesn't exist
echo "Creating ECR repository if it doesn't exist..."
aws ecr describe-repositories --repository-names $ECR_REPO_NAME --region $AWS_REGION || \
  aws ecr create-repository --repository-name $ECR_REPO_NAME --region $AWS_REGION

# Build and push Docker image
echo "Building and pushing Docker image..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
docker build -t $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO_NAME:latest -f Dockerfile.eks .
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO_NAME:latest

# Load database configuration
source k8s/db-config.env

# Create Kubernetes namespace
echo "Creating Kubernetes namespace..."
kubectl create namespace laravel-todo-api || true

# Create Kubernetes secrets
echo "Creating Kubernetes secrets..."
kubectl create secret generic laravel-todo-api-secrets \
  --namespace laravel-todo-api \
  --from-literal=db-host=$DB_HOST \
  --from-literal=db-name=$DB_DATABASE \
  --from-literal=db-username=$DB_USERNAME \
  --from-literal=db-password=$DB_PASSWORD \
  --dry-run=client -o yaml | kubectl apply -f -

# Create ConfigMap
echo "Creating ConfigMap..."
kubectl create configmap laravel-todo-api-config \
  --namespace laravel-todo-api \
  --from-literal=APP_NAME="Laravel Todo API" \
  --from-literal=APP_ENV="production" \
  --from-literal=APP_DEBUG="false" \
  --from-literal=APP_URL="https://api.example.com" \
  --from-literal=LOG_CHANNEL="stderr" \
  --dry-run=client -o yaml | kubectl apply -f -

# Update deployment.yaml with AWS account ID
echo "Updating deployment.yaml with AWS account ID..."
sed "s/\${AWS_ACCOUNT_ID}/$AWS_ACCOUNT_ID/g" k8s/deployment.yaml > k8s/deployment-updated.yaml

# Apply Kubernetes manifests
echo "Applying Kubernetes manifests..."
kubectl apply -f k8s/deployment-updated.yaml -n laravel-todo-api
kubectl apply -f k8s/service.yaml -n laravel-todo-api
kubectl apply -f k8s/ingress.yaml -n laravel-todo-api
kubectl apply -f k8s/hpa.yaml -n laravel-todo-api

# Wait for deployment to be ready
echo "Waiting for deployment to be ready..."
kubectl rollout status deployment/laravel-todo-api -n laravel-todo-api

# Run database migrations
echo "Running database migrations..."
POD_NAME=$(kubectl get pods -l app=laravel-todo-api -n laravel-todo-api -o jsonpath="{.items[0].metadata.name}")
kubectl exec -it $POD_NAME -n laravel-todo-api -- php artisan migrate --force

# Get ALB URL
echo "Waiting for ALB to be provisioned..."
sleep 60
ALB_URL=$(kubectl get ingress laravel-todo-api-ingress -n laravel-todo-api -o jsonpath="{.status.loadBalancer.ingress[0].hostname}")

echo "Deployment complete!"
echo "Application is available at: http://$ALB_URL"
