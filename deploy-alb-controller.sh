#!/bin/bash
set -e

# Configuration
AWS_REGION="ap-southeast-1"
CLUSTER_NAME="laravel-todo-api-cluster"

# Get VPC ID from the cluster
echo "Getting VPC ID from the cluster..."
VPC_ID=$(aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION --query "cluster.resourcesVpcConfig.vpcId" --output text)
echo "VPC ID: $VPC_ID"

# Create IAM OIDC provider
echo "Creating IAM OIDC provider..."
eksctl utils associate-iam-oidc-provider --cluster $CLUSTER_NAME --region $AWS_REGION --approve

# Create IAM policy for ALB Ingress Controller
echo "Creating IAM policy for ALB Ingress Controller..."
POLICY_ARN=$(aws iam list-policies --query "Policies[?PolicyName=='AWSLoadBalancerControllerIAMPolicy'].Arn" --output text)

if [ -z "$POLICY_ARN" ]; then
  echo "Downloading ALB Controller policy..."
  curl -o alb-controller-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

  echo "Creating IAM policy..."
  POLICY_ARN=$(aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://alb-controller-policy.json \
    --query "Policy.Arn" \
    --output text)
  
  rm alb-controller-policy.json
fi

echo "Policy ARN: $POLICY_ARN"

# Create service account
echo "Creating service account for ALB Ingress Controller..."
eksctl create iamserviceaccount \
  --cluster $CLUSTER_NAME \
  --namespace kube-system \
  --name aws-load-balancer-controller \
  --attach-policy-arn $POLICY_ARN \
  --override-existing-serviceaccounts \
  --region $AWS_REGION \
  --approve

# Install cert-manager
echo "Installing cert-manager..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.1/cert-manager.yaml

# Wait for cert-manager to be ready
echo "Waiting for cert-manager to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager -n cert-manager
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-cainjector -n cert-manager
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-webhook -n cert-manager

# Install ALB Ingress Controller using Helm
echo "Adding Helm repository for ALB Ingress Controller..."
helm repo add eks https://aws.github.io/eks-charts
helm repo update

echo "Installing ALB Ingress Controller..."
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=$AWS_REGION \
  --set vpcId=$VPC_ID \
  --namespace kube-system

# Wait for ALB Ingress Controller to be ready
echo "Waiting for ALB Ingress Controller to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/aws-load-balancer-controller -n kube-system

echo "ALB Ingress Controller deployment complete!"
