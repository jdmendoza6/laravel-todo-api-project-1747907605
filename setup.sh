#!/bin/bash

# Install dependencies
composer install

# Set up environment file
cp .env.example .env
php artisan key:generate

# Run migrations
php artisan migrate

# Set permissions
chown -R www-data:www-data /var/www/html/storage
chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache