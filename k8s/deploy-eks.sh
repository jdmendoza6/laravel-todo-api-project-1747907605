#!/bin/bash
set -e

# Configuration
AWS_REGION="ap-southeast-1"
CLUSTER_NAME="laravel-todo-api-cluster"
ECR_REPO_NAME="laravel-todo-api"
APP_NAME="laravel-todo-api"

# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)

# Create EC2 key pair if it doesn't exist
if ! aws ec2 describe-key-pairs --key-names eks-keypair --region $AWS_REGION &> /dev/null; then
  echo "Creating EC2 key pair 'eks-keypair'..."
  aws ec2 create-key-pair --key-name eks-keypair --query "KeyMaterial" --output text > eks-keypair.pem
  chmod 600 eks-keypair.pem
  echo "Key pair created and saved to eks-keypair.pem"
fi

# Create EKS cluster using eksctl
echo "Creating EKS cluster..."
eksctl create cluster -f k8s/cluster.yaml

# Get VPC ID from the cluster
VPC_ID=$(aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION --query "cluster.resourcesVpcConfig.vpcId" --output text)

# Create RDS database
echo "Creating RDS database..."
SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=*Private*" --query "Subnets[*].SubnetId" --output text | tr '\t' ',')
aws cloudformation create-stack \
  --stack-name laravel-todo-api-rds \
  --template-body file://k8s/rds.yaml \
  --parameters \
    ParameterKey=VpcId,ParameterValue=$VPC_ID \
    ParameterKey=SubnetIds,ParameterValue="$SUBNET_IDS" \
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
DB_HOST_BASE64=$(echo -n $DB_HOST | base64 -w 0)
DB_NAME_BASE64=$(echo -n "laravel_todo_api" | base64 -w 0)
DB_USERNAME_BASE64=$(echo -n "admin" | base64 -w 0)
DB_PASSWORD_BASE64=$(echo -n "Password123" | base64 -w 0)

cat > k8s/secrets-updated.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: laravel-todo-api-secrets
  namespace: default
type: Opaque
data:
  db-host: $DB_HOST_BASE64
  db-name: $DB_NAME_BASE64
  db-username: $DB_USERNAME_BASE64
  db-password: $DB_PASSWORD_BASE64
EOF

# Update deployment.yaml with AWS account ID
sed "s/\${AWS_ACCOUNT_ID}/$AWS_ACCOUNT_ID/g" k8s/deployment.yaml > k8s/deployment-updated.yaml

# Install AWS Load Balancer Controller using Helm
echo "Installing AWS Load Balancer Controller..."

# Check if Helm is installed, if not install it
if ! command -v helm &> /dev/null; then
  echo "Installing Helm..."
  curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
  chmod 700 get_helm.sh
  ./get_helm.sh
fi

# Add EKS Helm repository
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Install AWS Load Balancer Controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=$AWS_REGION \
  --set vpcId=$VPC_ID

# Wait for the controller to be ready
echo "Waiting for AWS Load Balancer Controller to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/aws-load-balancer-controller -n kube-system

# Apply Kubernetes manifests
echo "Applying Kubernetes manifests..."
kubectl apply -f k8s/secrets-updated.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/deployment-updated.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/ingress.yaml
kubectl apply -f k8s/hpa.yaml

# Wait for pods to be ready
echo "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app=$APP_NAME --timeout=300s

# Run database migrations
echo "Running database migrations..."
kubectl exec -it $(kubectl get pods -l app=$APP_NAME -o jsonpath="{.items[0].metadata.name}") -- php artisan migrate --force

# Get ALB URL
echo "Waiting for ALB to be provisioned..."
sleep 60
ALB_URL=$(kubectl get ingress laravel-todo-api-ingress -o jsonpath="{.status.loadBalancer.ingress[0].hostname}")

echo "Deployment complete!"
echo "Application is available at: http://$ALB_URL"
echo "Note: DNS propagation may take some time. You can verify the application is working by running:"
echo "kubectl exec -it \$(kubectl get pods -l app=$APP_NAME -o jsonpath=\"{.items[0].metadata.name}\") -- curl -s http://localhost/api/health"
