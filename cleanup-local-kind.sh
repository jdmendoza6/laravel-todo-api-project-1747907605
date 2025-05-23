#!/bin/bash
set -e

echo "Cleaning up local Kind Kubernetes environment for Laravel Todo API"

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

# Option to delete Kind cluster
read -p "Do you want to delete the Kind cluster? (y/n): " delete_kind
if [[ $delete_kind == "y" || $delete_kind == "Y" ]]; then
    echo "Deleting Kind cluster..."
    kind delete cluster --name laravel-todo-api
    echo "Kind cluster deleted."
else
    echo "Kind cluster preserved."
fi

echo "Cleanup complete!"
