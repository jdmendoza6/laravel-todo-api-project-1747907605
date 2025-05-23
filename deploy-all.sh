#!/bin/bash
set -e

echo "Starting full deployment process..."

# Step 1: Deploy EKS cluster
echo "Step 1: Deploying EKS cluster..."
./deploy-eks-cluster.sh

# Step 2: Deploy ALB Controller
echo "Step 2: Deploying ALB Controller..."
./deploy-alb-controller.sh

# Step 3: Deploy application
echo "Step 3: Deploying application..."
./deploy-app.sh

echo "Full deployment process completed successfully!"
