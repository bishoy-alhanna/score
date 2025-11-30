#!/bin/bash

# PostgreSQL Database Backup Script
# Usage: ./backup-database.sh

set -e

# Configuration
BACKUP_DIR="./backups"
DB_NAME="saas_platform"
DB_USER="postgres"
RETENTION_DAYS=30

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Timestamp for backup file
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/saas_platform_$TIMESTAMP.sql.gz"

echo "Starting PostgreSQL backup..."
echo "Database: $DB_NAME"
echo "Backup file: $BACKUP_FILE"

# Create compressed backup
docker-compose exec -T postgres pg_dump -U "$DB_USER" "$DB_NAME" | gzip > "$BACKUP_FILE"

# Check if backup was successful
if [ $? -eq 0 ]; then
    BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    echo "✅ Backup completed successfully!"
    echo "Backup size: $BACKUP_SIZE"
    echo "Location: $BACKUP_FILE"
else
    echo "❌ Backup failed!"
    exit 1
fi

# Remove old backups (older than RETENTION_DAYS)
echo "Cleaning up old backups (older than $RETENTION_DAYS days)..."
find "$BACKUP_DIR" -name "saas_platform_*.sql.gz" -type f -mtime +$RETENTION_DAYS -delete

# List recent backups
echo ""
echo "Recent backups:"
ls -lht "$BACKUP_DIR"/saas_platform_*.sql.gz | head -5

echo ""
echo "Backup process completed!"
