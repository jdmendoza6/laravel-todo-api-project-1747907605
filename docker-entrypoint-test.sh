#!/bin/bash
set -e

# Skip MySQL connection check for testing
echo "Starting services..."

# Start supervisord
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
