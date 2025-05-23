#!/bin/bash
set -e

# Script to set up the database schema for Laravel Todo API

# Check if required parameters are provided
if [ "$#" -lt 3 ]; then
    echo "Usage: $0 <db-host> <db-user> <db-password> [db-name]"
    exit 1
fi

DB_HOST=$1
DB_USER=$2
DB_PASSWORD=$3
DB_NAME=${4:-"laravel_todo_api"}

# Install mysql client if not available
if ! command -v mysql &> /dev/null; then
    echo "MySQL client not found. Installing..."
    apt-get update && apt-get install -y default-mysql-client
fi

echo "Setting up database schema..."

# Create database if it doesn't exist
mysql -h $DB_HOST -u $DB_USER -p$DB_PASSWORD -e "CREATE DATABASE IF NOT EXISTS $DB_NAME;"

# Run Laravel migrations
echo "Running Laravel migrations..."
cd ..
php artisan migrate --force --database=mysql --env=production

# Seed the database with sample data if needed
echo "Seeding the database with sample data..."
php artisan db:seed --force --env=production

echo "Database setup complete!"
