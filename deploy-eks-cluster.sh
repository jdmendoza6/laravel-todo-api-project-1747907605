#!/bin/bash
set -e

# Configuration
AWS_REGION="ap-southeast-1"
CLUSTER_NAME="laravel-todo-api-cluster"

echo "Creating EKS cluster: $CLUSTER_NAME"
echo "This may take 15-20 minutes to complete..."

# Create EKS cluster using eksctl
eksctl create cluster \
  --name $CLUSTER_NAME \
  --region $AWS_REGION \
  --version 1.28 \
  --nodegroup-name laravel-todo-api-nodes \
  --node-type t3.small \
  --nodes 2 \
  --nodes-min 2 \
  --nodes-max 4 \
  --with-oidc \
  --managed

echo "EKS cluster created successfully!"

# Update kubeconfig
aws eks update-kubeconfig --name $CLUSTER_NAME --region $AWS_REGION

# Get cluster info
echo "Cluster information:"
kubectl cluster-info

# Get nodes
echo "Cluster nodes:"
kubectl get nodes

echo "EKS cluster deployment complete!"
