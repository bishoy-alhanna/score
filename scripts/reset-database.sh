#!/bin/bash

# Reset Database from Scratch with Demo Data
# WARNING: This will delete ALL existing data!

set -e

echo "========================================="
echo "Database Reset with Demo Data"
echo "========================================="
echo ""

# Configuration
DB_CONTAINER="saas_postgres"
DB_NAME="saas_platform"
DB_USER="postgres"
SCHEMA_FILE="database/init_database.sql"

# Check if schema file exists
if [ ! -f "$SCHEMA_FILE" ]; then
    echo "❌ Error: Schema file not found: $SCHEMA_FILE"
    exit 1
fi

# Check if Docker is running
if ! docker ps &> /dev/null; then
    echo "❌ Error: Docker is not running"
    exit 1
fi

# Check if container exists and is running
if ! docker ps --format '{{.Names}}' | grep -q "^${DB_CONTAINER}$"; then
    echo "⚠️  PostgreSQL container is not running"
    echo "Starting PostgreSQL container..."
    docker-compose up -d postgres
    echo "Waiting for PostgreSQL to be ready..."
    sleep 5
fi

echo "⚠️  ⚠️  ⚠️  CRITICAL WARNING ⚠️  ⚠️  ⚠️"
echo ""
echo "This will COMPLETELY DELETE the database and recreate it!"
echo ""
echo "What will happen:"
echo "  • Current database will be DROPPED"
echo "  • New database will be created"
echo "  • All tables will be recreated"
echo "  • Demo data will be inserted"
echo ""
echo "Demo data includes:"
echo "  • 3 Organizations (Default, Youth Academy, Tech University)"
echo "  • 10 Users across organizations"
echo "  • 15 Score categories"
echo "  • 6 Groups"
echo "  • Random scores for testing"
echo ""
echo "Default Admin Credentials:"
echo "  Username: admin"
echo "  Password: admin123"
echo "  Organization: Default Organization"
echo ""
echo "⚠️  THIS ACTION CANNOT BE UNDONE!"
echo ""

read -p "Type 'DELETE ALL DATA' to confirm: " confirm

if [ "$confirm" != "DELETE ALL DATA" ]; then
    echo ""
    echo "Operation cancelled. Database not modified."
    exit 0
fi

echo ""
echo "Creating backup before proceeding..."
BACKUP_FILE="database/backups/pre_reset_$(date +%Y%m%d_%H%M%S).sql"
mkdir -p database/backups

# Try to backup existing database
docker exec $DB_CONTAINER pg_dump -U $DB_USER $DB_NAME > $BACKUP_FILE 2>/dev/null || {
    echo "⚠️  Could not create backup (database may not exist yet)"
    rm -f $BACKUP_FILE
}

if [ -f "$BACKUP_FILE" ]; then
    SIZE=$(du -h $BACKUP_FILE | cut -f1)
    echo "✅ Backup created: $BACKUP_FILE ($SIZE)"
fi

echo ""
echo "Step 1/4: Terminating all connections to database..."
docker exec $DB_CONTAINER psql -U $DB_USER -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$DB_NAME' AND pid <> pg_backend_pid();" 2>/dev/null || true

echo "Step 2/4: Dropping existing database..."
docker exec $DB_CONTAINER psql -U $DB_USER -d postgres -c "DROP DATABASE IF EXISTS ${DB_NAME};" 

if [ $? -eq 0 ]; then
    echo "✅ Database dropped"
else
    echo "❌ Error dropping database"
    exit 1
fi

echo "Step 3/4: Creating fresh database..."
docker exec $DB_CONTAINER psql -U $DB_USER -d postgres -c "CREATE DATABASE ${DB_NAME};"

if [ $? -eq 0 ]; then
    echo "✅ Database created"
else
    echo "❌ Error creating database"
    exit 1
fi

echo "Step 4/4: Loading schema and demo data..."

# Execute schema file
docker exec -i $DB_CONTAINER psql -U $DB_USER -d $DB_NAME < $SCHEMA_FILE

if [ $? -eq 0 ]; then
    echo ""
    echo "✅✅✅ SUCCESS! ✅✅✅"
    echo ""
    echo "========================================="
    echo "Database has been completely reset!"
    echo "========================================="
    echo ""
    echo "📊 DEMO DATA LOADED:"
    echo ""
    echo "🏢 Organizations:"
    echo "  • Default Organization"
    echo "  • Youth Academy"
    echo "  • Tech University"
    echo ""
    echo "👤 Admin Accounts (all use password: admin123):"
    echo "  • admin@score.com (Default Organization)"
    echo "  • mike@youth.com (Youth Academy)"
    echo "  • smith@tech.edu (Tech University)"
    echo ""
    echo "👥 Demo Users:"
    echo "  • 10 users total across 3 organizations"
    echo "  • Each organization has users with scores"
    echo "  • Groups and leaderboards populated"
    echo ""
    echo "📈 Score Categories:"
    echo "  • 5 categories per organization"
    echo "  • Random scores assigned for realistic leaderboard"
    echo ""
    echo "========================================="
    echo "NEXT STEPS:"
    echo "========================================="
    echo ""
    echo "1. Access the admin dashboard:"
    echo "   https://escore.al-hanna.com/admin/"
    echo ""
    echo "2. Login with:"
    echo "   Username: admin"
    echo "   Password: admin123"
    echo ""
    echo "3. If you see a loading screen:"
    echo "   • Open browser console (F12)"
    echo "   • Run: localStorage.clear()"
    echo "   • Refresh page"
    echo ""
    echo "4. ⚠️  CHANGE THE ADMIN PASSWORD IMMEDIATELY!"
    echo ""
    
    if [ -f "$BACKUP_FILE" ]; then
        echo "📦 Backup saved at: $BACKUP_FILE"
        echo ""
    fi
    
    echo "========================================="
else
    echo ""
    echo "❌ Error loading schema!"
    echo ""
    echo "To restore from backup (if exists):"
    if [ -f "$BACKUP_FILE" ]; then
        echo "  docker exec $DB_CONTAINER psql -U $DB_USER -c 'CREATE DATABASE ${DB_NAME};'"
        echo "  docker exec -i $DB_CONTAINER psql -U $DB_USER -d $DB_NAME < $BACKUP_FILE"
    else
        echo "  No backup available"
    fi
    exit 1
fi
