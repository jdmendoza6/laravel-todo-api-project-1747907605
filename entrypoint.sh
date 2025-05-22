#!/bin/bash

# Wait for MySQL to be ready
echo "Waiting for MySQL..."
until nc -z -v -w30 db 3306
do
  echo "Waiting for database connection..."
  sleep 5
done

# Run setup script
bash /var/www/html/setup.sh

# Start Apache
apache2-foreground