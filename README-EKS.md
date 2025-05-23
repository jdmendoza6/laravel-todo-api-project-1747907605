# Laravel Todo API - EKS Deployment

This guide explains how to deploy the Laravel Todo API application to Amazon EKS (Elastic Kubernetes Service) with an Application Load Balancer (ALB) and a separate RDS database.

## Prerequisites

- AWS CLI configured with appropriate permissions
- kubectl installed
- eksctl installed
- Docker installed
- AWS account with access to EKS, ECR, RDS, and ALB services

## Architecture

The deployment consists of:

1. **EKS Cluster**: Managed Kubernetes cluster in AWS
2. **RDS MySQL Database**: Separate RDS instance for data persistence
3. **Application Load Balancer (ALB)**: For routing traffic to the application
4. **ECR Repository**: For storing Docker images
5. **Kubernetes Resources**:
   - Deployment: For running the Laravel application
   - Service: For internal networking
   - Ingress: For ALB configuration
   - HPA: For auto-scaling
   - ConfigMap & Secrets: For configuration

## Deployment Steps

### 1. Create the EKS Cluster

```bash
eksctl create cluster -f k8s/cluster.yaml
```

**Note**: The deployment script will automatically create an EC2 key pair named "eks-keypair" if it doesn't exist.

### 2. Create RDS Database

```bash
# Get VPC ID from the cluster
VPC_ID=$(aws eks describe-cluster --name laravel-todo-api-cluster --region ap-southeast-1 --query "cluster.resourcesVpcConfig.vpcId" --output text)

# Get subnet IDs
SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=*Private*" --query "Subnets[*].SubnetId" --output text | tr '\t' ',')

# Create RDS database
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
  --region ap-southeast-1
```

### 3. Build and Push Docker Image

```bash
# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)

# Login to ECR
aws ecr get-login-password --region ap-southeast-1 | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.ap-southeast-1.amazonaws.com

# Build and push Docker image
docker build -t $AWS_ACCOUNT_ID.dkr.ecr.ap-southeast-1.amazonaws.com/laravel-todo-api:latest -f Dockerfile.eks .
docker push $AWS_ACCOUNT_ID.dkr.ecr.ap-southeast-1.amazonaws.com/laravel-todo-api:latest
```

### 4. Install AWS Load Balancer Controller

```bash
# Install Helm if not already installed
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

# Add EKS Helm repository
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Install AWS Load Balancer Controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=laravel-todo-api-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=ap-southeast-1 \
  --set vpcId=$VPC_ID
```

### 5. Deploy Kubernetes Resources

```bash
# Create secrets
DB_HOST=$(aws cloudformation describe-stacks --stack-name laravel-todo-api-rds --query "Stacks[0].Outputs[?OutputKey=='DBEndpoint'].OutputValue" --output text --region ap-southeast-1)
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

# Update deployment with AWS account ID
sed "s/\${AWS_ACCOUNT_ID}/$AWS_ACCOUNT_ID/g" k8s/deployment.yaml > k8s/deployment-updated.yaml

# Apply Kubernetes resources
kubectl apply -f k8s/secrets-updated.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/deployment-updated.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/ingress.yaml
kubectl apply -f k8s/hpa.yaml
```

### 6. Run Database Migrations

```bash
kubectl exec -it $(kubectl get pods -l app=laravel-todo-api -o jsonpath="{.items[0].metadata.name}") -- php artisan migrate --force
```

## Automated Deployment

For convenience, an automated deployment script is provided:

```bash
./k8s/deploy-eks.sh
```

This script will:
1. Create an EC2 key pair if it doesn't exist
2. Create the EKS cluster
3. Create the RDS database
4. Build and push the Docker image
5. Install the AWS Load Balancer Controller using Helm
6. Deploy all Kubernetes resources
7. Run database migrations
8. Output the ALB URL for accessing the application

## Accessing the Application

After deployment, the application will be available at the ALB URL, which can be obtained with:

```bash
kubectl get ingress laravel-todo-api-ingress -o jsonpath="{.status.loadBalancer.ingress[0].hostname}"
```

**Note**: DNS propagation may take some time. You can verify the application is working by running:

```bash
kubectl exec -it $(kubectl get pods -l app=laravel-todo-api -o jsonpath="{.items[0].metadata.name}") -- curl -s http://localhost/api/health
```

## Cleanup

To delete all resources:

```bash
# Delete Kubernetes resources
kubectl delete -f k8s/hpa.yaml
kubectl delete -f k8s/ingress.yaml
kubectl delete -f k8s/service.yaml
kubectl delete -f k8s/deployment-updated.yaml
kubectl delete -f k8s/configmap.yaml
kubectl delete -f k8s/secrets-updated.yaml

# Delete AWS Load Balancer Controller
helm uninstall aws-load-balancer-controller -n kube-system

# Delete RDS database
aws cloudformation delete-stack --stack-name laravel-todo-api-rds

# Delete EKS cluster
eksctl delete cluster --name laravel-todo-api-cluster
```
