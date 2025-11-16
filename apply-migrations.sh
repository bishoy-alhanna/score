#!/bin/bash

# Apply Database Migrations
# This script applies all pending database migrations

set -e

echo "=========================================="
echo "Applying Database Migrations"
echo "=========================================="
echo ""

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
elif [ -f .env.production ]; then
    export $(cat .env.production | grep -v '^#' | xargs)
fi

POSTGRES_USER=${POSTGRES_USER:-postgres}

echo "Checking database connection..."
if ! docker exec score_postgres_prod psql -U $POSTGRES_USER -d saas_platform -c "SELECT 1" > /dev/null 2>&1; then
    echo "ERROR: Cannot connect to database"
    echo "Make sure PostgreSQL container is running:"
    echo "  docker-compose -f docker-compose.prod.yml ps postgres"
    exit 1
fi

echo "✅ Database connection OK"
echo ""

# Apply migrations
MIGRATION_DIR="database/migrations"

if [ ! -d "$MIGRATION_DIR" ]; then
    echo "ERROR: Migration directory not found: $MIGRATION_DIR"
    exit 1
fi

echo "Applying migrations from $MIGRATION_DIR..."
echo ""

for migration in $(ls -1 $MIGRATION_DIR/*.sql 2>/dev/null | sort); do
    migration_name=$(basename "$migration")
    echo "📝 Applying: $migration_name"
    
    if docker exec -i score_postgres_prod psql -U $POSTGRES_USER -d saas_platform < "$migration"; then
        echo "   ✅ Success"
    else
        echo "   ❌ Failed"
        exit 1
    fi
    echo ""
done

echo "=========================================="
echo "✅ All Migrations Applied Successfully!"
echo "=========================================="
echo ""

# Show current users table structure
echo "Current users table structure:"
docker exec -i score_postgres_prod psql -U $POSTGRES_USER -d saas_platform << 'SQL'
\d users
SQL

echo ""
echo "You can now create the super admin user:"
echo "  ./create-admin-direct.sh"
echo ""
