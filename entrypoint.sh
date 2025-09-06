#!/bin/sh

# Exit immediately if a command exits with a non-zero status ('e')
# or if an unset variable is used ('u').
set -eu

# Wait for the database to be ready
DB_HOST=${DB_HOST:-db}
DB_PORT=${DB_PORT:-5432}
WAIT_TIMEOUT=${WAIT_TIMEOUT:-60}

echo "Waiting for database connection at ${DB_HOST}:${DB_PORT}..."

count=0
while ! python -c "import socket; socket.create_connection(('${DB_HOST}', ${DB_PORT}), timeout=1).close()" 2>/dev/null; do
    count=$((count + 1))
    if [ ${count} -ge ${WAIT_TIMEOUT} ]; then
        echo "Error: Timed out waiting for database connection at ${DB_HOST}:${DB_PORT}" >&2
        exit 1
    fi
    echo "Waiting for database connection... (${count}/${WAIT_TIMEOUT}s)"
    sleep 1
done

echo "Database is ready."

# Apply database migrations
echo "Applying database migrations..."
python manage.py migrate --noinput

# Collect static files if required
if [ "${COLLECT_STATIC:-0}" = "1" ]; then
    echo "Collecting static files..."
    python manage.py collectstatic --noinput
fi

# Start the application with Gunicorn for production
echo "Starting Gunicorn server..."
exec python -m gunicorn config.wsgi:application --bind 0.0.0.0:8000
