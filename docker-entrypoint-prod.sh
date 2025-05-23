#!/bin/bash
set -e

# Wait for MySQL to be ready
echo "Waiting for MySQL..."
while ! php -r "try { new PDO('mysql:host=\$DB_HOST;port=\$DB_PORT', '\$DB_USERNAME', '\$DB_PASSWORD'); echo 'Connected successfully'; } catch (PDOException \$e) { exit(1); }" > /dev/null 2>&1; do
    echo "MySQL connection failed, retrying..."
    sleep 2
done
echo "MySQL is up and running!"

# Run migrations
php artisan migrate --force

# Start supervisord
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
