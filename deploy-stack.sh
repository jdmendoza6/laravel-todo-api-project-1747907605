#!/bin/bash

# This script deploys the CloudFormation stack for the Laravel Todo API
# Run this after pushing the Docker image to ECR

# Set variables
AWS_REGION="ap-southeast-1"
STACK_NAME="laravel-todo-api-ecs"
TEMPLATE_FILE="cloudformation/ecs-service.yml"
PARAMS_FILE="cloudformation/ecs-params.json"

# Deploy the CloudFormation stack
echo "Deploying CloudFormation stack $STACK_NAME..."
aws cloudformation deploy \
  --template-file $TEMPLATE_FILE \
  --stack-name $STACK_NAME \
  --parameter-overrides file://$PARAMS_FILE \
  --region $AWS_REGION \
  --capabilities CAPABILITY_IAM

# Check if deployment was successful
if [ $? -eq 0 ]; then
  echo "Deployment successful!"
  
  # Get the ALB URL
  ALB_URL=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $AWS_REGION \
    --query "Stacks[0].Outputs[?OutputKey=='ServiceURL'].OutputValue" \
    --output text)
  
  echo "Your Laravel Todo API is available at: $ALB_URL"
else
  echo "Deployment failed. Check the CloudFormation events for more details."
fi
