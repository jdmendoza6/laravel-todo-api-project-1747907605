#!/bin/bash
set -e

# Configuration
AWS_REGION="ap-southeast-1"
CLUSTER_NAME="laravel-todo-api-cluster"
ECR_REPO_NAME="laravel-todo-api"
APP_NAME="laravel-todo-api"

# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)

# Create EKS cluster using eksctl
echo "Creating EKS cluster..."
eksctl create cluster -f k8s/cluster.yaml

# Get VPC ID from the cluster
VPC_ID=$(aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION --query "cluster.resourcesVpcConfig.vpcId" --output text)

# Update ALB Ingress Controller configuration with VPC ID
sed -i "s/vpc-xxx/$VPC_ID/g" k8s/alb-ingress-controller.yaml

# Create RDS database
echo "Creating RDS database..."
aws cloudformation create-stack \
  --stack-name laravel-todo-api-rds \
  --template-body file://k8s/rds.yaml \
  --parameters \
    ParameterKey=VpcId,ParameterValue=$VPC_ID \
    ParameterKey=SubnetIds,ParameterValue=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=*Private*" --query "Subnets[*].SubnetId" --output text | tr '\t' ',') \
    ParameterKey=DBName,ParameterValue=laravel_todo_api \
    ParameterKey=DBUsername,ParameterValue=admin \
    ParameterKey=DBPassword,ParameterValue=Password123 \
    ParameterKey=DBInstanceClass,ParameterValue=db.t3.small \
  --region $AWS_REGION

# Wait for RDS stack to complete
echo "Waiting for RDS database to be created..."
aws cloudformation wait stack-create-complete --stack-name laravel-todo-api-rds --region $AWS_REGION

# Get RDS endpoint
DB_HOST=$(aws cloudformation describe-stacks --stack-name laravel-todo-api-rds --query "Stacks[0].Outputs[?OutputKey=='DBEndpoint'].OutputValue" --output text --region $AWS_REGION)

# Create ECR repository if it doesn't exist
aws ecr describe-repositories --repository-names $ECR_REPO_NAME --region $AWS_REGION || \
  aws ecr create-repository --repository-name $ECR_REPO_NAME --region $AWS_REGION

# Build and push Docker image
echo "Building and pushing Docker image..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
docker build -t $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO_NAME:latest -f Dockerfile.eks .
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO_NAME:latest

# Create Kubernetes secrets
echo "Creating Kubernetes secrets..."
DB_HOST_BASE64=$(echo -n $DB_HOST | base64)
DB_NAME_BASE64=$(echo -n "laravel_todo_api" | base64)
DB_USERNAME_BASE64=$(echo -n "admin" | base64)
DB_PASSWORD_BASE64=$(echo -n "Password123" | base64)

sed -e "s|\${DB_HOST_BASE64}|$DB_HOST_BASE64|g" \
    -e "s|\${DB_NAME_BASE64}|$DB_NAME_BASE64|g" \
    -e "s|\${DB_USERNAME_BASE64}|$DB_USERNAME_BASE64|g" \
    -e "s|\${DB_PASSWORD_BASE64}|$DB_PASSWORD_BASE64|g" \
    k8s/secrets.yaml > k8s/secrets-updated.yaml

# Update deployment.yaml with AWS account ID
sed -i "s/\${AWS_ACCOUNT_ID}/$AWS_ACCOUNT_ID/g" k8s/deployment.yaml

# Install AWS Load Balancer Controller
echo "Installing AWS Load Balancer Controller..."
kubectl apply -f k8s/alb-ingress-controller.yaml

# Apply Kubernetes manifests
echo "Applying Kubernetes manifests..."
kubectl apply -f k8s/secrets-updated.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/ingress.yaml
kubectl apply -f k8s/hpa.yaml

# Run database migrations
echo "Running database migrations..."
kubectl exec -it $(kubectl get pods -l app=$APP_NAME -o jsonpath="{.items[0].metadata.name}") -- php artisan migrate --force

# Get ALB URL
echo "Waiting for ALB to be provisioned..."
sleep 60
ALB_URL=$(kubectl get ingress laravel-todo-api-ingress -o jsonpath="{.status.loadBalancer.ingress[0].hostname}")

echo "Deployment complete!"
echo "Application is available at: http://$ALB_URL"
