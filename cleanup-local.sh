#!/bin/bash
set -e

echo "Cleaning up local Kubernetes environment for Laravel Todo API"

# Delete Kubernetes resources
echo "Deleting Kubernetes resources..."
kubectl delete deployment/laravel-todo-api -n laravel-todo-api 2>/dev/null || true
kubectl delete service/laravel-todo-api -n laravel-todo-api 2>/dev/null || true
kubectl delete configmap/laravel-todo-api-config -n laravel-todo-api 2>/dev/null || true
kubectl delete secret/laravel-todo-api-secrets -n laravel-todo-api 2>/dev/null || true

# Option to delete MySQL container
read -p "Do you want to delete the MySQL container? (y/n): " delete_mysql
if [[ $delete_mysql == "y" || $delete_mysql == "Y" ]]; then
    echo "Stopping and removing MySQL container..."
    docker stop mysql-local 2>/dev/null || true
    docker rm mysql-local 2>/dev/null || true
    echo "MySQL container removed."
else
    echo "MySQL container preserved."
fi

# Option to stop Minikube
read -p "Do you want to stop Minikube? (y/n): " stop_minikube
if [[ $stop_minikube == "y" || $stop_minikube == "Y" ]]; then
    echo "Stopping Minikube..."
    minikube stop
    echo "Minikube stopped."
else
    echo "Minikube is still running."
fi

echo "Cleanup complete!"
