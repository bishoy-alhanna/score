#!/bin/bash

# Script to apply the manual score migration to the database
# Run this after the database is up and running

echo "========================================"
echo "Applying Manual Score Migration"
echo "========================================"

# Check if Docker Compose is running
if ! docker-compose ps | grep -q "saas_postgres"; then
    echo "⚠️  Database container is not running!"
    echo "Please start the services first:"
    echo "  docker-compose up -d"
    exit 1
fi

echo "📊 Applying migration to add manual_score field to groups table..."

# Apply the migration using docker exec
docker-compose exec -T postgres psql -U postgres -d saas_platform -f - < database/add_manual_score_to_groups.sql

if [ $? -eq 0 ]; then
    echo "✅ Migration applied successfully!"
    echo ""
    echo "📋 Verifying the change..."
    docker-compose exec -T postgres psql -U postgres -d saas_platform -c "SELECT column_name, data_type, column_default FROM information_schema.columns WHERE table_name = 'groups' AND column_name = 'manual_score';"
    echo ""
    echo "🎉 Manual score feature is ready to use!"
else
    echo "❌ Migration failed. Please check the error messages above."
    exit 1
fi
