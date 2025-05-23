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

### 2. Create RDS Database

```bash
aws cloudformation create-stack --stack-name laravel-todo-api-rds --template-body file://k8s/rds.yaml --parameters ...
```

### 3. Build and Push Docker Image

```bash
docker build -t <account-id>.dkr.ecr.<region>.amazonaws.com/laravel-todo-api:latest -f Dockerfile.eks .
docker push <account-id>.dkr.ecr.<region>.amazonaws.com/laravel-todo-api:latest
```

### 4. Deploy Kubernetes Resources

```bash
kubectl apply -f k8s/secrets.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/ingress.yaml
kubectl apply -f k8s/hpa.yaml
```

### 5. Run Database Migrations

```bash
kubectl exec -it <pod-name> -- php artisan migrate --force
```

## Automated Deployment

For convenience, an automated deployment script is provided:

```bash
./k8s/deploy-eks.sh
```

This script will:
1. Create the EKS cluster
2. Create the RDS database
3. Build and push the Docker image
4. Deploy all Kubernetes resources
5. Run database migrations
6. Output the ALB URL for accessing the application

## Accessing the Application

After deployment, the application will be available at the ALB URL, which can be obtained with:

```bash
kubectl get ingress laravel-todo-api-ingress -o jsonpath="{.status.loadBalancer.ingress[0].hostname}"
```

## Cleanup

To delete all resources:

```bash
# Delete Kubernetes resources
kubectl delete -f k8s/hpa.yaml
kubectl delete -f k8s/ingress.yaml
kubectl delete -f k8s/service.yaml
kubectl delete -f k8s/deployment.yaml
kubectl delete -f k8s/configmap.yaml
kubectl delete -f k8s/secrets.yaml

# Delete RDS database
aws cloudformation delete-stack --stack-name laravel-todo-api-rds

# Delete EKS cluster
eksctl delete cluster --name laravel-todo-api-cluster
```
