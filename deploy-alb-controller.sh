#!/bin/bash
set -e

# Configuration
AWS_REGION="ap-southeast-1"
CLUSTER_NAME="laravel-todo-api-cluster"

# Get VPC ID from the cluster
VPC_ID=$(aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION --query "cluster.resourcesVpcConfig.vpcId" --output text)

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

# Check if AWS Load Balancer Controller is already installed
if kubectl get deployment aws-load-balancer-controller -n kube-system &> /dev/null; then
  echo "AWS Load Balancer Controller is already installed. Removing it first..."
  kubectl delete deployment aws-load-balancer-controller -n kube-system
fi

# Install AWS Load Balancer Controller
echo "Installing AWS Load Balancer Controller..."
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

echo "AWS Load Balancer Controller installed successfully!"
