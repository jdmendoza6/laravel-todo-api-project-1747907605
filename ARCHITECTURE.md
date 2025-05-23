# Laravel Todo API - Architecture Overview

This document provides an overview of the architecture for the Laravel Todo API application deployed on AWS.

## Application Architecture

The Laravel Todo API is a RESTful API built with Laravel, a PHP web application framework. The application follows the MVC (Model-View-Controller) pattern and provides endpoints for managing todo items.

### Key Components

- **Controllers**: Handle HTTP requests and return responses
- **Models**: Define the data structure and interact with the database
- **Routes**: Define the API endpoints
- **Migrations**: Define the database schema

## AWS Deployment Architecture

### Option 1: ECS Architecture

![ECS Architecture](https://d1.awsstatic.com/diagrams/product-page-diagrams/product-page-diagram_ECS_1.86ebd8c223ec8b55aa1903c423fbe4e672f3daf7.png)

#### Components

1. **Amazon ECR**: Stores Docker images for the application
2. **Amazon ECS**: Runs the application containers
3. **Application Load Balancer**: Routes traffic to the ECS service
4. **Amazon RDS**: Provides a managed MySQL database
5. **CloudFormation**: Manages the infrastructure as code

#### Flow

1. User requests are sent to the Application Load Balancer
2. ALB routes requests to the ECS service
3. ECS service runs the application containers
4. Application containers connect to the RDS database
5. Responses are returned to the user

### Option 2: EKS Architecture

![EKS Architecture](https://d1.awsstatic.com/product-marketing/EKS/product-page-diagram_Amazon-EKS%402x.0d872d6d7d857b10b5b7c12e98e7d2fefad57920.png)

#### Components

1. **Amazon ECR**: Stores Docker images for the application
2. **Amazon EKS**: Manages the Kubernetes cluster
3. **AWS Load Balancer Controller**: Manages the ALB for Kubernetes
4. **Application Load Balancer**: Routes traffic to the Kubernetes service
5. **Amazon RDS**: Provides a managed MySQL database
6. **Kubernetes Resources**:
   - **Deployment**: Manages the application pods
   - **Service**: Exposes the application within the cluster
   - **Ingress**: Configures the ALB for external access
   - **HorizontalPodAutoscaler**: Scales the application based on load
   - **ConfigMap & Secrets**: Manage application configuration

#### Flow

1. User requests are sent to the Application Load Balancer
2. ALB routes requests to the Kubernetes service
3. Kubernetes service routes requests to the application pods
4. Application pods connect to the RDS database
5. Responses are returned to the user

## Security Considerations

1. **Network Security**:
   - VPC with public and private subnets
   - Security groups for controlling access
   - Private subnets for database

2. **Application Security**:
   - HTTPS for encrypted communication
   - Input validation and sanitization
   - Proper error handling

3. **Database Security**:
   - Credentials stored in Kubernetes Secrets or AWS Secrets Manager
   - Database in private subnet
   - Security group restricting access

## Scalability

### ECS Scalability

- ECS Service Auto Scaling based on CPU and memory utilization
- Application Load Balancer for distributing traffic

### EKS Scalability

- Horizontal Pod Autoscaler for scaling pods based on CPU and memory utilization
- Cluster Autoscaler for scaling worker nodes
- Application Load Balancer for distributing traffic

## Monitoring and Logging

- Health check endpoint for monitoring application health
- CloudWatch for monitoring AWS resources
- CloudWatch Logs for centralized logging
- Kubernetes metrics for monitoring application performance

## Cost Optimization

- Use of t3.small instances for cost-effective compute
- Auto-scaling to match capacity with demand
- RDS instance sized appropriately for the workload
- Shared ALB for multiple services
