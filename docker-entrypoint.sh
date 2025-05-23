#!/bin/bash
set -e

# Wait for MySQL to be ready
echo "Waiting for MySQL..."
while ! mysql -h "$DB_HOST" -u "$DB_USERNAME" -p"$DB_PASSWORD" -e "SELECT 1" >/dev/null 2>&1; do
    echo "MySQL connection failed, retrying..."
    sleep 2
done
echo "MySQL is up and running!"

# Run migrations and seed the database
php artisan migrate --force
php artisan db:seed --force

# Start supervisord
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
