#!/bin/bash

# PostgreSQL Database Restore Script
# Usage: ./restore-database.sh <backup_file>

set -e

# Configuration
DB_NAME="saas_platform"
DB_USER="postgres"

# Check if backup file is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <backup_file>"
    echo ""
    echo "Available backups:"
    ls -lht backups/saas_platform_*.sql.gz 2>/dev/null | head -10 || echo "No backups found"
    exit 1
fi

BACKUP_FILE="$1"

# Check if backup file exists
if [ ! -f "$BACKUP_FILE" ]; then
    echo "❌ Error: Backup file not found: $BACKUP_FILE"
    exit 1
fi

echo "⚠️  WARNING: This will REPLACE the current database!"
echo "Database: $DB_NAME"
echo "Backup file: $BACKUP_FILE"
echo ""
read -p "Are you sure you want to continue? (yes/no): " -r
echo

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Restore cancelled."
    exit 0
fi

echo "Starting database restore..."

# Stop all services that connect to the database
echo "Stopping backend services..."
docker-compose stop auth-service user-service group-service scoring-service leaderboard-service api-gateway

# Drop existing connections and recreate database
echo "Recreating database..."
docker-compose exec -T postgres psql -U "$DB_USER" -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$DB_NAME' AND pid <> pg_backend_pid();"
docker-compose exec -T postgres psql -U "$DB_USER" -c "DROP DATABASE IF EXISTS $DB_NAME;"
docker-compose exec -T postgres psql -U "$DB_USER" -c "CREATE DATABASE $DB_NAME;"

# Restore the backup
echo "Restoring backup..."
if [[ "$BACKUP_FILE" == *.gz ]]; then
    gunzip -c "$BACKUP_FILE" | docker-compose exec -T postgres psql -U "$DB_USER" "$DB_NAME"
else
    docker-compose exec -T postgres psql -U "$DB_USER" "$DB_NAME" < "$BACKUP_FILE"
fi

# Check if restore was successful
if [ $? -eq 0 ]; then
    echo "✅ Database restore completed successfully!"
else
    echo "❌ Database restore failed!"
    exit 1
fi

# Restart services
echo "Restarting backend services..."
docker-compose start auth-service user-service group-service scoring-service leaderboard-service api-gateway

echo ""
echo "Restore process completed!"
echo "Services are starting up. Please wait a moment for them to be ready."
