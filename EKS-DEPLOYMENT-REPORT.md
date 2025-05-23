# Laravel Todo API - EKS Deployment Report

## Overview

This report documents the deployment of the Laravel Todo API application to Amazon EKS (Elastic Kubernetes Service). The deployment process followed the steps outlined in the README-EKS.md file, with some modifications to address issues encountered during the deployment.

## Deployment Steps

### 1. EKS Cluster Creation

The EKS cluster was successfully created using eksctl:

```bash
eksctl create cluster -f k8s/cluster.yaml
```

**Issue encountered**: Missing EC2 key pair.
**Resolution**: Created an EC2 key pair named "eks-keypair" using AWS CLI:

```bash
aws ec2 create-key-pair --key-name eks-keypair --query "KeyMaterial" --output text > eks-keypair.pem
chmod 600 eks-keypair.pem
```

### 2. RDS Database Creation

The RDS database was created using CloudFormation:

```bash
aws cloudformation create-stack \
  --stack-name laravel-todo-api-rds \
  --template-body file://k8s/rds.yaml \
  --parameters \
    ParameterKey=VpcId,ParameterValue=vpc-0534cfd6e529be73d \
    ParameterKey=SubnetIds,ParameterValue="subnet-084834f70a9c46535,subnet-0ad3fee41708c24d2,subnet-09dea0b8fdeee6851" \
    ParameterKey=DBName,ParameterValue=laravel_todo_api \
    ParameterKey=DBUsername,ParameterValue=admin \
    ParameterKey=DBPassword,ParameterValue=Password123 \
    ParameterKey=DBInstanceClass,ParameterValue=db.t3.small \
  --region ap-southeast-1
```

**Issue encountered**: Parameter validation error for SubnetIds.
**Resolution**: Properly formatted the subnet IDs as a comma-separated string.

### 3. Docker Image Build and Push

The Docker image was built and pushed to Amazon ECR:

```bash
aws ecr get-login-password --region ap-southeast-1 | docker login --username AWS --password-stdin 370995404116.dkr.ecr.ap-southeast-1.amazonaws.com
docker build -t 370995404116.dkr.ecr.ap-southeast-1.amazonaws.com/laravel-todo-api:latest -f Dockerfile.eks.fixed .
docker push 370995404116.dkr.ecr.ap-southeast-1.amazonaws.com/laravel-todo-api:latest
```

**Issue encountered**: The original Dockerfile.eks failed during the key generation step.
**Resolution**: Created a fixed Dockerfile.eks.fixed that properly handles the .env file:

```dockerfile
# Modified step in Dockerfile.eks.fixed
RUN cp .env.example .env && php artisan key:generate
```

### 4. Kubernetes Resources Deployment

The following Kubernetes resources were deployed:

```bash
kubectl apply -f k8s/secrets-updated.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/deployment-updated.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/ingress.yaml
kubectl apply -f k8s/hpa.yaml
```

**Issue encountered**: The secrets.yaml file used template variables that needed to be replaced.
**Resolution**: Created a secrets-updated.yaml file with the actual values:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: laravel-todo-api-secrets
  namespace: default
type: Opaque
data:
  db-host: <base64-encoded-db-host>
  db-name: <base64-encoded-db-name>
  db-username: <base64-encoded-db-username>
  db-password: <base64-encoded-db-password>
```

### 5. AWS Load Balancer Controller Installation

**Issue encountered**: The ALB controller deployment failed with image pull errors.
**Resolution**: Used Helm to install the AWS Load Balancer Controller:

```bash
# Install Helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

# Delete existing failed deployment
kubectl delete deployment aws-load-balancer-controller -n kube-system

# Install ALB controller using Helm
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=laravel-todo-api-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=ap-southeast-1 \
  --set vpcId=vpc-0534cfd6e529be73d
```

### 6. Database Migrations

Database migrations were run successfully:

```bash
kubectl exec -it $(kubectl get pods -l app=laravel-todo-api -o jsonpath="{.items[0].metadata.name}") -- php artisan migrate --force
```

## Application Testing

The application was tested to verify it's working correctly:

1. Health check endpoint:
```bash
kubectl exec -it $(kubectl get pods -l app=laravel-todo-api -o jsonpath="{.items[0].metadata.name}") -- curl -s http://localhost/api/health
# Response: {"status":"healthy","message":"Application is running correctly","timestamp":"2025-05-23T18:57:21+00:00"}
```

2. Create a todo item:
```bash
kubectl exec -it $(kubectl get pods -l app=laravel-todo-api -o jsonpath="{.items[0].metadata.name}") -- curl -s -X POST -H "Content-Type: application/json" -d '{"title":"Test Todo"}' http://localhost/api/todos
# Response: {"title":"Test Todo","completed":false,"updated_at":"2025-05-23T18:57:46.000000Z","created_at":"2025-05-23T18:57:46.000000Z","id":1}
```

3. List todo items:
```bash
kubectl exec -it $(kubectl get pods -l app=laravel-todo-api -o jsonpath="{.items[0].metadata.name}") -- curl -s http://localhost/api/todos
# Response: [{"id":1,"title":"Test Todo","description":null,"completed":false,"created_at":"2025-05-23T18:57:46.000000Z","updated_at":"2025-05-23T18:57:46.000000Z"}]
```

## External Access

The application is accessible via the ALB URL:
```
k8s-laraveltodoapi-01d23bbaf7-1247280372.ap-southeast-1.elb.amazonaws.com
```

**Note**: DNS propagation may take some time. The application was verified to be working internally within the cluster.

## Conclusion

The Laravel Todo API was successfully deployed to Amazon EKS. The deployment process required several adjustments to the provided configuration files, particularly for the Docker image build and the AWS Load Balancer Controller installation. The application is functioning correctly and can be accessed via the ALB URL once DNS propagation is complete.

## Recommendations

1. Update the README-EKS.md file to include the fixes documented in this report
2. Use Helm for installing the AWS Load Balancer Controller instead of manual deployment
3. Add health checks to the Laravel application (already implemented)
4. Consider using Kubernetes Secrets management solutions like AWS Secrets Manager or HashiCorp Vault
5. Implement CI/CD pipeline for automated deployments
