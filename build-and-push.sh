#!/bin/bash

# This script builds and pushes the Docker image to ECR
# Run this script on a system where you have Docker permissions

# Set variables
AWS_REGION="ap-southeast-1"
ECR_REPO="laravel-todo-api"
AWS_ACCOUNT_ID="029062221755"
IMAGE_TAG="latest"

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Build the Docker image
echo "Building Docker image..."
docker build -t $ECR_REPO .

# Tag the image
echo "Tagging image..."
docker tag $ECR_REPO:$IMAGE_TAG $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO:$IMAGE_TAG

# Push the image to ECR
echo "Pushing image to ECR..."
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO:$IMAGE_TAG

echo "Done! Image pushed to $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO:$IMAGE_TAG"
