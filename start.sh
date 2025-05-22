#!/bin/bash

# This script is used to start the Laravel application inside the Docker container

# Copy environment file if it doesn't exist
if [ ! -f .env ]; then
    cp .env.example .env
    php artisan key:generate
fi

# Run migrations
php artisan migrate --force

# Start Apache
apache2-foreground