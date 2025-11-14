#!/bin/bash

# Apply Schema Migration to Production
# This script fixes the database schema to support multi-organization architecture

set -e

echo "========================================="
echo "Schema Migration - Multi-Org Support"
echo "========================================="
echo ""

# Configuration
DB_CONTAINER="saas_postgres"
DB_NAME="saas_platform"
DB_USER="postgres"
MIGRATION_FILE="database/migration_fix_schema.sql"

# Check if migration file exists
if [ ! -f "$MIGRATION_FILE" ]; then
    echo "❌ Error: Migration file not found: $MIGRATION_FILE"
    exit 1
fi

# Check if Docker is running
if ! docker ps &> /dev/null; then
    echo "❌ Error: Docker is not running"
    exit 1
fi

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${DB_CONTAINER}$"; then
    echo "❌ Error: PostgreSQL container is not running"
    echo "Start it with: docker-compose up -d postgres"
    exit 1
fi

echo "⚠️  This migration will:"
echo "  • Add organization_id column to users table"
echo "  • Create default organization"
echo "  • Link all existing users to default organization"
echo "  • Add missing tables (groups, scores, etc.)"
echo "  • Create indexes and views"
echo ""
echo "⚠️  IMPORTANT: This is a ONE-WAY migration!"
echo ""
read -p "Continue with migration? (y/n): " confirm

if [ "$confirm" != "y" ]; then
    echo "Migration cancelled"
    exit 0
fi

echo ""
echo "Creating backup before migration..."
BACKUP_FILE="database/backups/pre_migration_$(date +%Y%m%d_%H%M%S).sql"
mkdir -p database/backups

docker exec $DB_CONTAINER pg_dump -U $DB_USER $DB_NAME > $BACKUP_FILE

if [ $? -eq 0 ]; then
    SIZE=$(du -h $BACKUP_FILE | cut -f1)
    echo "✅ Backup created: $BACKUP_FILE ($SIZE)"
else
    echo "❌ Error creating backup"
    exit 1
fi

echo ""
echo "Applying migration..."
docker exec -i $DB_CONTAINER psql -U $DB_USER -d $DB_NAME < $MIGRATION_FILE

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Migration completed successfully!"
    echo ""
    echo "Summary:"
    echo "  • Default organization created"
    echo "  • All users linked to default organization"
    echo "  • Multi-org tables created"
    echo "  • Indexes and views created"
    echo ""
    echo "Next steps:"
    echo "  1. Test the admin dashboard: https://escore.al-hanna.com/admin/"
    echo "  2. Clear browser localStorage if still seeing loading screen"
    echo "  3. Login with your existing credentials"
    echo ""
    echo "Backup location: $BACKUP_FILE"
else
    echo ""
    echo "❌ Migration failed!"
    echo "Database has been rolled back"
    echo "Check the error messages above"
    echo ""
    echo "To restore from backup:"
    echo "  docker exec -i $DB_CONTAINER psql -U $DB_USER -d $DB_NAME < $BACKUP_FILE"
    exit 1
fi
