#!/bin/bash
set -e

# Start services immediately without waiting for MySQL
echo "Starting services..."

# Start supervisord
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
