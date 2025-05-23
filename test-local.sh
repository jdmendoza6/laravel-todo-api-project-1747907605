#!/bin/bash
set -e

echo "Setting up local Kubernetes environment for testing Laravel Todo API"

# Check if minikube is installed
if ! command -v minikube &> /dev/null; then
    echo "Minikube not found. Installing..."
    curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
    sudo install minikube-linux-amd64 /usr/local/bin/minikube
    rm minikube-linux-amd64
fi

# Start minikube if not running
if ! minikube status | grep -q "Running"; then
    echo "Starting Minikube..."
    minikube start
fi

# Enable ingress addon
echo "Enabling Ingress addon..."
minikube addons enable ingress

# Set up local Docker environment to use Minikube's Docker daemon
echo "Configuring Docker to use Minikube's Docker daemon..."
eval $(minikube docker-env)

# Build Docker image directly in Minikube's Docker
echo "Building Docker image in Minikube..."
docker build -t laravel-todo-api:local -f Dockerfile.eks .

# Set up local MySQL database
echo "Setting up local MySQL database..."
if ! docker ps | grep -q "mysql-local"; then
    echo "Starting MySQL container..."
    docker run --name mysql-local \
        -e MYSQL_ROOT_PASSWORD=password \
        -e MYSQL_DATABASE=laravel_todo_api \
        -p 3306:3306 \
        -d mysql:8.0
    
    # Wait for MySQL to be ready
    echo "Waiting for MySQL to be ready..."
    sleep 20
fi

# Get MySQL container IP
MYSQL_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' mysql-local)
echo "MySQL is running at IP: $MYSQL_IP"

# Create namespace
echo "Creating Kubernetes namespace..."
kubectl create namespace laravel-todo-api 2>/dev/null || true

# Create ConfigMap
echo "Creating ConfigMap..."
kubectl create configmap laravel-todo-api-config \
  --namespace laravel-todo-api \
  --from-literal=APP_NAME="Laravel Todo API" \
  --from-literal=APP_ENV="local" \
  --from-literal=APP_DEBUG="true" \
  --from-literal=APP_URL="http://localhost" \
  --from-literal=LOG_CHANNEL="stderr" \
  --dry-run=client -o yaml | kubectl apply -f -

# Create Secret
echo "Creating Secret..."
kubectl create secret generic laravel-todo-api-secrets \
  --namespace laravel-todo-api \
  --from-literal=db-host="$MYSQL_IP" \
  --from-literal=db-name="laravel_todo_api" \
  --from-literal=db-username="root" \
  --from-literal=db-password="password" \
  --dry-run=client -o yaml | kubectl apply -f -

# Create a modified deployment file for local testing
echo "Creating local deployment file..."
cat > k8s/deployment-local.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: laravel-todo-api
  labels:
    app: laravel-todo-api
spec:
  replicas: 1
  selector:
    matchLabels:
      app: laravel-todo-api
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: laravel-todo-api
    spec:
      containers:
      - name: laravel-todo-api
        image: laravel-todo-api:local
        imagePullPolicy: Never
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        env:
        - name: APP_NAME
          valueFrom:
            configMapKeyRef:
              name: laravel-todo-api-config
              key: APP_NAME
        - name: APP_ENV
          valueFrom:
            configMapKeyRef:
              name: laravel-todo-api-config
              key: APP_ENV
        - name: APP_DEBUG
          valueFrom:
            configMapKeyRef:
              name: laravel-todo-api-config
              key: APP_DEBUG
        - name: APP_URL
          valueFrom:
            configMapKeyRef:
              name: laravel-todo-api-config
              key: APP_URL
        - name: DB_CONNECTION
          value: "mysql"
        - name: DB_HOST
          valueFrom:
            secretKeyRef:
              name: laravel-todo-api-secrets
              key: db-host
        - name: DB_PORT
          value: "3306"
        - name: DB_DATABASE
          valueFrom:
            secretKeyRef:
              name: laravel-todo-api-secrets
              key: db-name
        - name: DB_USERNAME
          valueFrom:
            secretKeyRef:
              name: laravel-todo-api-secrets
              key: db-username
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: laravel-todo-api-secrets
              key: db-password
        - name: LOG_CHANNEL
          valueFrom:
            configMapKeyRef:
              name: laravel-todo-api-config
              key: LOG_CHANNEL
        livenessProbe:
          httpGet:
            path: /api/health
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
        readinessProbe:
          httpGet:
            path: /api/health
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
EOF

# Apply Kubernetes manifests
echo "Applying Kubernetes manifests..."
kubectl apply -f k8s/deployment-local.yaml -n laravel-todo-api
kubectl apply -f k8s/service.yaml -n laravel-todo-api

# Wait for deployment to be ready
echo "Waiting for deployment to be ready..."
kubectl rollout status deployment/laravel-todo-api -n laravel-todo-api

# Run database migrations
echo "Running database migrations..."
POD_NAME=$(kubectl get pods -l app=laravel-todo-api -n laravel-todo-api -o jsonpath="{.items[0].metadata.name}")
kubectl exec -it $POD_NAME -n laravel-todo-api -- php artisan migrate --force

# Start port forwarding
echo "Starting port forwarding..."
echo "The Laravel Todo API will be available at http://localhost:8080"
echo "Press Ctrl+C to stop port forwarding"
kubectl port-forward svc/laravel-todo-api 8080:80 -n laravel-todo-api
