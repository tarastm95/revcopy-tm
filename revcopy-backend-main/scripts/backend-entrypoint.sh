#!/bin/bash
# Backend entrypoint script for RevCopy production deployment

set -e

# Wait for database to be ready
echo "Waiting for database to be ready..."
while ! nc -z postgres 5432; do
  echo "Waiting for PostgreSQL..."
  sleep 2
done
echo "PostgreSQL is ready!"

# Wait for Redis to be ready
echo "Waiting for Redis to be ready..."
while ! nc -z redis 6379; do
  echo "Waiting for Redis..."
  sleep 1
done
echo "Redis is ready!"

# Run database migrations
echo "Running database migrations..."
python -m alembic upgrade head || echo "Migration failed or no migrations to run"

# Start the application
echo "Starting FastAPI application..."
exec "$@" 