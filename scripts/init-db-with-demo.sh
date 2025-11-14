#!/bin/bash

# Initialize Database with Demo Data
# Creates complete schema and populates with demo users and scores

set -e

echo "========================================="
echo "Database Initialization with Demo Data"
echo "========================================="
echo ""

# Configuration
DB_CONTAINER="saas_postgres"
DB_NAME="saas_platform"
DB_USER="postgres"
SCHEMA_FILE="database/init_schema_with_demo_data.sql"

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

# Check if container exists
if ! docker ps -a --format '{{.Names}}' | grep -q "^${DB_CONTAINER}$"; then
    echo "❌ Error: PostgreSQL container '${DB_CONTAINER}' not found"
    echo "Please start your Docker containers first: docker-compose up -d"
    exit 1
fi

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${DB_CONTAINER}$"; then
    echo "⚠️  PostgreSQL container is not running. Starting it..."
    docker-compose up -d postgres
    echo "Waiting for PostgreSQL to be ready..."
    sleep 5
fi

# Menu
echo "⚠️  WARNING: This will DROP all existing tables and data!"
echo ""
echo "This script will:"
echo "  • Drop all existing tables"
echo "  • Create complete schema (organizations, users, groups, scores, etc.)"
echo "  • Add 3 demo organizations"
echo "  • Add 10 demo users with credentials"
echo "  • Add score categories"
echo "  • Add sample scores for leaderboard testing"
echo ""
read -p "Continue? (type 'YES' to confirm): " confirm

if [ "$confirm" != "YES" ]; then
    echo "Cancelled"
    exit 0
fi

echo ""
echo "Creating backup of current database..."
BACKUP_FILE="database/backups/backup_$(date +%Y%m%d_%H%M%S).sql"
mkdir -p database/backups

docker exec $DB_CONTAINER pg_dump -U $DB_USER $DB_NAME > $BACKUP_FILE 2>/dev/null || echo "No existing data to backup"

if [ -f "$BACKUP_FILE" ]; then
    SIZE=$(du -h $BACKUP_FILE 2>/dev/null | cut -f1 || echo "0")
    echo "✅ Backup created: $BACKUP_FILE ($SIZE)"
fi

echo ""
echo "Initializing database with demo data..."
docker exec -i $DB_CONTAINER psql -U $DB_USER -d $DB_NAME < $SCHEMA_FILE

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Database initialized successfully!"
    echo ""
    echo "========================================="
    echo "Demo Credentials"
    echo "========================================="
    echo ""
    echo "🏫 DEMO UNIVERSITY (Organization 1)"
    echo "   Admin:"
    echo "     Username: admin"
    echo "     Password: admin123"
    echo ""
    echo "   Users (password: demo123):"
    echo "     • john.doe"
    echo "     • jane.smith"
    echo "     • bob.wilson"
    echo "     • alice.johnson"
    echo ""
    echo "🏃 YOUTH CENTER (Organization 2)"
    echo "   Admin:"
    echo "     Username: youth.admin"
    echo "     Password: admin123"
    echo ""
    echo "   Users (password: demo123):"
    echo "     • mike.brown"
    echo "     • sarah.davis"
    echo ""
    echo "💻 TECH ACADEMY (Organization 3)"
    echo "   Admin:"
    echo "     Username: tech.admin"
    echo "     Password: admin123"
    echo ""
    echo "   Users (password: demo123):"
    echo "     • dev.student"
    echo ""
    echo "========================================="
    echo "Database Contents"
    echo "========================================="
    echo ""
    
    # Query the database for summary
    docker exec $DB_CONTAINER psql -U $DB_USER -d $DB_NAME -c "
        SELECT 'Organizations: ' || COUNT(*)::text FROM organizations
        UNION ALL
        SELECT 'Users: ' || COUNT(*)::text FROM users
        UNION ALL
        SELECT 'Groups: ' || COUNT(*)::text FROM groups
        UNION ALL
        SELECT 'Score Categories: ' || COUNT(*)::text FROM score_categories
        UNION ALL
        SELECT 'Total Scores: ' || COUNT(*)::text FROM scores;
    " | grep -v "row"
    
    echo ""
    echo "========================================="
    echo "Next Steps"
    echo "========================================="
    echo ""
    echo "1. Access Admin Dashboard:"
    echo "   https://escore.al-hanna.com/admin/"
    echo ""
    echo "2. Login with admin credentials"
    echo ""
    echo "3. If you see loading screen, clear browser storage:"
    echo "   • Press F12 (open console)"
    echo "   • Run: localStorage.clear(); location.reload()"
    echo ""
    echo "4. Test the leaderboard and scoring features"
    echo ""
    echo "Backup saved to: $BACKUP_FILE"
else
    echo ""
    echo "❌ Error initializing database"
    echo "Check the error messages above"
    echo ""
    if [ -f "$BACKUP_FILE" ]; then
        echo "To restore from backup:"
        echo "  docker exec -i $DB_CONTAINER psql -U $DB_USER -d $DB_NAME < $BACKUP_FILE"
    fi
    exit 1
fi

echo ""
echo "========================================="
echo "Initialization Complete!"
echo "========================================="
